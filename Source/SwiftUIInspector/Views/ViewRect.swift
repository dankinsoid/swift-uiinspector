import UIKit

protocol UIInspectorItem: Hashable, AnyObject {

	var snapshot: UIViewSnapshot { get }
	var parentItem: (any UIInspectorItem)? { get set }
	var children: [any UIInspectorItem] { get set }
	var isHighlighted: Bool { get }
	var highlightColor: UIColor { get set }
	func highlight()
	func unhighlight()
}

extension UIInspectorItem {

	func highlight(with color: UIColor ) {
		highlightColor = color
		highlight()
	}

	var parents: [any UIInspectorItem] {
		parentItem.flatMap { [$0] + $0.parents } ?? []
	}
}

final class UIViewInspectorItem: UIView, UIInspectorItem {

	weak var parentItem: (any UIInspectorItem)?
	var children: [any UIInspectorItem] = []
	let snapshot: UIViewSnapshot
	var isHighlighted = false
	var highlightColor: UIColor = UIInspector.tintColor.withAlphaComponent(UIInspector.highlightAlpha)

	init(_ snapshot: UIViewSnapshot, frame: CGRect = .zero) {
		self.snapshot = snapshot
		super.init(frame: frame)
		backgroundColor = .clear
	}
	
	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func highlight() {
		isHighlighted = true
		backgroundColor = highlightColor
	}

	func unhighlight() {
		isHighlighted = false
		backgroundColor = .clear
	}
}
