import SwiftUI

final class UIColorPipette: UIView {

	private let padding: CGFloat = 3
	private let colorView = UIView()
	private let label = UILabel()

	var color: UIColor {
		get {
			colorView.backgroundColor ?? .clear
		}
		set {
			guard newValue != color else { return }
			colorView.backgroundColor = newValue
			invalidateIntrinsicContentSize()
		}
	}

	var text: String {
		get { label.text ?? "" }
		set {
			guard newValue != text else { return }
			label.text = newValue
			invalidateIntrinsicContentSize()
		}
	}

	override var intrinsicContentSize: CGSize {
		let labelSize = label.intrinsicContentSize
		return CGSize(
			width: labelSize.width + labelSize.height + padding * 2 + labelSize.height / 2,
			height: labelSize.height + padding * 2
		)
	}

	init() {
		super.init(frame: .zero)
		backgroundColor = UIInspector.backgroundColor
		addSubview(colorView)
		addSubview(label)
		label.textColor = UIInspector.foregroundColor
		label.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
		label.text = color.hexString
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		let minSize = min(bounds.width, bounds.height)
		layer.cornerRadius = minSize / 2
		colorView.frame = CGRect(
			origin: CGPoint(x: padding, y: padding),
			size: CGSize(width: minSize - padding * 2, height: minSize - padding * 2)
		)
		label.frame = CGRect(
			x: minSize,
			y: padding,
			width: label.intrinsicContentSize.width,
			height: label.intrinsicContentSize.height
		)
		colorView.layer.cornerRadius = min(colorView.bounds.width, colorView.bounds.height) / 2
	}
}
