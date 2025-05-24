import SwiftUI

final class UIInspectorControls: UIView {

	private let padding: CGFloat = 3
	private let buttonSize: CGFloat = 36
	private var buttonViews: [ButtonView] = []

	var buttons: [Button] = [] {
		didSet {
			updateButtons()
		}
	}

	init() {
		super.init(frame: .zero)
		backgroundColor = UIInspector.backgroundColor
	}

	override var intrinsicContentSize: CGSize {
		CGSize(
			width: CGFloat(buttons.count) * buttonSize + 4 * padding,
			height: buttonSize + padding * 2
		)
	}

	private func updateButtons() {
		buttonViews.forEach { $0.removeFromSuperview() }
		buttonViews = buttons.enumerated().map { i, button in
			let buttonView = buttonViews[safe: i] ?? ButtonView()
			buttonView.imageView.tintColor = button.isSelected ? tintColor : UIInspector.foregroundColor
			buttonView.imageView.image = button.isSelected ? button.selectedIcon : button.unselectedIcon
			buttonView.isEnabled = button.isEnabled
			buttonView.imageView.alpha = button.isEnabled ? 1 : 0.5
			buttonView.tap = button.action
			return buttonView
		}
		buttonViews.forEach(addSubview)
		setNeedsLayout()
		invalidateIntrinsicContentSize()
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		layer.cornerRadius = bounds.height / 2
		var offset: CGFloat = padding * 2
		for button in buttonViews {
			button.frame = CGRect(
				x: offset,
				y: padding,
				width: buttonSize,
				height: buttonSize
			)
			offset += buttonSize
		}
	}

	struct Button {

		let selectedIcon: UIImage
		let unselectedIcon: UIImage
		let isSelected: Bool
		let isEnabled: Bool
		let action: () -> Void

		init(selectedIcon: UIImage, unselectedIcon: UIImage, isSelected: Bool, isEnabled: Bool = true, action: @escaping () -> Void) {
			self.selectedIcon = selectedIcon
			self.unselectedIcon = unselectedIcon
			self.isSelected = isSelected
			self.isEnabled = isEnabled
			self.action = action
		}

		init(icon: UIImage, isSelected: Bool = false, isEnabled: Bool = true, action: @escaping () -> Void) {
			self.init(selectedIcon: icon, unselectedIcon: icon, isSelected: isSelected, isEnabled: isEnabled, action: action)
		}
	}

	final class ButtonView: UIControl {

		let imageView = UIImageView()
		var tap: (() -> Void)?

		init() {
			super.init(frame: .zero)
			addSubview(imageView)
			backgroundColor = .clear
			imageView.contentMode = .scaleAspectFit
			addTarget(self, action: #selector(onTap), for: .touchUpInside)
			addTarget(self, action: #selector(onTouchDown), for: .touchDown)
			addTarget(self, action: #selector(onTouchUp), for: [.touchCancel, .touchUpOutside, .touchUpInside])
		}

		@objc
		private func onTap() {
			tap?()
		}

		@objc
		private func onTouchDown() {
			imageView.alpha = 0.5
		}

		@objc
		private func onTouchUp() {
			imageView.alpha = 1
		}

		@available(*, unavailable)
		required init?(coder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}

		override func layoutSubviews() {
			super.layoutSubviews()
			let padding = bounds.height / 5
			imageView.frame = bounds.insetBy(dx: padding, dy: padding)
		}

		override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
			true
		}
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
