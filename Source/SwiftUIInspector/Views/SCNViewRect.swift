import UIKit
import SceneKit

final class SCNViewRect: SCNNode, Identifiable, ViewRect {

	var id: ObjectIdentifier {
		ObjectIdentifier(source)
	}

	var overlayNode: SCNNode?
	var tintColor: UIColor
	let source: UIView
	let bounds: CGRect
	var size: CGSize {
		bounds.size
	}
	var globalRect: CGRect

	init(_ view: UIView, tintColor: UIColor, geometry: SCNPlane) {
		self.source = view
		self.globalRect = view.convert(view.bounds, to: view.window)
		self.bounds = view.bounds
		self.tintColor = tintColor
		super.init()
		self.geometry = geometry
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func convert(_ point: CGPoint, to view: SCNViewRect) -> CGPoint {
		CGPoint(
			x: point.x + globalRect.origin.x - view.globalRect.origin.x,
			y: point.y + globalRect.origin.y - view.globalRect.origin.y
		)
	}

	func convert(_ rect: CGRect, to view: SCNViewRect) -> CGRect {
		let minXminY = convert(rect.origin, to: view)
		let maxXmaxY = convert(
			CGPoint(x: rect.maxX, y: rect.maxY),
			to: view
		)
		return CGRect(
			x: minXminY.x,
			y: minXminY.y,
			width: abs(maxXmaxY.x - minXminY.x),
			height: abs(maxXmaxY.y - minXminY.y)
		)
	}

	func highlight() {
		guard overlayNode == nil else { return }
		overlayNode = addRectOverlay(color: tintColor)
	}

	func unhighlight() {
		overlayNode?.removeFromParentNode()
		overlayNode = nil
	}
}

extension SCNNode {
	
	func addRectOverlay(color: UIColor, alpha: CGFloat = 0.5) -> SCNNode? {
		guard let geometry = geometry as? SCNPlane else { return nil }
		
		let overlayGeometry = SCNBox(
			width: geometry.width,
			height: geometry.height,
			length: 1,
			chamferRadius: 0
		)
		
		let material = SCNMaterial()
		material.diffuse.contents = color
		material.transparency = alpha
		
		overlayGeometry.materials = [material]
		
		let overlayNode = SCNNode(geometry: overlayGeometry)
		overlayNode.position = SCNVector3(0, 0, 0)
		overlayNode.renderingOrder = 10 // ensure it's rendered after inner content
		
		overlayNode.categoryBitMask = 2
		addChildNode(overlayNode)
		return overlayNode
	}
}
