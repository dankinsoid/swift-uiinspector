import UIKit
import SceneKit

final class SCNViewRect: SCNNode, Identifiable, UIInspectorItem {

	var id: ObjectIdentifier {
		ObjectIdentifier(source)
	}

	var overlayNode: SCNNode?
	let source: UIView
	let bounds: CGRect
	var size: CGSize {
		bounds.size
	}
	var globalRect: CGRect
	var isHighlighted = false
	var highlightColor: UIColor = UIInspector.tintColor.withAlphaComponent(UIInspector.highlightAlpha)

	init(_ view: UIView, tintColor: UIColor, geometry: SCNPlane) {
		self.source = view
		self.globalRect = view.convert(view.bounds, to: view.window)
		self.bounds = view.bounds
		self.highlightColor = tintColor.withAlphaComponent(UIInspector.highlightAlpha)
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
		guard overlayNode == nil else {
			overlayNode?.geometry?.firstMaterial?.diffuse.contents = highlightColor
			return
		}
		overlayNode = addRectOverlay(color: highlightColor)
	}

	func unhighlight() {
		overlayNode?.removeFromParentNode()
		overlayNode = nil
	}
}

extension SCNNode {
	
	func addRectOverlay(color: UIColor) -> SCNNode? {
		guard let geometry = geometry as? SCNPlane else { return nil }
		
		let overlayGeometry = SCNBox(
			width: geometry.width,
			height: geometry.height,
			length: 1,
			chamferRadius: 0
		)
		
		let material = SCNMaterial()
		var alpha: CGFloat = 1
		color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
		material.diffuse.contents = color.withAlphaComponent(1)
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
