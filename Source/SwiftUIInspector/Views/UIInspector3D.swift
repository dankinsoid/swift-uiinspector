import SceneKit
import simd
import SwiftUI

final class UIInspector3D: UIView {

	private(set) weak var targetView: UIView?
	private(set) var targetNode: SCNViewRect?
	private var inspectTargetRect: CGRect?
	private let sceneView = SCNView()
	private let scene = SCNScene()
	private(set) var viewNodes: [SCNViewRect] = []
	private(set) var viewNodesBySource: [UIView: SCNViewRect] = [:]
	private var borderOverlayNodes: Set<SCNNode> = []
	var notifyViewSelected: (any UIInspectorItem, [any UIInspectorItem]) -> Void = { _, _ in }

	// Animation properties
	private let initialCameraDistance: Float = 1500
	private let revealCameraDistance: Float = 2000
	private var lastPinchLocation: CGPoint?
	private let background = UISceneBackground()
	private var measurmentPlane: SCNNode?
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

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func inspect(view: UIView, in rect: CGRect?, animate: Bool = false, whenReady: (() -> Void)? = nil) {
		targetView = view
		inspectTargetRect = rect
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
	}

	func update(animate: Bool, whenReady: (() -> Void)?) {
		guard let targetView, window != nil, bounds.width > 0, bounds.height > 0 else {
			return
		}
		let groupedViews = targetView.selfAndAllVisibleSubviewsLayers

		// Clear existing nodes (but keep camera and lights)
		for childNode in scene.rootNode.childNodes {
			if childNode.camera == nil, childNode.light == nil {
				childNode.removeFromParentNode()
			}
		}
		hideMeasurementPlane()
		viewNodes.removeAll()
		viewNodesBySource.removeAll()
		borderOverlayNodes.removeAll()

		// Configure camera for perfect sizing FIRST
		if animate {
			configureCameraForTargetView()
		}

		// Process each depth level
		var i = 0
		for views in groupedViews {
			for (j, view) in views.filter({ insideRect($0) && !$0.needIgnoreInInspector }).enumerated() {
				let node = createNodeForView(view, depth: Double(i) + Double(j) * 0.5)
				scene.rootNode.addChildNode(node)
				viewNodes.append(node)
				viewNodesBySource[view] = node
				if view === targetView {
					targetNode = node
				}
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

		animate {
			camera.orthographicScale = orthographicScale
			cameraNode.position = targetPosition
			cameraNode.eulerAngles = targetRotation
		} completion: {
			completion?()
		}
	}

	func zoomToFit(rect: CGRect) {
		guard let cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil }),
		      let camera = cameraNode.camera else { return }

		// Convert rect to sceneView coordinates if needed
		let targetRect = convert(rect, to: sceneView)

		// Calculate scale factor (inverse - smaller rect means zoom in more)
		let scaleX = bounds.width / targetRect.width
		let scaleY = bounds.height / targetRect.height
		let scale = min(scaleX, scaleY) // Use minimum to ensure entire rect fits

		// Convert screen offset to world coordinates
		let screenCenter = CGPoint(x: bounds.midX, y: bounds.midY)
		let targetCenter = CGPoint(x: targetRect.midX, y: targetRect.midY)

		// Project screen points to world coordinates
		let worldCenter = sceneView.unprojectPoint(SCNVector3(screenCenter.x, screenCenter.y, 0))
		let worldTarget = sceneView.unprojectPoint(SCNVector3(targetCenter.x, targetCenter.y, 0))

		// Calculate world space offset
		let worldOffset = SCNVector3(
			worldTarget.x - worldCenter.x,
			worldTarget.y - worldCenter.y,
			0
		)

		animate {
			// Apply world space translation directly to camera node
			let currentPosition = cameraNode.position
			cameraNode.position = SCNVector3(
				currentPosition.x + worldOffset.x,
				currentPosition.y + worldOffset.y,
				currentPosition.z
			)

			// Adjust orthographic scale (divide to zoom in)
			camera.orthographicScale /= Double(scale)
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

		let cameraController = sceneView.defaultCameraController
		// Set the point of interest to the center of our scene
		cameraController.pointOfView = cameraNode
		cameraController.target = targetPoint

		// Enable automatic camera and set it to orbit mode
		cameraController.interactionMode = .orbitTurntable

		// Start a smooth programmatic orbit
		animate {
			performSmoothOrbit(cameraController: cameraController, cameraNode: cameraNode)
		}
	}

	private func performSmoothOrbit(cameraController: SCNCameraController, cameraNode: SCNNode) {
		// Calculate orbital position around the center (0,0,0)
		let targetPoint = sceneContentCenter()
		let distance: Float = revealCameraDistance

		// Orbital angles for nice 3D perspective
		let angleX: Float = 0.3 // Tilt up slightly (about 17 degrees)
		let angleY: Float = -0.4 // Rotate around Y axis (about 23 degrees)

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

	private func createNodeForView(_ view: UIView, depth: Double) -> SCNViewRect {
		// Create geometry
		let width = max(view.bounds.width, 1) // Ensure minimum size
		let height = max(view.bounds.height, 1)
		let geometry = SCNPlane(width: width, height: height)

		// Apply snapshot as texture
		let snapshot = view.snapshotImageWithoutSubviews()
		geometry.firstMaterial?.diffuse.contents = snapshot
		geometry.firstMaterial?.diffuse.magnificationFilter = .nearest
		geometry.firstMaterial?.diffuse.minificationFilter = .nearest
		geometry.firstMaterial?.diffuse.wrapS = .clamp
		geometry.firstMaterial?.diffuse.wrapT = .clamp
		geometry.firstMaterial?.isDoubleSided = true
		geometry.firstMaterial?.lightingModel = .constant

		let node = SCNViewRect(view, tintColor: tintColor, geometry: geometry)
		borderOverlayNodes.formUnion(node.addBorderOverlay(color: tintColor, hidden: !showBorderOverlay))

		// Position in 3D space - CENTER THE COMPOSITION
		guard let targetNode else {
			node.position = SCNVector3(0, 0, CGFloat(depth * 50))
			return node
		}

		// Convert view position to targetView coordinate system
		let viewFrameInTarget = view.superview?.convert(view.frame, to: targetNode.source) ?? view.convert(view.bounds, to: targetNode.source)

		// Calculate position relative to targetView center
		let targetCenter = CGPoint(x: targetNode.bounds.midX, y: targetNode.bounds.midY)
		let viewCenter = CGPoint(x: viewFrameInTarget.midX, y: viewFrameInTarget.midY)

		// Center around origin (0,0,0)
		let centerX = viewCenter.x - targetCenter.x
		let centerY = -(viewCenter.y - targetCenter.y) // Flip Y for SceneKit
		let zPosition = CGFloat(depth * 10) // Space layers apart

		node.position = SCNVector3(centerX, centerY, zPosition)

		return node
	}

	/// 2. Interactive debugging
	func setupInteractions() {
		// Enable camera controls
		sceneView.allowsCameraControl = false

		// Add tap gesture
		let tapGesture = JustTapGesture(target: self, action: #selector(handleTap))
		sceneView.addGestureRecognizer(tapGesture)

		let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
		panGesture.maximumNumberOfTouches = 1
		sceneView.addGestureRecognizer(panGesture)

		let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
		sceneView.addGestureRecognizer(pinchGesture)

		let pan2Gesture = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
		pan2Gesture.minimumNumberOfTouches = 2
		sceneView.addGestureRecognizer(pan2Gesture)
	}

	func animate(
		duration: TimeInterval = 0.25,
		curve: CAMediaTimingFunctionName = .easeInEaseOut,
		_ animation: () -> Void,
		completion: (() -> Void)? = nil
	) {
		SCNTransaction.begin()
		SCNTransaction.animationDuration = duration
		SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: curve)

		animation()

		SCNTransaction.completionBlock = {
			completion?()
		}
		SCNTransaction.commit()
	}

	func convert(_ location: CGPoint) -> CGPoint? {
		convertTapToTargetView(location).map {
			sceneView.convert($0.location, to: self)
		}
	}

	@objc private func handleTap(_ gesture: JustTapGesture) {
		let location = gesture.location(in: sceneView)

		guard let node = convertTapToTargetView(location)?.result.node as? SCNViewRect, gesture.state == .ended else {
			return
		}

		let dict = viewNodes.reduce(into: [UIView: any UIInspectorItem]()) { result, view in
			result[view.source] = view
		}
	
		// Find corresponding UIView
		notifyViewSelected(
			node,
			node.source.ancestors.dropFirst().compactMap { dict[$0] }
		)
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
		let location = gesture.location(in: sceneView)
		camera.orthographicScale /= Double(gesture.scale)
		gesture.scale = 1
		if let lastPinchLocation, gesture.state == .changed, gesture.numberOfTouches == 2 {
			let deltaX = Float(location.x - lastPinchLocation.x)
			let deltaY = Float(location.y - lastPinchLocation.y)
			let cameraController = sceneView.defaultCameraController
			cameraController.translateInCameraSpaceBy(
				x: -deltaX,
				y: deltaY,
				z: 0
			)
		}
		if gesture.state.isFinal {
			lastPinchLocation = nil
		} else {
			lastPinchLocation = location
		}
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
}

extension UIInspector3D {

	func insideRect(_ view: UIView) -> Bool {
		guard let inspectTargetRect, let targetNode, targetNode.source !== view else { return true }
		return inspectTargetRect.contains(view.convert(view.bounds, to: targetNode.source))
	}
}

extension UIInspector3D {

	func showMeasurementPlane(_ point0: CGPoint, _ point1: CGPoint) {
		if let measurmentPlane {
			updateMeasurementPlane(measurmentPlane, point0, point1)
		} else {
			let planeNode = createMeasurementPlane()
			updateMeasurementPlane(planeNode, point0, point1)
			measurmentPlane = planeNode
			scene.rootNode.addChildNode(planeNode)
		}
	}

	func hideMeasurementPlane() {
		measurmentPlane?.removeFromParentNode()
		measurmentPlane = nil
	}

	private func createMeasurementPlane() -> SCNNode {
		// Создаем геометрию плоскости

		let geometry = SCNPlane()
		// Настраиваем материал
		let material = SCNMaterial()
		material.diffuse.contents = tintColor
		material.transparency = 0.5
		material.lightingModel = .constant
		material.isDoubleSided = true
		geometry.materials = [material]

		// 5. Создаем узел и позиционируем его
		let planeNode = SCNNode(geometry: geometry)
		planeNode.position = SCNVector3Zero

		// Плоскость уже параллельна всем остальным (rotation = 0)

		planeNode.categoryBitMask = 2
		return planeNode
	}

	/// Обновить размер и положение существующей плоскости
	private func updateMeasurementPlane(_ planeNode: SCNNode, _ point0: CGPoint, _ point1: CGPoint) {

		// 1. Найти плоскость, на которую нажал пользователь (определить Z-координату)
		guard
			let geometry = planeNode.geometry as? SCNPlane
		else {
			return
		}

		let center = sceneView.unprojectPoint(
			SCNVector3(
				Float(point1.x + point0.x) / 2,
				Float(point1.y + point0.y) / 2,
				0.1
			)
		)

		planeNode.position = center

		let p0 = planeNode.simdWorldPosition

		// Локальные X и Y оси в мировой системе
		let ux = planeNode.simdConvertVector(simd_float3(1, 0, 0), to: nil)
		let uy = planeNode.simdConvertVector(simd_float3(0, 1, 0), to: nil)

		// Проецируем базисные векторы на экран
		let screen0 = sceneView.projectPoint(SCNVector3(p0))
		let screenX = sceneView.projectPoint(SCNVector3(p0 + ux))
		let screenY = sceneView.projectPoint(SCNVector3(p0 + uy))

		let vx = simd_float2(screenX.x - screen0.x, screenX.y - screen0.y)
		let vy = simd_float2(screenY.x - screen0.x, screenY.y - screen0.y)

		let J = float2x2(columns: (vx, vy))
		let invJ = J.inverse

		let dx = Float(point1.x - point0.x)
		let dy = Float(point1.y - point0.y)
		let screenDelta = simd_float2(dx, dy)
		let planeDelta = invJ * screenDelta

		// 4. Расстояние между точками в координатах плоскости
		geometry.width = CGFloat(abs(planeDelta.x))
		geometry.height = CGFloat(abs(planeDelta.y))
	}
}

extension UIInspector3D {

	func convertTapToTargetView(_ location: CGPoint) -> (location: CGPoint, result: SCNHitTestResult)? {
		guard let targetNode else { return nil }
		let location = convert(location, to: sceneView)
		let hitResults = sceneView.hitTest(location, options: [.categoryBitMask: 1])

		if let hitResult = hitResults.first(
			where: {
				($0.node as? SCNViewRect)?.bounds.size.isVisible == true && $0.node.geometry is SCNPlane
			}
		),
		   let view = hitResult.node as? SCNViewRect
		{
			let localHit = CGPoint(
				x: CGFloat(hitResult.localCoordinates.x) + view.bounds.midX,
				y: view.bounds.midY - CGFloat(hitResult.localCoordinates.y)
			)
			return (view.convert(localHit, to: targetNode), hitResult)
		}
		return nil
	}

	func convertFromTarget(_ location: CGPoint) -> CGPoint? {
		guard let targetNode else { return nil }
		let position = targetNode.convertPosition(
			SCNVector3(
				location.x - targetNode.size.width / 2,
				targetNode.size.height / 2 - location.y,
				0
			),
			to: nil
		)
		let point = sceneView.projectPoint(position)
		return sceneView.convert(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)), to: self)
	}
}

extension SCNNode {

	func addBorderOverlay(color: UIColor = UIInspector.tintColor, thickness: CGFloat = 0.5, hidden: Bool) -> Set<SCNNode> {
		guard let geometry = geometry as? SCNPlane else {
			return []
		}

		let width = geometry.width
		let height = geometry.height
		let t = thickness

		// Create 4 border rectangles
		let borders = [
			// Top border - horizontal box
			(SCNBox(width: width, height: t, length: t, chamferRadius: 0), SCNVector3(0, height / 2 - t / 2, 0.1)),
			// Bottom border - horizontal box
			(SCNBox(width: width, height: t, length: t, chamferRadius: 0), SCNVector3(0, -height / 2 + t / 2, 0.1)),
			// Left border - vertical box
			(SCNBox(width: t, height: height, length: t, chamferRadius: 0), SCNVector3(-width / 2 + t / 2, 0, 0.1)),
			// Right border - vertical box
			(SCNBox(width: t, height: height, length: t, chamferRadius: 0), SCNVector3(width / 2 - t / 2, 0, 0.1)),
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

			borderNode.categoryBitMask = 2
			addChildNode(borderNode)
			borderNodes.insert(borderNode)
		}
		return borderNodes
	}
}
