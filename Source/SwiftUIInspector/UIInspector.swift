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
	public var hideFullScreenLayers = false {
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
	private lazy var selectionView = UIView()
	private lazy var measurementLabel = UIMeasurementLabel()
	private let inspector3D = UIInspector3D()
	private let animationView = UIView()

	private(set) public weak var targetView: UIView?
	var inspectTargetRect: CGRect?
	private var rects: [UIView: UIView] = [:]
	private var hiddenRects: Set<UIView> = []

	private let gridContainer = UIView()
	private let gridWidth: CGFloat = 2.0 / UIScreen.main.scale
	private var highlightedGrid: Set<UIGrid> = []
	private var gridViews: [UIGrid] = []

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
							inspector3D.inspect(view: targetView, in: inspectTargetRect, animate: true) { [self] in
							 inspector3D.isHidden = false
						 }
						}
					} else {
						inspector3D.inspect(view: targetView, in: inspectTargetRect, animate: true) { [self] in
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
		selectionView.backgroundColor = tintColor.withAlphaComponent(0.5)
		measurementLabel.textColor = tintColor
		
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
		selectionView.backgroundColor = tintColor.withAlphaComponent(0.5)
		measurementLabel.textColor = tintColor
		background.tintColor = tintColor
	}
	
	/// Inspects the specified view, showing its hierarchy and properties.
	///
	/// This method captures the view's current state and displays it in the inspector.
	/// - Parameters:
	///  - view: The view to inspect
	///  - rect: An optional rectangle within the view to focus on.
	public func inspect(view: UIView, at rect: CGRect? = nil) {
		targetView = view
		inspectTargetRect = rect
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
		let viewForSnapshot = targetView
		snapshot.image = viewForSnapshot.snapshotImage()
		let frame = viewForSnapshot.convert(viewForSnapshot.bounds, to: container)
		snapshot.frame = frame
		container.addSubview(snapshot)

		for (_, layer) in targetView.selfAndAllVisibleSubviewsLayers.enumerated() {
			for subview in layer {
				let frame = subview.convert(subview.bounds, to: container)
				guard !hideFullScreenLayers || frame.size.less(than: container.frame.size),
					  insideRect(subview),
					  !subview.needIgnoreInInspector else {
					continue
				}
				let view = UIView(frame: frame)
				view.backgroundColor = .clear
				let tapGesture = JustTapGesture(target: self, action: #selector(handleTap(_:)))
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
		let rects = [container] + rects.keys
		for rect in rects {
			for x in [rect.frame.minX, rect.frame.maxX] {
				let line = UIGrid()
				line.grid = x
				line.axis = .horizontal
				line.sourceRect = rect.frame
				gridViews.append(line)
			}
		}
		for rect in rects {
			for y in [rect.frame.minY, rect.frame.maxY] {
				let line = UIGrid()
				line.grid = y
				line.axis = .vertical
				line.sourceRect = rect.frame
				gridViews.append(line)
			}
		}

		for line in gridViews {
			line.backgroundColor = tintColor
			line.isUserInteractionEnabled = false
			line.isHidden = !showGrid
			gridContainer.addSubview(line)
		}
	}

	func drawGrid() {
		let threshold: CGFloat = 5
		let halfWidth = gridWidth / 2
		for line in gridViews {
			switch line.axis {
			case .horizontal:
				let size = min(line.sourceRect.size.height, container.bounds.height)
				line.frame = container.convert(
					CGRect(x: line.grid, y: line.sourceRect.midY - size / 2, width: 0, height: size),
					to: gridContainer
				)
				.insetBy(dx: -halfWidth, dy: -threshold)
			case .vertical:
				let size = min(line.sourceRect.size.width, container.bounds.width)
				line.frame = container.convert(
					CGRect(x: line.sourceRect.midX - size / 2, y: line.grid, width: size, height: 0),
					to: gridContainer
				)
				.insetBy(dx: -threshold, dy: -halfWidth)
			}
		}
	}

	func removeGrid() {
		gridViews.forEach { $0.removeFromSuperview() }
		gridViews.removeAll()
	}

	func round(point: CGPoint) -> CGPoint {
		guard !showLayers, !isMagnificationEnabled else { return point }
		let point = convert(point, to: snapshot).roundedToScale
		guard showGrid else { return snapshot.convert(point, to: self) }
		let sortedX = gridViews
			.filter { isVisible($0) && $0.axis == .horizontal }
			.sorted {
				abs($0.grid - point.x) < abs($1.grid - point.x)
			}
		let closestX = sortedX.first?.grid ?? point.x
//		sortedX
//			.first {
//				min(point.y - $0.frame.minY, $0.frame.maxY - point.y) > 0
//			}?.frame.midX ?? sortedX.first?.frame.midX ?? point.x

		let sortedY = gridViews
			.filter { isVisible($0) && $0.axis == .vertical }
			.sorted {
				abs($0.grid - point.y) < abs($1.grid - point.y)
			}

		let closestY = sortedY.first?.grid ?? point.y
//		sortedY
//			.first {
//				min(point.x - $0.frame.minX, $0.frame.maxX - point.x) > 0
//			}?.frame.midY ?? sortedY.first?.frame.midY ?? point.y
//
		let threshold: CGFloat = 10 / scroll.zoomScale
		let x = abs(closestX - point.x) < threshold ? closestX : point.x
		let y = abs(closestY - point.y) < threshold ? closestY : point.y
		return snapshot.convert(CGPoint(x: x, y: y), to: self)
	}

	func isVisible(_ view: UIView) -> Bool {
		view.convert(view.bounds, to: container)
			.intersects(convert(bounds, to: container))
	}

	func insideRect(_ view: UIView) -> Bool {
		guard let inspectTargetRect, let targetView, targetView !== view else { return true }
		return inspectTargetRect.contains(view.convert(view.bounds, to: targetView))
	}

	func highlightGrid(points: [CGPoint]) {
		guard showGrid else { return }
		let currentHighlighted = highlightedGrid
		highlightedGrid = []
		let highlightedWidth = 2.0
		if !points.isEmpty {
			let points = points.map { convert($0, to: container) }
			for grid in gridViews {
				switch grid.axis {
				case .horizontal:
					if points.contains(where: { isSameGrid(grid.grid, $0.x) }) {
						highlightedGrid.insert(grid)
						updateWidth(grid: grid, width: highlightedWidth)
					}
				case .vertical:
					if points.contains(where: { isSameGrid(grid.grid, $0.y) }) {
						highlightedGrid.insert(grid)
						updateWidth(grid: grid, width: highlightedWidth)
					}
				}
			}
		}
		for grid in currentHighlighted.subtracting(highlightedGrid) {
			updateWidth(grid: grid, width: gridWidth)
		}
	}
	
	func isSameGrid(_ value1: CGFloat, _ value2: CGFloat) -> Bool {
		abs(value1 - value2) < 1 / UIScreen.main.scale
	}
	
	func updateWidth(grid: UIGrid, width: CGFloat) {
		switch grid.axis {
		case .horizontal:
			grid.frame = CGRect(
				origin: CGPoint(x: grid.frame.midX, y: grid.frame.minY),
				size: CGSize(width: 0, height: grid.frame.height)
			)
			.insetBy(dx: -width / 2, dy: 0)
		case .vertical:
			grid.frame = CGRect(
				origin: CGPoint(x: grid.frame.minX, y: grid.frame.midY),
				size: CGSize(width: grid.frame.width, height: 0)
			)
			.insetBy(dx: 0, dy: -width / 2)
		}
	}
}

private extension UIInspector {
	
	@objc private func handleTap(_ gesture: JustTapGesture) {
		guard let rect = gesture.view, let source = rects[rect] else { return }
		if gesture.state == .ended {
			didTap(on: source, rect: rect)
		}
	}
	
	private func didTap(on source: UIView, rect: UIView?) {
		guard let controller else { return }
		feedback.selectionChanged()
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
				rect.backgroundColor = tintColor.withAlphaComponent(0.5)
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
		otherGestureRecognizer is JustTapGesture
	}

	override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		guard gestureRecognizer.numberOfTouches == 1 else {
			return false
		}
		if controls.bounds.contains(gestureRecognizer.location(in: controls)) {
			return controls.draggableArea.bounds.contains(gestureRecognizer.location(in: controls.draggableArea))
		}
		guard !showLayers else {
			// remove if measurement will be supported in 3D inspector
			return isMagnificationEnabled || isPipetteeEnabled
		}
		return isMeasurementEnabled || isMagnificationEnabled || isPipetteeEnabled
	}
}

private extension UIInspector {

	func addDragGesture() {
		#if targetEnvironment(simulator)
		drag.minimumPressDuration = 0
		scroll.isScrollEnabled = false
		#else
		drag.minimumPressDuration = 0.15
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
			if draggingView != nil || !(showLayers && !isMagnificationEnabled && isMeasurementEnabled) {
				feedback.selectionChanged()
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
			controlsOffset = CGPoint(
				x: draggingControlOffset.x + translation.x,
				y: draggingControlOffset.y + translation.y
			)
			updateControlsLayout()
			return
		}
		guard !isMagnificationEnabled else {
			drawSelectionRectGesture(gesture, location: location)
			return
		}
		if isMeasurementEnabled {
			guard !showLayers else { return }
			drawSelectionRectGesture(gesture, location: location)
		} else if isPipetteeEnabled {
			let pixel: CGPoint
			let location = gesture.location(in: self)
			if showLayers {
				guard let point = inspector3D.convert(gesture.location(in: inspector3D)) else {
					removeColorPicker()
					return
				}
				pixel = inspector3D.convert(point, to: snapshot)
			} else {
				pixel = gesture.location(in: snapshot)
			}
			if colorPipette.superview == nil {
				addColorPicker(at: location, pixel: pixel)
			}
			updateColorPicker(at: location, pixel: pixel)
			
			if gesture.state.isFinal {
				UIPasteboard.general.string = hex
				updateColorPicker(at: location, pixel: pixel, text: "COPIED!")
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
					self?.removeColorPicker()
				}
			}
		}
	}
	
	func drawSelectionRectGesture(
		_ gesture: UILongPressGestureRecognizer,
		location: CGPoint
	) {
		if gesture.state == .began {
			if !showLayers || isMagnificationEnabled {
				addSubview(selectionView)
			}
			if !isMagnificationEnabled {
				addSubview(measurementLabel)
			}
			bringSubviewToFront(controls)
			draggingStart = location
		}
		let point0: CGPoint?
		let point1: CGPoint?
		if showLayers, !isMagnificationEnabled {
			point0 = inspector3D.convert(draggingStart).map { inspector3D.convert($0, to: self) }
			point1 = inspector3D.convert(location).map { inspector3D.convert($0, to: self) }
		} else {
			point0 = draggingStart
			point1 = location
		}
		if let point0, let point1 {
			let startPoint = round(point: point0)
			let endPoint = round(point: point1)
			let translation = CGPoint(
				x: endPoint.x - startPoint.x,
				y: endPoint.y - startPoint.y
			)
			if !isMagnificationEnabled {
				highlightGrid(points: [startPoint, endPoint])
			}
			var rect = CGRect(
				origin: CGPoint(
					x: min(startPoint.x, endPoint.x),
					y: min(startPoint.y, endPoint.y)
				),
				size: CGSize(
					width: abs(translation.x),
					height: abs(translation.y)
				)
			)
		    
			if !showLayers || isMagnificationEnabled { 
				selectionView.frame = rect
			} else
				if let p0 = inspector3D.convertFromTarget(startPoint),
				   let p1 = inspector3D.convertFromTarget(endPoint) {
				rect = CGRect(
					origin: CGPoint(
						x: min(p0.x, p1.x),
						y: min(p0.y, p1.y)
					),
					size: CGSize(
						width: abs(p0.x - p1.x),
						height: abs(p0.y - p1.y)
					)
				)
				inspector3D.showMeasurementPlane(p0, p1)
			}
			let selectedSize = convert(rect, to: snapshot)
			measurementLabel.text = selectedSize.size.inspectorDescription
			measurementLabel.place(in: rect)
		}
		if gesture.state.isFinal {
			if isMagnificationEnabled {
				zoomToFitSelection()
				isMagnificationEnabled = false
			} else {
				highlightGrid(points: [])
			}
			selectionView.removeFromSuperview()
			measurementLabel.removeFromSuperview()
			inspector3D.hideMeasurementPlane()
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
				isEnabled: !isMagnificationEnabled
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

	func addColorPicker(at point: CGPoint, pixel: CGPoint) {
		guard colorPipette.superview == nil else { return }
		colorPipette.alpha = 0
		setShadow(for: colorPipette)
		setShadow(for: measurementLabel)
		addSubview(colorPipette)
		updateColorPicker(at: point, pixel: pixel)
		UIView.animate(withDuration: 0.1) {
			self.colorPipette.alpha = 1
		}
	}

	func removeColorPicker() {
		UIView.animate(withDuration: 0.25) {
			self.colorPipette.alpha = 0
		} completion: { _ in
			self.colorPipette.removeFromSuperview()
		}
	}

	func updateColorPicker(at point: CGPoint, pixel: CGPoint, text: String? = nil) {
		guard colorPipette.superview != nil, !colorPipette.isHidden else { return }
		if let color = snapshot.image?.pixelColor(at: snapshot.imagePixelPoint(from: pixel)) {
			colorPipette.color = color
			colorPipette.text = text ?? color.hexString
			hex = color.hexString
		}
		let size = colorPipette.intrinsicContentSize
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
		view.layer.shadowOpacity = UIScreen.main.traitCollection.userInterfaceStyle == .dark ? 0.17 : 0.07
		view.layer.shadowOffset = CGSize(width: 0, height: 2)
		view.layer.shadowRadius = 6
	}
}

#Preview {
	VStack(spacing: 14) {
		Image(systemName: "globe")
			.imageScale(.large)
			.foregroundColor(.blue)
		Text("Hello, world!")
		
		Button("Show Inspector") {
			UIInspectorController.present()
		}
	}
	.previewInspector()
}
