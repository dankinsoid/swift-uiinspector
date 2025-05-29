import SwiftUI

final class UIInspectorControls: UIView {

	private let padding: CGFloat = 3
	private let buttonSize: CGFloat = 36
	private var buttonViews: [ButtonView] = []
	let draggableArea = UIView()
	private let draggableImageView = UIImageView(image: UIImage(systemName: "circle.grid.3x3.fill"))

	var buttons: [UIInspectorButton] = [] {
		didSet {
			updateButtons()
		}
	}

	init() {
		super.init(frame: .zero)
		backgroundColor = UIInspector.backgroundColor
		layer.borderColor = UIInspector.foregroundColor.withAlphaComponent(0.3).cgColor
		layer.borderWidth = 0
		addSubview(draggableArea)
		draggableImageView.tintColor = UIInspector.foregroundColor
		draggableImageView.contentMode = .scaleAspectFit
		draggableImageView.alpha = 0.2
		draggableImageView.isUserInteractionEnabled = false
		draggableArea.addSubview(draggableImageView)
	}

	override var intrinsicContentSize: CGSize {
		CGSize(
			width: CGFloat(buttons.count + 1) * buttonSize + 4 * padding,
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
			buttonView.tap = { [weak self] in
				if self?.isUserInteractionEnabled == true {
					button.action()
				}
			}
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
		for button in (buttonViews) + [draggableArea] {
			button.frame = CGRect(
				x: offset,
				y: padding,
				width: buttonSize,
				height: buttonSize
			)
			offset += buttonSize
		}
		
		let padding = draggableArea.bounds.height / 5
		draggableImageView.frame = draggableArea.bounds.insetBy(dx: padding, dy: padding)
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

public struct UIInspectorButton {

	public var selectedIcon: UIImage?
	public var unselectedIcon: UIImage?
	public var isSelected: Bool
	public var isEnabled: Bool
	public var action: () -> Void

	public init(selectedIcon: UIImage?, unselectedIcon: UIImage?, isSelected: Bool, isEnabled: Bool = true, action: @escaping () -> Void) {
		self.selectedIcon = selectedIcon
		self.unselectedIcon = unselectedIcon ?? selectedIcon
		self.isSelected = isSelected
		self.isEnabled = isEnabled
		self.action = action
	}

	public init(icon: UIImage?, isSelected: Bool = false, isEnabled: Bool = true, action: @escaping () -> Void) {
		self.init(selectedIcon: icon, unselectedIcon: icon, isSelected: isSelected, isEnabled: isEnabled, action: action)
	}
}
