import UIKit

final class ViewItem: Identifiable {

	var id: ObjectIdentifier {
		ObjectIdentifier(view)
	}

	let view: UIView
	let bounds: CGRect
	let frame: CGRect
	var size: CGSize {
		bounds.size
	}
	var globalRect: CGRect

	init(_ view: UIView) {
		self.view = view
		self.globalRect = view.convert(view.bounds, to: view.window)
		self.bounds = view.bounds
		self.frame = view.frame
	}

	func convert(_ point: CGPoint, to view: ViewItem) -> CGPoint {
		CGPoint(
			x: point.x + globalRect.origin.x - view.globalRect.origin.x,
			y: point.y + globalRect.origin.y - view.globalRect.origin.y
		)
	}

	func convert(_ rect: CGRect, to view: ViewItem) -> CGRect {
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
