import SwiftUI
import SceneKit

final class UIInspector3D: UIView {
	
	private(set) weak var targetView: UIView?
	private var selectedNode: SCNNode?
	private let sceneView = SCNView()
	private let scene = SCNScene()
	private var viewNodes: [SCNNode: UIView] = [:]
	private var highlightNodes: Set<SCNNode> = []
	private var borderOverlayNodes: Set<SCNNode> = []
	var notifyViewSelected: ((UIView) -> Void)?
	
	// Animation properties
	private var isAnimating = false
	private let initialCameraDistance: Float = 1500
	private let revealCameraDistance: Float = 2000
	private let background = UISceneBackground()
	var showBorderOverlay = true {
		didSet {
			guard oldValue != showBorderOverlay else { return }
			for node in borderOverlayNodes {
				node.isHidden = !showBorderOverlay
			}
		}
	}

	init() {
		super.init(frame: .zero)
		backgroundColor = UIInspector.backgroundColor
		addSubview(background)
		background.tintColor = tintColor
		setup3DView()
		setupInteractions()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func inspect(view: UIView, animate: Bool = false, whenReady: (() -> Void)? = nil) {
		targetView = view
		update(animate: animate, whenReady: whenReady)
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		background.frame = bounds
		sceneView.frame = bounds
	}

	override func tintColorDidChange() {
		super.tintColorDidChange()
		background.tintColor = tintColor
		for node in borderOverlayNodes {
			node.geometry?.firstMaterial?.diffuse.contents = tintColor
		}
		for node in highlightNodes {
			node.geometry?.firstMaterial?.emission.contents = tintColor
		}
	}

	func update(animate: Bool = false, whenReady: (() -> Void)? = nil) {
		guard let targetView, window != nil, bounds.width > 0 && bounds.height > 0 else {
			return
		}
		let groupedViews = [[targetView]] + targetView.allVisibleSubviewsLayers

		// Clear existing nodes (but keep camera and lights)
		scene.rootNode.childNodes.forEach {
			if $0.camera == nil && $0.light == nil {
				$0.removeFromParentNode()
			}
		}
		viewNodes.removeAll()
		highlightNodes.removeAll()
		borderOverlayNodes.removeAll()
		
		// Configure camera for perfect sizing FIRST
		if animate {
			configureCameraForTargetView()
		}

		// Process each depth level
		var i = 0
		for views in groupedViews {
			for (j, view) in views.enumerated() {
				let node = createNodeForView(view, depth: Double(i) + Double(j) * 0.5)
				scene.rootNode.addChildNode(node)
				viewNodes[node] = view
			}
			i += views.count
		}
		
		// Force scene view to update
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
			whenReady?()
			if animate {
				animateAppear()
			}
		}
	}

	func animateFocus(completion: (() -> Void)? = nil) {
		guard let cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil }),
			  let camera = cameraNode.camera,
			  let targetView else { return }
		// Compute new target values
		let scaleForWidth = targetView.bounds.width / 2
		let scaleForHeight = targetView.bounds.height / 2
		let orthographicScale = max(scaleForWidth, scaleForHeight)
		let targetPosition = SCNVector3(0, 0, initialCameraDistance)
		let targetRotation = SCNVector3(0, 0, 0)
		
		animateCamera {
			camera.orthographicScale = orthographicScale
			cameraNode.position = targetPosition
			cameraNode.eulerAngles = targetRotation
		} completion: {
			completion?()
		}
	}

	private func setup3DView() {
		sceneView.scene = scene
		sceneView.backgroundColor = .clear
		
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
	
	private func configureCameraForTargetView(from function: String = #function) {
		guard let targetView else { return }
		guard let cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil }),
			  let camera = cameraNode.camera else { return }
		
		// Calculate the orthographic scale to match the target view size
		// The orthographic scale represents half the height of the view volume
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

	private func animateAppear() {
		guard let cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil }) else { return }
		
		// Use the built-in camera controls to smoothly orbit the scene
		let targetPoint = SCNVector3(0, 0, 0) // Center of our composition
		
		let cameraController = self.sceneView.defaultCameraController
		// Set the point of interest to the center of our scene
		cameraController.pointOfView = cameraNode
		cameraController.target = targetPoint
		
		// Enable automatic camera and set it to orbit mode
		cameraController.interactionMode = .orbitTurntable
		
		// Start a smooth programmatic orbit
		animateCamera {
			performSmoothOrbit(cameraController: cameraController, cameraNode: cameraNode)
		}
	}
	
	private func performSmoothOrbit(cameraController: SCNCameraController, cameraNode: SCNNode) {
		// Calculate orbital position around the center (0,0,0)
		let targetPoint = sceneContentCenter()
		let distance: Float = self.revealCameraDistance
		
		// Orbital angles for nice 3D perspective
		let angleX: Float = 0.3 // Tilt up slightly (about 17 degrees)
		let angleY: Float = 0.4  // Rotate around Y axis (about 23 degrees)
		
		// Calculate camera position in orbit around target
		let x = distance * sin(angleY) * cos(angleX)
		let y = distance * sin(angleX)
		let z = distance * cos(angleY) * cos(angleX)
		
		cameraNode.camera?.orthographicScale *= 1.2
		
		// Make camera look at the center of our composition
		cameraNode.position = SCNVector3(x, y, z)
		cameraNode.look(at: targetPoint)
	}
	
	private func sceneContentCenter() -> SCNVector3 {
		let contentNodes = scene.rootNode.childNodes.filter {
			$0.geometry != nil && $0.camera == nil && $0.light == nil
		}
		
		guard !contentNodes.isEmpty else { return SCNVector3Zero }
		
		var sum = SCNVector3Zero
		for node in contentNodes {
			let (min, max) = node.boundingBox
			let center = SCNVector3(
				(min.x + max.x) / 2,
				(min.y + max.y) / 2,
				(min.z + max.z) / 2
			)
			let worldCenter = node.convertPosition(center, to: nil)
			sum.x += worldCenter.x
			sum.y += worldCenter.y
			sum.z += worldCenter.z
		}
		
		let count = Float(contentNodes.count)
		return SCNVector3(sum.x / count, sum.y / count, sum.z / count)
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
		borderOverlayNodes.formUnion(node.addBorderOverlay(color: tintColor, hidden: !showBorderOverlay))
		
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
		if let highligh = node.addRectOverlay(color: tintColor) {
			highlightNodes.insert(highligh)
		}
	}

	// 3. Interactive debugging
	func setupInteractions() {
		// Enable camera controls
		sceneView.allowsCameraControl = false
		
		// Add tap gesture
		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
		sceneView.addGestureRecognizer(tapGesture)
		
		let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
		sceneView.addGestureRecognizer(panGesture)

		let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
		sceneView.addGestureRecognizer(pinchGesture)

		let pan2Gesture = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
		pan2Gesture.minimumNumberOfTouches = 2
		sceneView.addGestureRecognizer(pan2Gesture)
	}
	
	func animateCamera(
		duration: TimeInterval = 0.3,
		curve: CAMediaTimingFunctionName = .easeInEaseOut,
		_ animation: () -> Void,
		completion: (() -> Void)? = nil
	) {
		guard !isAnimating else { return }
		isAnimating = true

		SCNTransaction.begin()
		SCNTransaction.animationDuration = duration
		SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: curve)

		animation()

		SCNTransaction.completionBlock = { [weak self] in
			guard let self else { return }
			self.isAnimating = false
			completion?()
		}
		SCNTransaction.commit()
	}
	
	func detachCameraControl() {
		sceneView.allowsCameraControl = false
		sceneView.defaultCameraController.interactionMode = .fly
		sceneView.defaultCameraController.pointOfView = nil
		sceneView.isUserInteractionEnabled = false
	}

	func attachCameraControl() {
		guard let cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil }) else { return }
		sceneView.defaultCameraController.pointOfView = cameraNode
		sceneView.defaultCameraController.target = sceneContentCenter()
		sceneView.defaultCameraController.interactionMode = .orbitTurntable
		sceneView.allowsCameraControl = true
		sceneView.isUserInteractionEnabled = true
	}
	
	@objc private func handleTap(_ gesture: UITapGestureRecognizer) {
		let location = gesture.location(in: sceneView)
		let hitResults = sceneView.hitTest(location, options: nil)
		
		// Clear previous selection
		clearSelection()
		
		if let hitResult = hitResults.first {
			selectedNode = hitResult.node
			highlightNode(hitResult.node)
			
			// Find corresponding UIView
			if let view = viewNodes[hitResult.node] {
				notifyViewSelected?(view)
			}
		}
	}
	
	@objc func handlePan(_ gesture: UIPanGestureRecognizer) {
		guard gesture.numberOfTouches == 1 else { return }
		let translation = gesture.translation(in: sceneView)
		let cameraController = sceneView.defaultCameraController
		// Sensitivity is arbitrary; tweak as needed
		cameraController.rotateBy(
			x: Float(-translation.x),
			y: Float(-translation.y)
		)
		gesture.setTranslation(.zero, in: sceneView)
	}

	@objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
		guard let cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil }),
			  let camera = cameraNode.camera
		else {
			return
		}
		camera.orthographicScale /= Double(gesture.scale)
		gesture.scale = 1
	}

	@objc func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
		guard gesture.numberOfTouches == 2 else { return }
		let translation = gesture.translation(in: sceneView)
		let cameraController = sceneView.defaultCameraController
		cameraController.translateInCameraSpaceBy(
			x: Float(-translation.x),
			y: Float(translation.y),
			z: 0
		)
		gesture.setTranslation(.zero, in: sceneView)
	}
	
	func clearSelection() {
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
	
	func addRectOverlay(color: UIColor = UIInspector.tintColor, alpha: CGFloat = 0.5) -> SCNNode? {
		guard let geometry = self.geometry as? SCNPlane else { return nil }
		 
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
		 return overlayNode
	}

	func addBorderOverlay(color: UIColor = UIInspector.tintColor, thickness: CGFloat = 0.5, hidden: Bool) -> Set<SCNNode> {
		guard let geometry = self.geometry as? SCNPlane else {
			return []
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
		
		var borderNodes: Set<SCNNode> = []
		for (borderGeometry, position) in borders {
			let material = SCNMaterial()
			material.diffuse.contents = color
			material.lightingModel = .constant
			material.isDoubleSided = true
			material.transparency = 1.0 // Make sure it's fully opaque
			
			borderGeometry.materials = [material]
			
			let borderNode = SCNNode(geometry: borderGeometry)
			borderNode.position = position
			borderNode.isHidden = hidden // Set initial visibility
			
			addChildNode(borderNode)
			borderNodes.insert(borderNode)
		}
		return borderNodes
	}
}
