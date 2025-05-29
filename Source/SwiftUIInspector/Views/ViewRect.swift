import UIKit

protocol UIInspectorItem: Hashable {

	var source: UIView { get }
	func highlight()
	func highlight(with color: UIColor)
	func unhighlight()
}

final class UIViewInspectorItem: UIView, UIInspectorItem {
	
	let source: UIView
	
	init(_ source: UIView, frame: CGRect = .zero) {
		self.source = source
		super.init(frame: frame)
		backgroundColor = .clear
	}
	
	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func highlight(with color: UIColor) {
		backgroundColor = color
	}

	func highlight() {
		backgroundColor = tintColor.withAlphaComponent(0.5)
	}

	func unhighlight() {
		backgroundColor = .clear
	}
}
