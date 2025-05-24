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
	
	init() {
		super.init(frame: .zero)
		print("🔴 UIInspector3D init")
		backgroundColor = UIInspector.backgroundColor
		setup3DView()
		setupInteractions()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func inspect(view: UIView) {
		print("🔴 UIInspector3D inspect called with view: \(view)")
		targetView = view
		update()
	}
	
	override func didMoveToWindow() {
		super.didMoveToWindow()
		print("🔴 UIInspector3D didMoveToWindow: \(window != nil)")
		print("🔴 UIInspector3D bounds: \(bounds)")
		print("🔴 UIInspector3D sceneView bounds: \(sceneView.bounds)")
		update()
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		print("🔴 UIInspector3D layoutSubviews: \(bounds)")
		sceneView.frame = bounds
		// Force update if we have a target view
		if targetView != nil && bounds.width > 0 && bounds.height > 0 {
			print("🔴 UIInspector3D triggering update from layoutSubviews")
			update()
		}
	}
	
	func update() {
		print("🔴 UIInspector3D update called")
		print("🔴 targetView: \(targetView != nil)")
		print("🔴 window: \(window != nil)")
		print("🔴 bounds: \(bounds)")
		print("🔴 sceneView bounds: \(sceneView.bounds)")
		guard let targetView, let window else {
			print("🔴 UIInspector3D update failed - missing targetView or window")
			return }
		guard bounds.width > 0 && bounds.height > 0 else {
				print("🔴 UIInspector3D update failed - invalid bounds")
				return
			}
		// Get the grouped views
			let groupedViews = [[targetView]] + targetView.allVisibleSubviewsLayers
			print("🔴 UIInspector3D grouped views count: \(groupedViews.count)")
			print("🔴 UIInspector3D total views: \(groupedViews.flatMap { $0 }.count)")
			
		build3DRepresentation(
			groupedViews: groupedViews
		)
	}

	func setup3DView() {
		print("🔴 UIInspector3D setup3DView")
		sceneView.scene = scene
		sceneView.allowsCameraControl = true
		sceneView.backgroundColor = UIInspector.backgroundColor
		
		// Ensure scene view is added and configured first
		addSubview(sceneView)
		sceneView.frame = bounds
		
		// Setup camera after scene view is added
		setupCamera()
	}
	
	private func setupCamera() {
		// Setup orthographic camera (no perspective)
		let camera = SCNCamera()
		camera.usesOrthographicProjection = true
		camera.orthographicScale = 500
		
		let cameraNode = SCNNode()
		cameraNode.camera = camera
		cameraNode.position = SCNVector3(0, 0, 1000)
		scene.rootNode.addChildNode(cameraNode)
		
		// Add lighting
		let lightNode = SCNNode()
		lightNode.light = SCNLight()
		lightNode.light?.type = .omni
		lightNode.position = SCNVector3(0, 0, 500)
		scene.rootNode.addChildNode(lightNode)
		print("🔴 UIInspector3D setup3DView complete")
		print("🔴 Scene root node children: \(scene.rootNode.childNodes.count)")
	}
	
	func build3DRepresentation(groupedViews: [[UIView]]) {
		print("🔴 UIInspector3D build3DRepresentation called")
		// Clear existing nodes
		scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
		viewNodes.removeAll()
		highlightNodes.removeAll()
		
		
		// Add a test cube to verify the scene is working
		let testCube = SCNBox(width: 100, height: 100, length: 100, chamferRadius: 0)
		testCube.firstMaterial?.diffuse.contents = UIColor.green
		let testNode = SCNNode(geometry: testCube)
		testNode.position = SCNVector3(-200, 0, 0)
		scene.rootNode.addChildNode(testNode)
		print("🔴 Added test cube at position: \(testNode.position)")
		
		
		
		// Process each depth level
		var i = 0
		for (depth, views) in groupedViews.enumerated() {
			print("🔴 Processing depth \(depth) with \(views.count) views")
			for (j, view) in views.enumerated() {
				print("🔴 Creating node for view: \(view) with bounds: \(view.bounds)")
				let node = createNodeForView(view, depth: Double(i) + Double(j) * 0.5)
				scene.rootNode.addChildNode(node)
				viewNodes[node] = view
				print("🔴 Added node at position: \(node.position)")
			}
			i += views.count
		}
	}

	private func createNodeForView(_ view: UIView, depth: Double) -> SCNNode {
		print("🔴 Creating node for view with bounds: \(view.bounds), depth: \(depth)")
		// Create geometry
		
		let geometry = SCNPlane(width: view.bounds.width, height: view.bounds.height)

		// Apply snapshot as texture
		let snapshot = view.snapshotImageWithoutSubviews()
		geometry.firstMaterial?.diffuse.contents = snapshot
		geometry.firstMaterial?.isDoubleSided = true
		
		// Handle transparency
//		if view.backgroundColor?.cgColor.alpha ?? 1.0 < 1.0 {
//			geometry.firstMaterial?.transparency = view.backgroundColor?.cgColor.alpha ?? 1.0
//		}
		
		let node = SCNNode(geometry: geometry)
		node.addBorderOverlay()
		
		// Position in 3D space - CENTER THE COMPOSITION
		guard let targetView else {
			node.position = SCNVector3(0, 0, CGFloat(depth * 50))
			print("🔴 No targetView, positioned at: \(node.position)")
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
		
		print("🔴 Node positioned at: \(node.position)")
		return node
	}
	
	// 1. View selection and highlighting
	private func highlightNode(_ node: SCNNode) {
		selectedNode = node
		
		// Add highlight effect
		node.geometry?.firstMaterial?.emission.contents = UIColor.systemBlue
		
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
//			focusCamera(on: hitResult.node)
//			highlightNode(hitResult.node)
			
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
			// Top border
			(SCNPlane(width: width, height: t), SCNVector3(0, height/2 - t/2, 0.1)),
			// Bottom border
			(SCNPlane(width: width, height: t), SCNVector3(0, -height/2 + t/2, 0.1)),
			// Left border
			(SCNPlane(width: t, height: height), SCNVector3(-width/2 + t/2, 0, 0.1)),
			// Right border
			(SCNPlane(width: t, height: height), SCNVector3(width/2 - t/2, 0, 0.1))
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
