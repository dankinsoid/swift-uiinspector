import SwiftUI
import SceneKit

final class UIInspector3D: UIView {
	
	private(set) weak var targetView: UIView?
	private var selectedNode: SCNNode?
	private let sceneView = SCNView()
	private let scene = SCNScene()
	private var viewNodes: [SCNNode: UIView] = [:]
	private var highlightNodes: Set<SCNNode> = []
	var notifyViewSelected: ((UIView) -> Void)?
	
	// Animation properties
	private var hasAnimatedInitialReveal = false
	private let initialCameraDistance: Float = 1500
	private let revealCameraDistance: Float = 2000
	
	init() {
		super.init(frame: .zero)
		backgroundColor = UIInspector.backgroundColor
		setup3DView()
		setupInteractions()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func inspect(view: UIView) {
		targetView = view
		hasAnimatedInitialReveal = false // Reset animation flag for new view
		update()
	}
	
	override func didMoveToWindow() {
		super.didMoveToWindow()
		update()
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		sceneView.frame = bounds
	}
	
	func update() {
		guard let targetView, let window, bounds.width > 0 && bounds.height > 0 else {
			return
		}
		let groupedViews = [[targetView]] + targetView.allVisibleSubviewsLayers
		build3DRepresentation(groupedViews: groupedViews)
	}

	func setup3DView() {
		sceneView.scene = scene
		sceneView.allowsCameraControl = true
		sceneView.backgroundColor = UIInspector.backgroundColor
		
		// Setup orthographic camera (will be configured properly in update())
		let camera = SCNCamera()
		camera.usesOrthographicProjection = true
		camera.zNear = 1
		camera.zFar = 3000
		
		let cameraNode = SCNNode()
		cameraNode.camera = camera
		cameraNode.position = SCNVector3(0, 0, initialCameraDistance)
		scene.rootNode.addChildNode(cameraNode)
		
		// Add ambient lighting so everything is visible
		let ambientLight = SCNNode()
		ambientLight.light = SCNLight()
		ambientLight.light?.type = .ambient
		ambientLight.light?.intensity = 1000
		scene.rootNode.addChildNode(ambientLight)
		
		// Add directional lighting
		let lightNode = SCNNode()
		lightNode.light = SCNLight()
		lightNode.light?.type = .directional
		lightNode.light?.intensity = 1000
		lightNode.position = SCNVector3(0, 0, 1000)
		lightNode.look(at: SCNVector3(0, 0, 0))
		scene.rootNode.addChildNode(lightNode)
		
		addSubview(sceneView)
		sceneView.frame = bounds
	}
	
	private func configureCameraForTargetView() {
		guard let targetView else { return }
		guard let cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil }),
			  let camera = cameraNode.camera else { return }
		
		// Calculate the orthographic scale to match the target view size
		// The orthographic scale represents half the height of the view volume
		let sceneViewSize = sceneView.bounds.size
		let targetViewSize = targetView.bounds.size
		
		// Calculate scale based on the larger dimension to ensure everything fits
		let scaleForWidth = targetViewSize.width / 2
		let scaleForHeight = targetViewSize.height / 2
		
		// Use the larger scale to ensure everything fits
		let orthographicScale = max(scaleForWidth, scaleForHeight)
		
		camera.orthographicScale = orthographicScale

		// Reset camera position for perfect initial alignment
		cameraNode.position = SCNVector3(0, 0, initialCameraDistance)
		cameraNode.eulerAngles = SCNVector3(0, 0, 0) // Reset any rotation
	}
	
	private func animateCamera3DReveal() {
		guard !hasAnimatedInitialReveal else { return }
		guard let cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil }) else { return }
		
		hasAnimatedInitialReveal = true
		
		// Disable camera control during animation
		sceneView.allowsCameraControl = false
		
		// Wait a brief moment to let user see the perfect alignment
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
			SCNTransaction.begin()
			SCNTransaction.animationDuration = 1.2
			SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
			
			// Calculate orbital position around the center (0,0,0)
			let targetPoint = SCNVector3(0, 0, 0) // Center of our composition
			let distance: Float = self.revealCameraDistance
			
			// Orbital angles for nice 3D perspective
			let angleX: Float = 0.3 // Tilt up slightly (about 17 degrees)
			let angleY: Float = 0.4  // Rotate around Y axis (about 23 degrees)
			
			// Calculate camera position in orbit around target
			let x = distance * sin(angleY) * cos(angleX)
			let y = distance * sin(angleX)
			let z = distance * cos(angleY) * cos(angleX)
			
			// Position camera in orbital position
			cameraNode.position = SCNVector3(x, y, z)
			cameraNode.camera?.orthographicScale *= 1.2
			
			// Make camera look at the center of our composition
			cameraNode.look(at: targetPoint)
			
			SCNTransaction.completionBlock = {
				// Re-enable camera control after animation
				DispatchQueue.main.async {
					self.sceneView.allowsCameraControl = true
				}
			}
			
			SCNTransaction.commit()
		}
	}
	
	func build3DRepresentation(groupedViews: [[UIView]]) {
		// Clear existing nodes (but keep camera and lights)
		scene.rootNode.childNodes.forEach {
			if $0.camera == nil && $0.light == nil {
				$0.removeFromParentNode()
			}
		}
		viewNodes.removeAll()
		highlightNodes.removeAll()
		
		// Configure camera for perfect sizing FIRST
		configureCameraForTargetView()
		
		// Calculate bounds of all content for debugging
		var minX: CGFloat = 0, maxX: CGFloat = 0
		var minY: CGFloat = 0, maxY: CGFloat = 0
		var minZ: CGFloat = 0, maxZ: CGFloat = 0
		
		// Process each depth level
		var i = 0
		for (depth, views) in groupedViews.enumerated() {
			for (j, view) in views.enumerated() {
				let node = createNodeForView(view, depth: Double(i) + Double(j) * 0.5)
				scene.rootNode.addChildNode(node)
				viewNodes[node] = view
			}
			i += views.count
		}
		
		// Force scene view to update
		DispatchQueue.main.async { [weak self] in
			self?.sceneView.setNeedsDisplay()
			// Start the 3D reveal animation after the scene is built
			self?.animateCamera3DReveal()
		}
	}

	private func createNodeForView(_ view: UIView, depth: Double) -> SCNNode {
		// Create geometry
		let width = max(view.bounds.width, 1) // Ensure minimum size
		let height = max(view.bounds.height, 1)
		let geometry = SCNPlane(width: width, height: height)

		// Apply snapshot as texture
		let snapshot = view.snapshotImageWithoutSubviews()
		geometry.firstMaterial?.diffuse.contents = snapshot
		geometry.firstMaterial?.isDoubleSided = true
		geometry.firstMaterial?.lightingModel = .constant // Make sure it's always visible regardless of lighting
		
		let node = SCNNode(geometry: geometry)
		node.addBorderOverlay(color: tintColor)
		
		// Position in 3D space - CENTER THE COMPOSITION
		guard let targetView else {
			node.position = SCNVector3(0, 0, CGFloat(depth * 50))
			return node
		}
		
		// Convert view position to targetView coordinate system
		let viewFrameInTarget = view.superview?.convert(view.frame, to: targetView) ?? view.frame
		
		// Calculate position relative to targetView center
		let targetCenter = CGPoint(x: targetView.bounds.midX, y: targetView.bounds.midY)
		let viewCenter = CGPoint(x: viewFrameInTarget.midX, y: viewFrameInTarget.midY)
		
		// Center around origin (0,0,0)
		let centerX = viewCenter.x - targetCenter.x
		let centerY = -(viewCenter.y - targetCenter.y) // Flip Y for SceneKit
		let zPosition = CGFloat(depth * 10) // Space layers apart
		
		node.position = SCNVector3(centerX, centerY, zPosition)
		
		return node
	}
	
	// 1. View selection and highlighting
	private func highlightNode(_ node: SCNNode) {
		selectedNode = node
		
		// Add highlight effect
		node.geometry?.firstMaterial?.emission.contents = tintColor
		
		// Optional: Add outline
		if let outlineGeometry = node.geometry?.copy() as? SCNGeometry {
			outlineGeometry.firstMaterial?.fillMode = .lines
			outlineGeometry.firstMaterial?.diffuse.contents = UIColor.white
			outlineGeometry.firstMaterial?.emission.contents = UIColor.white
			
			let outlineNode = SCNNode(geometry: outlineGeometry)
			outlineNode.position = node.position
			outlineNode.scale = SCNVector3(1.02, 1.02, 1.02) // Slightly larger
			
			scene.rootNode.addChildNode(outlineNode)
			highlightNodes.insert(outlineNode) // Track for cleanup
		}
	}

	// 3. Interactive debugging
	func setupInteractions() {
		// Enable camera controls
		sceneView.allowsCameraControl = true
		
		// Add tap gesture
		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
		sceneView.addGestureRecognizer(tapGesture)
	}
	
	@objc private func handleTap(_ gesture: UITapGestureRecognizer) {
		let location = gesture.location(in: sceneView)
		let hitResults = sceneView.hitTest(location, options: nil)
		
		// Clear previous selection
		clearSelection()
		
		if let hitResult = hitResults.first {
			selectedNode = hitResult.node
			
			// Find corresponding UIView
			if let view = viewNodes[hitResult.node] {
				notifyViewSelected?(view)
			}
		}
	}
	
	private func focusCamera(on node: SCNNode) {
		// Animate camera to focus on selected node
		SCNTransaction.begin()
		SCNTransaction.animationDuration = 0.5
		
		if let cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil }) {
			let nodePosition = node.position
			let offset = SCNVector3(0, 0, 200) // Distance from node
			cameraNode.position = SCNVector3(
				nodePosition.x + offset.x,
				nodePosition.y + offset.y,
				nodePosition.z + offset.z
			)
			cameraNode.look(at: nodePosition)
		}
		
		SCNTransaction.commit()
	}
	
	private func clearSelection() {
		 // Remove highlight from previously selected node
		 if let selectedNode = selectedNode {
			 selectedNode.geometry?.firstMaterial?.emission.contents = UIColor.black
		 }
		 
		 // Remove any outline nodes we added
		 highlightNodes.forEach { $0.removeFromParentNode() }
		 highlightNodes.removeAll()
		 
		 // Clear selection
		 selectedNode = nil
	 }
}

extension SCNNode {
	
	func addRectOverlay(color: UIColor = UIInspector.tintColor, alpha: CGFloat = 1) {
		guard let geometry = self.geometry as? SCNPlane else { return }
		 
		 // Create overlay with same dimensions as the original plane
		 let overlayGeometry = SCNPlane(width: geometry.width, height: geometry.height)
		 
		 let material = SCNMaterial()
		 material.diffuse.contents = color
		 material.transparency = alpha
		 material.lightingModel = .constant
		 material.isDoubleSided = true
		 
		 overlayGeometry.materials = [material]
		 
		 let overlayNode = SCNNode(geometry: overlayGeometry)
		 // Position at the same location as parent, just slightly in front
		 overlayNode.position = SCNVector3(0, 0, 0.2)
		 
		 addChildNode(overlayNode)
	}

	func addBorderOverlay(color: UIColor = UIInspector.tintColor, thickness: CGFloat = 0.5) {
		guard let geometry = self.geometry as? SCNPlane else {
			return
		}
		
		let width = geometry.width
		let height = geometry.height
		let t = thickness
		
		// Create 4 border rectangles
		let borders = [
			// Top border - horizontal box
			(SCNBox(width: width, height: t, length: t, chamferRadius: 0), SCNVector3(0, height/2 - t/2, 0.1)),
			// Bottom border - horizontal box
			(SCNBox(width: width, height: t, length: t, chamferRadius: 0), SCNVector3(0, -height/2 + t/2, 0.1)),
			// Left border - vertical box
			(SCNBox(width: t, height: height, length: t, chamferRadius: 0), SCNVector3(-width/2 + t/2, 0, 0.1)),
			// Right border - vertical box
			(SCNBox(width: t, height: height, length: t, chamferRadius: 0), SCNVector3(width/2 - t/2, 0, 0.1))
		]
		
		for (i, (borderGeometry, position)) in borders.enumerated() {
			let material = SCNMaterial()
			material.diffuse.contents = color
			material.lightingModel = .constant
			material.isDoubleSided = true
			material.transparency = 1.0 // Make sure it's fully opaque
			
			borderGeometry.materials = [material]
			
			let borderNode = SCNNode(geometry: borderGeometry)
			borderNode.position = position
			
			addChildNode(borderNode)
		}
	}
}
