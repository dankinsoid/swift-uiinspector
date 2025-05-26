import SwiftUI

final class UIMeasurementLabel: UIView {

	private let label = UILabel()
	
	var textColor: UIColor {
		get { label.textColor }
		set { label.textColor = newValue }
	}

	var text: String? {
		get { label.text }
		set {
			guard newValue != text else { return }
			label.text = newValue
			invalidateIntrinsicContentSize()
		}
	}
	
	init() {
		super.init(frame: .zero)
		backgroundColor = UIInspector.backgroundColor
		label.textAlignment = .center
		label.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
		addSubview(label)
		clipsToBounds = false
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		label.frame = bounds
		layer.cornerRadius = min(bounds.height, bounds.width) / 2
	}

	func place(in rect: CGRect) {
		guard let window else { return }
		let labelSize = label.intrinsicContentSize
		frame = CGRect(
			origin: CGPoint(
				x: rect.midX - labelSize.width / 2,
				y: rect.midY - labelSize.height / 2
			),
			size: labelSize
		)
		.insetBy(dx: -5, dy: -3)
		.offsetBy(dx: 0, dy: -20)
		.inside(window.convert(window.bounds, to: superview))
	}
}
