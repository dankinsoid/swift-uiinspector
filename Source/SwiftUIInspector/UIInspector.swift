import SwiftUI

/// A visual inspector view that overlays on top of your app to examine UI elements.
///
/// `UIInspector` provides tools for:
/// - Inspecting view hierarchies
/// - Measuring dimensions of UI elements
/// - Picking colors from the UI
/// - Displaying detailed information about views
///
/// This class is typically used through `UIInspectorController` rather than directly.
///
/// ## Example Usage
///
/// While you typically use `UIInspectorController` to present the inspector,
/// you can configure the inspector directly:
///
/// ```swift
/// // Get an inspector instance from the controller
/// let inspector = UIInspectorController.present()?.inspector
///
/// // Configure the inspector
/// inspector?.tintColor = .systemBlue
/// inspector?.layerConfiguration = { view in
///     view.backgroundColor = .systemYellow.withAlphaComponent(0.2)
///     view.layer.borderColor = UIColor.systemYellow.cgColor
///     view.layer.borderWidth = 1
/// }
///
/// // Add custom information to the inspector detail view
/// inspector?.customInfoView = { view in
///     AnyView(
///         VStack {
///             Text("Custom Info")
///                 .font(.headline)
///             Text("View tag: \(view.tag)")
///             if let imageView = view as? UIImageView {
///                 Text("Image size: \(imageView.image?.size.width ?? 0) x \(imageView.image?.size.height ?? 0)")
///             }
///         }
///     )
/// }
/// ```
public final class UIInspector: UIView {

	/// The background color for inspector UI elements.
	/// Defaults to a dark/light mode adaptive color.
	public static var backgroundColor = UIColor(dark: .black, light: .white)

	/// The tint color for inspector UI elements and highlights.
	/// Defaults to a pink/magenta color that adapts to dark/light mode.
	public static var tintColor = UIColor(
		dark: UIColor(red: 1.0, green: 0.6, blue: 0.8, alpha: 1.0),
		light: UIColor(red: 0.9, green: 0.4, blue: 0.6, alpha: 1.0)
	)

	/// The foreground color for text and icons in the inspector.
	/// Defaults to white in dark mode and black in light mode.
	public static var foregroundColor = UIColor(dark: .white, light: .black)

	/// Reference to the controller that manages this inspector.
	weak var controller: UIInspectorController?

	/// Closure called when the close button is tapped.
	var onClose: (() -> Void)?

	/// Customizes the additional information view shown for inspected views.
	///
	/// Use this to add your own custom information to the inspector detail view.
	/// - Parameter view: The view being inspected
	/// - Returns: A SwiftUI view wrapped in `AnyView`
	public var customInfoView: (UIView) -> AnyView = { _ in AnyView(EmptyView()) }

	/// Configures the appearance of layer views in the hierarchy visualization.
	///
	/// By default, this sets a semi-transparent background color using the view's tint color.
	public var layerConfiguration: (UIView) -> Void = {
		$0.backgroundColor = $0.tintColor.withAlphaComponent(0.3)
	}

	private let scroll = UIScrollView()
	private let container = UIView()
	private let snapshot = UIImageView()
	private var controls = UIInspectorControls()
	private lazy var colorPalette = UIColorPalette()
	private lazy var selectionView = UIMeasurementSelection()

	private weak var targetView: UIView?
	private var rects: [UIView: UIView] = [:]

	private var horizontalGrid: [CGFloat] = []
	private var verticalGrid: [CGFloat] = []
	private var gridViews: [UIGrid] {
		gridHViews + gridVViews
	}

	private var gridHViews: [UIGrid] = []
	private var gridVViews: [UIGrid] = []

	private weak var draggingView: UIView?
	private var draggingControlOffset: CGPoint = .zero
	private var draggingStart: CGPoint = .zero

	private lazy var feedback = UISelectionFeedbackGenerator(view: self)

	private var hex = ""
	private var isFirstAppear = true
	private var controlsOffset: CGPoint = .zero

	private var mode: Mode = .dimensionMeasurement {
		didSet {
			updateButtons()
		}
	}

	private var showGrid = false {
		didSet {
			for gridView in gridViews {
				gridView.isHidden = !showGrid
			}
			if showGrid {
				drawGrid()
			}
			updateButtons()
		}
	}

	private var showLayers = true {
		didSet {
			for view in rects.keys {
				view.isHidden = !showLayers
			}
			updateButtons()
		}
	}

	override public var tintColor: UIColor! {
		didSet {
			for grid in gridViews {
				grid.backgroundColor = tintColor
			}
			updateButtons()
			selectionView.color = tintColor
		}
	}

	/// Initializes a new inspector view.
	///
	/// The inspector starts with default settings and is ready to inspect views
	/// once added to the view hierarchy.
	public init() {
		super.init(frame: .zero)
		tintColor = Self.tintColor
		backgroundColor = .clear
		selectionView.color = tintColor
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override public func didMoveToWindow() {
		super.didMoveToWindow()
		guard window != nil else { return }

		snapshot.layer.magnificationFilter = .nearest
		snapshot.isUserInteractionEnabled = false

		scroll.alwaysBounceHorizontal = false
		scroll.alwaysBounceVertical = false
		scroll.showsVerticalScrollIndicator = false
		scroll.showsHorizontalScrollIndicator = false
		scroll.insetsLayoutMarginsFromSafeArea = false
		scroll.delegate = self
		scroll.maximumZoomScale = 1000
		addSubview(scroll)

		container.backgroundColor = .clear
		scroll.addSubview(container)

		addControls()
		addDragGesture()
		update()
	}

	/// Inspects the specified view, showing its hierarchy and properties.
	///
	/// This method captures the view's current state and displays it in the inspector.
	/// - Parameter view: The view to inspect
	public func inspect(view: UIView) {
		if targetView !== view {
			targetView = view
		}
		update()
	}

	/// Updates the inspector view with the current state of the target view.
	///
	/// Call this method to refresh the inspector when the target view has changed.
	public func update() {
		guard let targetView, let window, targetView.window === window else { return }

		container.alpha = 0
		controls.alpha = 0
		backgroundColor = .white
		scroll.zoomScale = 1

		scroll.frame = bounds
		container.frame = scroll.bounds
		container.subviews.forEach { $0.removeFromSuperview() }
		rects.removeAll()
		let viewForSnapshot = viewForSnapshot(of: targetView)
		snapshot.image = viewForSnapshot.snapshotImage()
		let frame = targetView.convert(viewForSnapshot.bounds, to: container)
		container.addSubview(snapshot)
		snapshot.frame = frame

		for (deep, layer) in targetView.allSubviewsLayers.enumerated() {
			for subview in layer {
				let frame = subview.convert(subview.bounds, to: container)
				let view = UIView(frame: frame)
//				view.transform3D = CATransform3DTranslate(CATransform3DIdentity, 0, 0, CGFloat(deep) * 10)
				view.tintColor = tintColor
				view.layer.isDoubleSided = true
				layerConfiguration(view)
				let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
				view.addGestureRecognizer(tapGesture)
				container.addSubview(view)
				rects[view] = subview
			}
		}
		updateGrid()
		bringSubviewToFront(selectionView)
		bringSubviewToFront(controls)
		feedback.selectionChanged()
		controls.transform3D = CATransform3DTranslate(CATransform3DIdentity, 0, 0, 1000)
//		scroll.layer.sublayerTransform.m34 = -1 / 500
//		container.layer.sublayerTransform.m34 = -1 / 500
//		layer.sublayerTransform.m34 = -1 / 500
//		var transform = CATransform3DIdentity
//		transform.m34 = -1 / 500
//		scroll.transform3D = CATransform3DRotate(transform, .pi / 2.5, 1, 0, 0)

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
			UIView.animate(withDuration: 0.5) {
				self.container.alpha = 1
				self.controls.alpha = 1
			} completion: { _ in
				self.backgroundColor = .clear
			}
		}
	}

	override public func layoutSubviews() {
		super.layoutSubviews()
		updateControlsLayout()
	}
}

extension UIInspector: UIScrollViewDelegate {

	public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		container
	}

	public func scrollViewDidZoom(_ scrollView: UIScrollView) {
		if showGrid {
			drawGrid()
		}
	}

	public func scrollViewDidScroll(_ scrollView: UIScrollView) {
		if showGrid {
			drawGrid()
		}
	}
}

private extension UIInspector {

	func viewForSnapshot(of view: UIView) -> UIView {
		var view = view
		while let superview = view.superview, !isDescendant(of: superview) {
			view = superview
		}
		return view
	}
}

private extension UIInspector {

	func updateGrid() {
		removeGrid()
		horizontalGrid = rects.keys.flatMap {
			[$0.frame.minX, $0.frame.maxX]
		}
		horizontalGrid.insert(0, at: 0)
		horizontalGrid.append(container.bounds.width)
		horizontalGrid = Set(horizontalGrid).sorted()
		for grid in horizontalGrid {
			let line = UIGrid()
			line.grid = grid
			gridHViews.append(line)
		}

		verticalGrid = rects.keys.flatMap {
			[$0.frame.minY, $0.frame.maxY]
		}
		verticalGrid.insert(0, at: 0)
		verticalGrid.append(container.bounds.height)
		verticalGrid = Set(verticalGrid).sorted()

		for grid in verticalGrid {
			let line = UIGrid()
			line.grid = grid
			gridVViews.append(line)
		}
		for line in gridViews {
			line.backgroundColor = tintColor
			line.isUserInteractionEnabled = false
			line.isHidden = !showGrid
			addSubview(line)
		}
		if showGrid {
			drawGrid()
		}
	}

	func drawGrid() {
		for line in gridVViews {
			line.frame = container.convert(
				CGRect(x: 0, y: line.grid, width: container.bounds.width, height: 0),
				to: self
			)
			.insetBy(dx: 0, dy: -0.25)
		}
		for line in gridHViews {
			line.frame = container.convert(
				CGRect(x: line.grid, y: 0, width: 0, height: container.bounds.height),
				to: self
			)
			.insetBy(dx: -0.25, dy: 0)
		}
	}

	func removeGrid() {
		gridViews.forEach { $0.removeFromSuperview() }
		gridHViews.removeAll()
		gridVViews.removeAll()
	}

	func round(point: CGPoint) -> CGPoint {
		guard showGrid else { return point }
		let closestX = gridHViews.sorted {
			abs($0.frame.midX - point.x) < abs($1.frame.midX - point.x)
		}.first?.frame.midX ?? point.x
		let closestY = gridVViews.sorted {
			abs($0.frame.midY - point.y) < abs($1.frame.midY - point.y)
		}.first?.frame.midY ?? point.y
		let threshold: CGFloat = 15
		let x = abs(closestX - point.x) < threshold ? closestX : point.x
		let y = abs(closestY - point.y) < threshold ? closestY : point.y
		return CGPoint(x: x, y: y)
	}
}

private extension UIInspector {

	@objc private func handleTap(_ gesture: UITapGestureRecognizer) {
		guard let controller, let rect = gesture.view, let source = rects[rect] else { return }
		let hostingController = UIHostingController(rootView: Info(view: source, custom: customInfoView))
		hostingController.sheetPresentationController?.detents = [.medium(), .large()]
		controller.present(hostingController, animated: true)
	}
}

extension UIInspector: UIGestureRecognizerDelegate {

	public func gestureRecognizer(
		_ gestureRecognizer: UIGestureRecognizer,
		shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
	) -> Bool {
		false
	}
}

private extension UIInspector {

	func addDragGesture() {
		let drag = UILongPressGestureRecognizer(target: self, action: #selector(handleDrag(_:)))
		drag.minimumPressDuration = 0.2
		drag.delaysTouchesBegan = false
		drag.cancelsTouchesInView = true
		drag.delegate = self
		addGestureRecognizer(drag)
	}

	@objc private func handleDrag(_ gesture: UILongPressGestureRecognizer) {
		let location = gesture.location(in: self)
		if gesture.state == .began {
			feedback.selectionChanged()
			draggingView = controls.bounds.contains(gesture.location(in: controls)) ? controls : nil
			draggingStart = location
		}
		let translation = CGPoint(
			x: location.x - draggingStart.x,
			y: location.y - draggingStart.y
		)
		guard draggingView == nil else {
			if gesture.state == .began {
				draggingControlOffset = controlsOffset
			}
			controlsOffset = CGPoint(
				x: draggingControlOffset.x + translation.x,
				y: draggingControlOffset.y + translation.y
			)
			updateControlsLayout()
			return
		}
		switch mode {
		case .colorPalette:
			let location = gesture.location(in: snapshot)
			if gesture.state == .began {
				addColorPicker(at: location)
			}
			updateColorPicker(at: location)

			if gesture.state == .ended {
				removeColorPicker()
				UIPasteboard.general.string = hex
			}

		case .dimensionMeasurement:
			if gesture.state == .began {
				addSubview(selectionView)
				draggingStart = location
			}
			let startPoint = round(point: draggingStart)
			let endPoint = round(point: location)
			let translation = CGPoint(
				x: endPoint.x - startPoint.x,
				y: endPoint.y - startPoint.y
			)
			selectionView.frame = CGRect(
				origin: CGPoint(
					x: min(startPoint.x, endPoint.x),
					y: min(startPoint.y, endPoint.y)
				),
				size: CGSize(
					width: abs(translation.x),
					height: abs(translation.y)
				)
			)
			let selectedSize = convert(selectionView.frame, to: snapshot)
			selectionView.label.text = selectedSize.size.inspectorDescription
			if gesture.state == .ended {
				selectionView.removeFromSuperview()
			}
		}
	}
}

private extension UIInspector {

	func addControls() {
		updateButtons()
		controls.tintColor = tintColor
		setShadow(for: controls)
		addSubview(controls)
		updateControlsLayout()
	}

	func updateControlsLayout() {
		let size = controls.intrinsicContentSize
		let padding: CGFloat = 20
		controls.frame = CGRect(
			origin: CGPoint(
				x: bounds.width - size.width - padding + controlsOffset.x,
				y: bounds.height - size.height - safeAreaInsets.bottom - padding + controlsOffset.y
			),
			size: size
		)
		.inside(bounds)
	}
}

private extension UIInspector {

	func updateButtons() {
		controls.tintColor = tintColor
		controls.buttons = [
			UIInspectorControls.Button(
				selectedIcon: UIImage(systemName: "square.3.layers.3d.top.filled")!,
				unselectedIcon: UIImage(systemName: "square.3.layers.3d")!,
				isSelected: showLayers
			) { [weak self] in
				self?.showLayers.toggle()
			},
			UIInspectorControls.Button(
				icon: mode == .colorPalette ? UIImage(systemName: "eyedropper")! : UIImage(systemName: "pencil.and.ruler")!
			) { [weak self] in
				guard let self else { return }
				if mode == .colorPalette {
					mode = .dimensionMeasurement
				} else {
					mode = .colorPalette
				}
			},
			UIInspectorControls.Button(
				icon: UIImage(systemName: "grid")!,
				isSelected: showGrid
			) { [weak self] in
				self?.showGrid.toggle()
			},
			UIInspectorControls.Button(
				icon: UIImage(systemName: "arrow.clockwise")!
			) { [weak self] in
				self?.update()
			},
			UIInspectorControls.Button(
				icon: UIImage(systemName: "xmark.circle.fill")!
			) { [weak self] in
				self?.onClose?()
			},
		]
	}
}

private extension UIInspector {

	func addColorPicker(at point: CGPoint) {
		guard colorPalette.superview == nil else { return }
		colorPalette.alpha = 0
		setShadow(for: colorPalette)
		addSubview(colorPalette)
		updateColorPicker(at: point)
		UIView.animate(withDuration: 0.1) {
			self.colorPalette.alpha = 1
		}
	}

	func removeColorPicker() {
		UIView.animate(withDuration: 0.1) {
			self.colorPalette.alpha = 0
		} completion: { _ in
			self.colorPalette.removeFromSuperview()
		}
	}

	func updateColorPicker(at point: CGPoint) {
		if let color = snapshot.image?.pixelColor(at: snapshot.imagePixelPoint(from: point)) {
			colorPalette.color = color
			hex = color.hexString
		}
		let size = colorPalette.intrinsicContentSize
		let point = snapshot.convert(point, to: self)
		colorPalette.frame = CGRect(
			origin: CGPoint(
				x: point.x - size.width / 2,
				y: point.y - 60
			),
			size: size
		)
		.inside(bounds)
	}
}

private extension UIInspector {

	func setShadow(for view: UIView) {
		view.layer.shadowColor = UIInspector.foregroundColor.cgColor
		view.layer.shadowOpacity = UIScreen.main.traitCollection.userInterfaceStyle == .dark ? 0.2 : 0.07
		view.layer.shadowOffset = CGSize(width: 0, height: 2)
		view.layer.shadowRadius = 4
	}
}

private extension UIInspector {

	/// The available inspection modes.
	enum Mode: Equatable {
		/// Color picker mode for extracting colors from the UI.
		case colorPalette

		/// Measurement mode for measuring dimensions of UI elements.
		case dimensionMeasurement
	}
}

struct InspectorPreview: View {

	var body: some View {
		VStack(spacing: 14) {
			Image(systemName: "globe")
				.imageScale(.large)
				.foregroundStyle(.tint)
			Text("Hello, world!")

			Button("Show Inspector") {
				UIInspectorController.present()
			}
		}
		.padding()
	}
}

#Preview {
	InspectorPreview()
}
