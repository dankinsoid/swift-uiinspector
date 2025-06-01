import UIKit

struct UIViewSnapshot: Identifiable {
	
	var id: ObjectIdentifier {
		ObjectIdentifier(source)
	}

	let source: UIView
	let ancestors: [UIView]
	let info: [UIInspector.Section]
	let snapshot: UIImage
	let bounds: CGRect
	var size: CGSize {
		bounds.size
	}
	let globalRect: CGRect
	
	init(_ source: UIView) {
		self.source = source
		self.ancestors = Array(source.ancestors.dropFirst())
		self.info = (source as? UIInspectorInfoConvertable)?.inspectorInfo ?? source.defaultInspectorInfo
		self.bounds = source.bounds
		self.globalRect = source.convert(source.bounds, to: source.window)
		self.snapshot = source.snapshotImageWithoutSubviews()
	}

	func convert(_ point: CGPoint, to view: UIViewSnapshot) -> CGPoint {
		CGPoint(
			x: point.x + globalRect.origin.x - view.globalRect.origin.x,
			y: point.y + globalRect.origin.y - view.globalRect.origin.y
		)
	}

	func convert(_ rect: CGRect, to view: UIViewSnapshot) -> CGRect {
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
}
