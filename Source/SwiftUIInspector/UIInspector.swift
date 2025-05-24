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
/// // Get an inspector instance from the inspector controller
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

	/// Closure called when the close button is tapped.
	var onClose: (() -> Void)?

	/// Customizes the additional information view shown for inspected views.
	///
	/// Use this to add your own custom information to the inspector detail view.
	/// - Parameter view: The view being inspected
	/// - Returns: A SwiftUI view wrapped in `AnyView`
	public var customInfoView: (UIView) -> AnyView = { _ in AnyView(EmptyView()) }
	
	/// Defines the animation duration for the inspector's update.
	public var showUpdateAnimation = true

	/// Whether to hide full-screen layers in the inspector.
	public var hideFullScreenLayers = true {
		didSet {
			_update(reset: false)
		}
	}

	private let background = UISceneBackground()
	private let scroll = UIScrollView()
	private let container = UIView()
	private let snapshot = UIImageView()
	private var controls = UIInspectorControls()
	private lazy var colorPipette = UIColorPipette()
	private lazy var selectionView = UIMeasurementSelection()
	private let inspector3D = UIInspector3D()
	private let animationView = UIView()

	private(set) public weak var targetView: UIView?
	private var rects: [UIView: UIView] = [:]
	private var hiddenRects: Set<UIView> = []

	private let gridContainer = UIView()
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

	private lazy var feedback = UISelectionFeedbackGenerator()
	private lazy var drag = UILongPressGestureRecognizer(target: self, action: #selector(handleDrag(_:)))

	private var hex = ""
	private var isFirstAppear = true
	private var controlsOffset: CGPoint = .zero
	
	private var isMagnificationEnabled = false {
		didSet {
			guard isMagnificationEnabled != oldValue else { return }
			if isMagnificationEnabled {
				enableMagnification()
			} else {
				disableMagnification()
			}
			updateButtons()
		}
	}

	private var isPipetteeEnabled = false {
		didSet {
			guard isPipetteeEnabled != oldValue else { return }
			if isPipetteeEnabled {
				isMeasurementEnabled = false
			}
#if targetEnvironment(simulator)
			scroll.isScrollEnabled = !isPipetteeEnabled
#endif
			updateButtons()
		}
	}
	
	private var isMeasurementEnabled = true {
		didSet {
			guard isMeasurementEnabled != oldValue else { return }
			if isMeasurementEnabled {
				isPipetteeEnabled = false
			}
#if targetEnvironment(simulator)
			scroll.isScrollEnabled = !isMeasurementEnabled
#endif
			updateButtons()
		}
	}

	private var showGrid = true {
		didSet {
			gridContainer.isHidden = !showGrid
			inspector3D.showBorderOverlay = showGrid
			if showGrid {
				drawGrid()
			}
			updateButtons()
		}
	}

	private var showLayers = false {
		didSet {
			guard oldValue != showLayers else { return }
			if showLayers {
				if let targetView {
					if scroll.zoomScale > 1 {
						UIView.animate(withDuration: 0.2) { [self] in
							scroll.zoomScale = 1
						} completion: { [self] _ in
							inspector3D.inspect(view: targetView, animate: true) { [self] in
							 inspector3D.isHidden = false
						 }
						}
					} else {
						inspector3D.inspect(view: targetView, animate: true) { [self] in
							inspector3D.isHidden = false
						}
					}
				}
			} else {
				inspector3D.animateFocus { [weak self] in
					self?.inspector3D.isHidden = true
				}
			}
			updateButtons()
		}
	}

	/// Initializes a new inspector view.
	///
	/// The inspector starts with default settings and is ready to inspect views
	/// once added to the view hierarchy.
	public init() {
		super.init(frame: .zero)
		addSubview(background)
		tintColor = Self.tintColor
		backgroundColor = .clear
		background.tintColor = tintColor
		selectionView.color = tintColor
		inspector3D.tintColor = tintColor
		clipsToBounds = true
	
		snapshot.layer.magnificationFilter = .nearest
		snapshot.isUserInteractionEnabled = false
		snapshot.contentMode = .scaleToFill

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

		gridContainer.isUserInteractionEnabled = false
		gridContainer.backgroundColor = .clear
		addSubview(gridContainer)
		addSubview(inspector3D)
		inspector3D.isHidden = true
		inspector3D.notifyViewSelected = { [weak self] view in
			self?.didTap(on: view, rect: nil)
		}
		
		animationView.backgroundColor = .white
	
		addControls()
		addDragGesture()
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override public func didMoveToWindow() {
		super.didMoveToWindow()
		update()
		updateButtons()
	}

	override public func tintColorDidChange() {
		super.tintColorDidChange()
		for grid in gridViews {
			grid.backgroundColor = tintColor
		}
		inspector3D.tintColor = tintColor
		updateButtons()
		selectionView.color = tintColor
		background.tintColor = tintColor
	}
	
	/// Inspects the specified view, showing its hierarchy and properties.
	///
	/// This method captures the view's current state and displays it in the inspector.
	/// - Parameter view: The view to inspect
	public func inspect(view: UIView) {
		targetView = view
		update()
	}

	/// Updates the inspector view with the current state of the target view.
	///
	/// Call this method to refresh the inspector when the target view has changed.
	public func update() {
		guard let targetView, let window, targetView.window === window else { return }
		if showUpdateAnimation {
			animationView.frame = bounds
			animationView.alpha = 1
			addSubview(animationView)
			setNeedsDisplay()
		}

		DispatchQueue.main.async {
			self._update(reset: true)
		}
	}

	override public func layoutSubviews() {
		super.layoutSubviews()
		background.frame = bounds
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

	func _update(reset: Bool = false) {
		guard let targetView, window != nil else { return }

		if reset {
			feedback.selectionChanged()
			scroll.zoomScale = 1
			scroll.frame = bounds
			container.frame = scroll.bounds
			gridContainer.frame = bounds
			inspector3D.frame = bounds
		}
		if !inspector3D.isHidden {
			inspector3D.update(animate: reset)
		}

		rects.removeAll()
		hiddenRects.removeAll()

		container.subviews.forEach { $0.removeFromSuperview() }
		let viewForSnapshot = viewForSnapshot(of: targetView)
		snapshot.image = viewForSnapshot.snapshotImage()
		let frame = viewForSnapshot.convert(viewForSnapshot.bounds, to: container)
		snapshot.frame = frame
		container.addSubview(snapshot)

		for (_, layer) in targetView.allVisibleSubviewsLayers.enumerated() {
			for subview in layer {
				let frame = subview.convert(subview.bounds, to: container)
				guard !hideFullScreenLayers || frame.size.less(than: container.frame.size) else {
					continue
				}
				let view = UIView(frame: frame)
				view.backgroundColor = .clear
				let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
				view.addGestureRecognizer(tapGesture)
				container.addSubview(view)
				rects[view] = subview
			}
		}
		updateGrid()
		if showGrid {
			drawGrid()
		}

		if showUpdateAnimation, reset {
			DispatchQueue.main.async { [self] in
				UIView.animate(withDuration: 0.5) { [self] in
					animationView.alpha = 0
				} completion: { [self] _ in
					animationView.removeFromSuperview()
				}
			}
		}
	}

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
		horizontalGrid.removeAll()
		let rects = [container] + rects.keys
		for rect in rects {
			for x in [rect.frame.minX, rect.frame.maxX] {
				let line = UIGrid()
				line.grid = x
				line.sourceRect = rect.frame
				gridHViews.append(line)
				horizontalGrid.append(x)
			}
		}
		horizontalGrid = Set(horizontalGrid).sorted()

		verticalGrid.removeAll()
		for rect in rects {
			for y in [rect.frame.minY, rect.frame.maxY] {
				let line = UIGrid()
				line.grid = y
				line.sourceRect = rect.frame
				gridVViews.append(line)
				verticalGrid.append(y)
			}
		}
		verticalGrid = Set(verticalGrid).sorted()

		for line in gridViews {
			line.backgroundColor = tintColor
			line.isUserInteractionEnabled = false
			line.isHidden = !showGrid
			gridContainer.addSubview(line)
		}
	}

	func drawGrid() {
		let threshold: CGFloat = 15
		for line in gridVViews {
			let size = min(line.sourceRect.size.width, container.bounds.width)
			line.frame = container.convert(
				CGRect(x: line.sourceRect.midX - size / 2, y: line.grid, width: size, height: 0),
				to: gridContainer
			)
			.insetBy(dx: -threshold, dy: -0.25)
		}
		for line in gridHViews {
			let size = min(line.sourceRect.size.height, container.bounds.height)
			line.frame = container.convert(
				CGRect(x: line.grid, y: line.sourceRect.midY - size / 2, width: 0, height: size),
				to: gridContainer
			)
			.insetBy(dx: -0.25, dy: -threshold)
		}
	}

	func removeGrid() {
		gridViews.forEach { $0.removeFromSuperview() }
		gridHViews.removeAll()
		gridVViews.removeAll()
	}

	func round(point: CGPoint) -> CGPoint {
		guard !showLayers else { return point }
		let point = snapshot.convert(convert(point, to: snapshot).roundedToScale, to: self)
		guard showGrid else { return point }
		let sortedX = gridHViews
			.filter(isVisible)
			.sorted {
				abs($0.frame.midX - point.x) < abs($1.frame.midX - point.x)
			}
		let closestX = sortedX.first?.frame.midX ?? point.x
//		sortedX
//			.first {
//				min(point.y - $0.frame.minY, $0.frame.maxY - point.y) > 0
//			}?.frame.midX ?? sortedX.first?.frame.midX ?? point.x

		let sortedY = gridVViews
			.filter(isVisible)
			.sorted {
				abs($0.frame.midY - point.y) < abs($1.frame.midY - point.y)
			}

		let closestY = sortedY.first?.frame.midY ?? point.y
//		sortedY
//			.first {
//				min(point.x - $0.frame.minX, $0.frame.maxX - point.x) > 0
//			}?.frame.midY ?? sortedY.first?.frame.midY ?? point.y
//
		let threshold: CGFloat = 15
		let x = abs(closestX - point.x) < threshold ? closestX : point.x
		let y = abs(closestY - point.y) < threshold ? closestY : point.y
		return CGPoint(x: x, y: y)
	}

	private func isVisible(_ view: UIView) -> Bool {
		view.convert(view.bounds, to: container)
			.intersects(convert(bounds, to: container))
	}
}

private extension UIInspector {
	
	@objc private func handleTap(_ gesture: UITapGestureRecognizer) {
		guard let rect = gesture.view, let source = rects[rect] else { return }
		didTap(on: source, rect: rect)
	}
	
	private func didTap(on source: UIView, rect: UIView?) {
		guard let controller else { return }
		let hostingController = DeinitHostingController(
			rootView: Info(view: source, custom: customInfoView)
		)
		hostingController.onDeinit = { [weak self] in
			self?.inspector3D.clearSelection()
			if let rect {
				self?.unselect(rect: rect)
			}
		}
		if #available(iOS 15.0, *) {
			hostingController.sheetPresentationController?.detents = [.medium(), .large()]
		}
		controller.present(hostingController, animated: true)
		if let rect {
			UIView.animate(withDuration: 0.1) { [self] in
				rect.backgroundColor = tintColor.withAlphaComponent(0.2)
			}
		}
	}

	private func unselect(rect: UIView) {
		UIView.animate(withDuration: 0.1) {
			rect.backgroundColor = .clear
		}
	}
}

private final class DeinitHostingController<Content: View>: UIHostingController<Content> {

	var onDeinit: (() -> Void)?

	deinit {
		onDeinit?()
	}
}

extension UIInspector: UIGestureRecognizerDelegate {

	public func gestureRecognizer(
		_ gestureRecognizer: UIGestureRecognizer,
		shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
	) -> Bool {
		false
	}

	override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		guard gestureRecognizer.numberOfTouches == 1 else {
			return false
		}
		if isMeasurementEnabled || isMagnificationEnabled || isPipetteeEnabled {
			return true
		}
		guard !showLayers else {
			return false
		}
		return controls.bounds.contains(gestureRecognizer.location(in: controls))
	}
}

private extension UIInspector {

	func addDragGesture() {
		#if targetEnvironment(simulator)
		drag.minimumPressDuration = 0
		scroll.isScrollEnabled = false
		#else
		drag.minimumPressDuration = 0.1
		#endif
		drag.cancelsTouchesInView = false
		drag.delaysTouchesBegan = false
		drag.delegate = self
		addGestureRecognizer(drag)
	}

	@objc private func handleDrag(_ gesture: UILongPressGestureRecognizer) {
		let location = gesture.location(in: self)
		if gesture.state == .began {
			draggingView = controls.bounds.contains(gesture.location(in: controls)) ? controls : nil
			draggingStart = location
			if draggingView != nil || !showLayers {
				feedback.selectionChanged()
			}
		}
		if gesture.state.isFinal {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
				controls.isUserInteractionEnabled = true
			}
		}
		let translation = CGPoint(
			x: location.x - draggingStart.x,
			y: location.y - draggingStart.y
		)
		guard draggingView == nil else {
			if gesture.state == .began {
				draggingControlOffset = controlsOffset
			}
			if max(abs(translation.y), abs(translation.x)) > 3 {
				controls.isUserInteractionEnabled = false
				controlsOffset = CGPoint(
					x: draggingControlOffset.x + translation.x,
					y: draggingControlOffset.y + translation.y
				)
				updateControlsLayout()
			}
			return
		}
		guard !isMagnificationEnabled else {
			drawSelectionRectGesture(gesture, location: location)
			return
		}
		guard !showLayers else { return }
		if isMeasurementEnabled {
			drawSelectionRectGesture(gesture, location: location)
		} else if isPipetteeEnabled {
			let location = gesture.location(in: snapshot)
			if gesture.state == .began {
				addColorPicker(at: location)
			}
			updateColorPicker(at: location)

			if gesture.state.isFinal {
				removeColorPicker()
				UIPasteboard.general.string = hex
			}
		}
	}
	
	func drawSelectionRectGesture(
		_ gesture: UILongPressGestureRecognizer,
		location: CGPoint
	) {
		if gesture.state == .began {
			addSubview(selectionView)
			bringSubviewToFront(controls)
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
		if gesture.state.isFinal {
			if isMagnificationEnabled {
				zoomToFitSelection()
				isMagnificationEnabled = false
			}
			selectionView.removeFromSuperview()
		}
	}
}

private extension UIInspector {

	func addControls() {
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
		var buttons: [UIInspectorControls.Button] = [
			UIInspectorControls.Button(
				selectedIcon: UIImage(systemName: "square.3.layers.3d.top.filled"),
				unselectedIcon: UIImage(systemName: "square.3.layers.3d"),
				isSelected: showLayers
			) { [weak self] in
				self?.showLayers.toggle()
			}
		]
#if targetEnvironment(simulator)
		buttons.append(
			UIInspectorControls.Button(
				icon: UIImage(systemName: "arrow.up.left.and.down.right.magnifyingglass"),
				isSelected: isMagnificationEnabled
			) { [weak self] in
				self?.isMagnificationEnabled.toggle()
			}
		)
#endif
		buttons += [
			UIInspectorControls.Button(
				selectedIcon: UIImage(systemName: "eyedropper.full"),
				unselectedIcon: UIImage(systemName: "eyedropper"),
				isSelected: isPipetteeEnabled,
				isEnabled: !showLayers && !isMagnificationEnabled
			) { [weak self] in
				guard let self else { return }
				isPipetteeEnabled.toggle()
			},
			UIInspectorControls.Button(
				selectedIcon: UIImage(systemName: "pencil.and.ruler.fill"),
				unselectedIcon: UIImage(systemName: "pencil.and.ruler"),
				isSelected: isMeasurementEnabled,
				isEnabled: !showLayers && !isMagnificationEnabled
			) { [weak self] in
				guard let self else { return }
				isMeasurementEnabled.toggle()
			},
			UIInspectorControls.Button(
				icon: UIImage(systemName: "grid"),
				isSelected: showGrid
			) { [weak self] in
				self?.showGrid.toggle()
			},
			UIInspectorControls.Button(
				icon: UIImage(systemName: "arrow.clockwise")
			) { [weak self] in
				self?.update()
			},
		]
		if let onClose {
			buttons.append(
				UIInspectorControls.Button(
					icon: UIImage(systemName: "xmark.circle.fill")
				) {
					onClose()
				}
			)
		}
		controls.buttons = buttons
	}
}

private extension UIInspector {
	
	var viewsToDisableDuringMagnification: [UIView] {
		[inspector3D, scroll, container]
	}
	
	func enableMagnification() {
		viewsToDisableDuringMagnification.forEach { view in
			view.isUserInteractionEnabled = false
		}
	}
	
	func disableMagnification() {
		viewsToDisableDuringMagnification.forEach { view in
			view.isUserInteractionEnabled = true
		}
	}

	func zoomToFitSelection() {
		guard !showLayers else {
			inspector3D.zoomToFit(rect: selectionView.convert(selectionView.bounds, to: inspector3D))
			return
		}
		let rect = selectionView.convert(selectionView.bounds, to: snapshot)
		let zoomScale = min(
			scroll.bounds.width / rect.width,
			scroll.bounds.height / rect.height
		)
		UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) { [self] in
			scroll.zoomScale = zoomScale
			scroll.scrollRectToVisible(
				snapshot.convert(rect, to: scroll),
				animated: false
			)
		}
	}
}

private extension UIInspector {

	func addColorPicker(at point: CGPoint) {
		guard colorPipette.superview == nil else { return }
		colorPipette.alpha = 0
		setShadow(for: colorPipette)
		addSubview(colorPipette)
		updateColorPicker(at: point)
		UIView.animate(withDuration: 0.1) {
			self.colorPipette.alpha = 1
		}
	}

	func removeColorPicker() {
		UIView.animate(withDuration: 0.1) {
			self.colorPipette.alpha = 0
		} completion: { _ in
			self.colorPipette.removeFromSuperview()
		}
	}

	func updateColorPicker(at point: CGPoint) {
		if let color = snapshot.image?.pixelColor(at: snapshot.imagePixelPoint(from: point)) {
			colorPipette.color = color
			hex = color.hexString
		}
		let size = colorPipette.intrinsicContentSize
		let point = snapshot.convert(point, to: self)
		colorPipette.frame = CGRect(
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
		view.layer.shadowOpacity = UIScreen.main.traitCollection.userInterfaceStyle == .dark ? 0.14 : 0.07
		view.layer.shadowOffset = CGSize(width: 0, height: 2)
		view.layer.shadowRadius = 4
	}
}

private extension UIInspector {

	/// The available inspection modes.
	enum Mode: Equatable {
		/// Color picker mode for extracting colors from the UI.
		case colorPipette

		/// Measurement mode for measuring dimensions of UI elements.
		case dimensionMeasurement
	}
}

struct InspectorPreview: View {

	var body: some View {
		VStack(spacing: 14) {
			Image(systemName: "globe")
				.imageScale(.large)
				.foregroundColor(.blue)
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
