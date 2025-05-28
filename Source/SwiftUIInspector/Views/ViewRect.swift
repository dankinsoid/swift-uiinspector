import UIKit

protocol ViewRect: Hashable {

	var source: UIView { get }
	func highlight()
	func unhighlight()
}

final class UIViewRect: UIView, ViewRect {
	
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
	
	func highlight() {
		backgroundColor = tintColor.withAlphaComponent(0.5)
	}

	func unhighlight() {
		backgroundColor = .clear
	}
}
