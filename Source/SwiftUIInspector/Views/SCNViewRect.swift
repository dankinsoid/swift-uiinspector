import UIKit
import SceneKit

final class SCNViewRect: SCNNode, Identifiable, UIInspectorItem {

	var id: ObjectIdentifier {
		snapshot.id
	}

	weak var parentItem: (any UIInspectorItem)?
	var children: [any UIInspectorItem] = []
	var overlayNode: SCNNode?
	let snapshot: UIViewSnapshot
	var isHighlighted = false
	var highlightColor: UIColor = UIInspector.tintColor.withAlphaComponent(UIInspector.highlightAlpha)

	init(_ snapshot: UIViewSnapshot, tintColor: UIColor, geometry: SCNPlane) {
		self.snapshot = snapshot
		self.highlightColor = tintColor.withAlphaComponent(UIInspector.highlightAlpha)
		super.init()
		self.geometry = geometry
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
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
