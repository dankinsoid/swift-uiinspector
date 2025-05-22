import SwiftUI

final class UIMeasurementSelection: UIView {

	let label = UILabel()

	var color: UIColor? {
		didSet {
			backgroundColor = color?.withAlphaComponent(0.3)
			label.textColor = color
			label.backgroundColor = UIInspector.backgroundColor
			label.textAlignment = .center
			layer.borderColor = color?.cgColor
		}
	}

	init() {
		super.init(frame: .zero)
		label.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
		addSubview(label)
		label.layer.masksToBounds = true
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		guard let window else { return }
		let labelSize = label.intrinsicContentSize
		label.frame = CGRect(
			origin: CGPoint(
				x: bounds.width / 2 - labelSize.width / 2,
				y: bounds.height / 2 - labelSize.height / 2
			),
			size: labelSize
		)
		.insetBy(dx: -5, dy: -3)
		.offsetBy(dx: 0, dy: -20)
		.inside(window.convert(window.bounds, to: self))
		label.layer.cornerRadius = min(label.bounds.height, label.bounds.width) / 2
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
