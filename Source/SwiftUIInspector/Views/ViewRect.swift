import UIKit

protocol UIInspectorItem: Hashable {

	var snapshot: UIViewSnapshot { get }
	var isHighlighted: Bool { get }
	var highlightColor: UIColor { get nonmutating set }
	func highlight()
	func unhighlight()
}

extension UIInspectorItem {

	func highlight(with color: UIColor ) {
		highlightColor = color
		highlight()
	}
}

final class UIViewInspectorItem: UIView, UIInspectorItem {
	
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
