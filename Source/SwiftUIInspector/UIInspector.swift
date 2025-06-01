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
open class UIInspector: UIView {
	
	/// The view that is currently being inspected.
	open private(set) weak var targetView: UIView?

	/// The background color for inspector UI elements.
	/// Defaults to a dark/light mode adaptive color.
	public static var backgroundColor = UIColor(dark: .black, light: .white)

	/// The tint color for inspector UI elements and highlights.
	/// Defaults to a pink/magenta color that adapts to dark/light mode.
	public static var tintColor = UIColor.systemBlue
	
	public static var highlightAlpha: CGFloat = 0.5

	/// The foreground color for text and icons in the inspector.
	/// Defaults to white in dark mode and black in light mode.
	public static var foregroundColor = UIColor(dark: .white, light: .black)

	/// Customizes the additional information view shown for inspected views.
	///
	/// Use this to add your own custom information to the inspector detail view.
	/// - Parameter view: The view being inspected
	/// - Returns: A SwiftUI view wrapped in `AnyView`
	public var customInfoView: (UIView) -> AnyView = { _ in AnyView(EmptyView()) }

	/// Defines the animation duration for the inspector's update.
	open var showUpdateAnimation = true

	/// Closure to configure the custom buttons in the inspector controls.
	open var customButtons: (UIInspector) -> [UIInspectorButton] = { _ in [] }

	/// Whether to enable magnification of the inspected view.
	open var isMagnificationEnabled = false {
		didSet {
			guard isMagnificationEnabled != oldValue else { return }
			if isMagnificationEnabled {
				enableMagnification()
			} else {
				disableMagnification()
			}
			reloadControls()
		}
	}

	/// Whether to enable pipettee functionality for color picking.
	open var isPipetteeEnabled = false {
		didSet {
			guard isPipetteeEnabled != oldValue else { return }
			if isPipetteeEnabled {
				isMeasurementEnabled = false
			}
			#if targetEnvironment(simulator)
			scroll.isScrollEnabled = !isPipetteeEnabled
			#endif
			reloadControls()
		}
	}

	/// Whether to enable measurement functionality in the inspector.
	open var isMeasurementEnabled = true {
		didSet {
			guard isMeasurementEnabled != oldValue else { return }
			if isMeasurementEnabled {
				isPipetteeEnabled = false
			}
			#if targetEnvironment(simulator)
			scroll.isScrollEnabled = !isMeasurementEnabled
			#endif
			reloadControls()
		}
	}

	/// Whether to show the edges of the inspected view and subviews.
	open var areEdgesVisible = true {
		didSet {
			edgesContainer.isHidden = !areEdgesVisible
			inspector3D.showBorderOverlay = areEdgesVisible
			if areEdgesVisible {
				drawEdges()
			}
			reloadControls()
		}
	}

	/// Whether to enable 3D view inspection.
	open var show3DView = false {
		didSet {
			guard oldValue != show3DView else { return }
			if show3DView {
				showInspector3D()
			} else {
				hideInspector3D()
			}
			reloadControls()
		}
	}

	/// Closure called when the close button is tapped.
	var onClose: (() -> Void)?

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
	private var selectedRect: (any UIInspectorItem)?
	private var highlightedViews: [UIView: UIColor] = [:]

	var inspectTargetRect: CGRect?
	private var rects: [UIViewInspectorItem] = []
	private var rectsBySource: [UIView: UIViewInspectorItem] = [:]

	private let edgesContainer = UIView()
	private let edgeWidth: CGFloat = 2.0 / UIScreen.main.scale
	private var highlightedEdges: Set<UIEdgeLine> = []
	private var edgeViews: [UIEdgeLine] = []

	private weak var draggingView: UIView?
	private var draggingControlOffset: CGPoint = .zero
	private var draggingStart: CGPoint = .zero

	private lazy var feedback = UISelectionFeedbackGenerator()
	private lazy var drag = UILongPressGestureRecognizer(target: self, action: #selector(handleDrag(_:)))

	private var hex = ""
	private var isFirstAppear = true
	private var controlsOffset: CGPoint = .zero

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
		selectionView.backgroundColor = selectionColor
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

		edgesContainer.isUserInteractionEnabled = false
		edgesContainer.backgroundColor = .clear
		addSubview(edgesContainer)
		addSubview(inspector3D)
		inspector3D.isHidden = true
		inspector3D.notifyViewSelected = { [weak self] view, parents in
			self?.didTap(on: view, underlying: parents, underlyingType: .hierarchy)
		}

		animationView.backgroundColor = .white

		addControls()
		addDragGesture()
	}

	@available(*, unavailable)
	required public init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override open func didMoveToWindow() {
		super.didMoveToWindow()
		update()
		reloadControls()
	}

	override open func tintColorDidChange() {
		super.tintColorDidChange()
		for grid in edgeViews {
			grid.backgroundColor = tintColor
		}
		inspector3D.tintColor = tintColor
		reloadControls()
		selectionView.backgroundColor = selectionColor
		measurementLabel.textColor = tintColor
		background.tintColor = tintColor
	}

	/// Inspects the specified view, showing its hierarchy and properties.
	///
	/// This method captures the view's current state and displays it in the inspector.
	/// - Parameters:
	///  - view: The view to inspect
	///  - rect: An optional rectangle within the view to focus on.
	open func inspect(view: UIView, at rect: CGRect? = nil) {
		targetView = view
		inspectTargetRect = rect
		update()
	}

	/// Updates the inspector view with the current state of the target view.
	///
	/// Call this method to refresh the inspector when the target view has changed.
	open func update() {
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

	open func highlight(view: UIView, with color: UIColor? = nil) {
		let color = color ?? tintColor.withAlphaComponent(UIInspector.highlightAlpha)
		let rect = rectsBySource[view]
		let node = inspector3D.viewNodesBySource[view]
		highlightedViews[view] = color
		rect?.highlight(with: color)
		node?.highlight(with: color)
	}

	open func unhighlight(view: UIView? = nil) {
		if let view {
			highlightedViews[view] = nil
			rectsBySource[view]?.unhighlight()
			inspector3D.viewNodesBySource[view]?.unhighlight()
		} else {
			highlightedViews.keys.forEach {
				rectsBySource[$0]?.unhighlight()
				inspector3D.viewNodesBySource[$0]?.unhighlight()
			}
			highlightedViews.removeAll()
		}
	}

	override open func layoutSubviews() {
		super.layoutSubviews()
		background.frame = bounds
		updateControlsLayout()
	}

	open func reloadControls() {
		updateButtons()
	}
}

extension UIInspector: UIScrollViewDelegate {

	open func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		container
	}

	open func scrollViewDidZoom(_ scrollView: UIScrollView) {
		if areEdgesVisible {
			drawEdges()
		}
	}

	open func scrollViewDidScroll(_ scrollView: UIScrollView) {
		if areEdgesVisible {
			drawEdges()
		}
	}
}

private extension UIInspector {

	func _update(reset: Bool) {
		guard let targetView, window != nil else { return }
		var targetSnapshot: UIViewSnapshot?
		if reset {
			feedback.selectionChanged()
			scroll.zoomScale = 1
			scroll.frame = bounds
			container.frame = scroll.bounds
			edgesContainer.frame = bounds
			inspector3D.frame = bounds
		}

		rects.removeAll()
		rectsBySource.removeAll()
		container.subviews.forEach { $0.removeFromSuperview() }
		highlightedViews.removeAll()
		let viewForSnapshot = targetView
		snapshot.image = viewForSnapshot.snapshotImage()
		let frame = viewForSnapshot.convert(viewForSnapshot.bounds, to: container)
		snapshot.frame = frame
		container.addSubview(snapshot)

		let groupped = targetView.selfAndAllVisibleSubviewsLayers
			.map {
				$0.filter { insideRect($0) && !$0.needIgnoreInInspector }
					.map { UIViewSnapshot($0) }
			}
			.filter {
				!$0.isEmpty
			}
		for (_, layer) in groupped.enumerated() {
			for snapshot in layer {
				let frame = container.convert(snapshot.globalRect, from: container.window)
				let view = UIViewInspectorItem(snapshot, frame: frame)
				view.highlightColor = tintColor.withAlphaComponent(UIInspector.highlightAlpha)
				let tapGesture = JustTapGesture(target: self, action: #selector(handleTap(_:)))
				view.addGestureRecognizer(tapGesture)
				container.addSubview(view)
				rects.append(view)
				rectsBySource[snapshot.source] = view
				if snapshot.source === targetView {
					targetSnapshot = snapshot
				}
			}
		}
		updateEdges()
		if areEdgesVisible {
			drawEdges()
		}

		inspector3D.update(
			targetView: targetSnapshot ?? UIViewSnapshot(targetView),
			groupedViews: groupped,
			in: inspectTargetRect
		)

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

	func showInspector3D() {
		if scroll.zoomScale > 1 {
			UIView.animate(withDuration: 0.2) { [self] in
				scroll.zoomScale = 1
			} completion: { [self] _ in
				showInspector3DWithoutAnimation()
			}
		} else {
			showInspector3DWithoutAnimation()
		}
	}

	func showInspector3DWithoutAnimation() {
		inspector3D.showAppearAnimation { [self] in
			for (view, color) in highlightedViews {
				inspector3D.viewNodesBySource[view]?.highlight(with: color)
			}
			inspector3D.isHidden = false
		}
	}

	func hideInspector3D() {
		inspector3D.animateFocus { [weak self] in
			self?.inspector3D.isHidden = true
		}
	}
}

private extension UIInspector {

	func updateEdges() {
		removeEdges()
		let rects = [container] + rects
		for rect in rects {
			for x in [rect.frame.minX, rect.frame.maxX] {
				let line = UIEdgeLine()
				line.location = x
				line.axis = .horizontal
				line.sourceRect = rect.frame
				edgeViews.append(line)
			}
		}
		for rect in rects {
			for y in [rect.frame.minY, rect.frame.maxY] {
				let line = UIEdgeLine()
				line.location = y
				line.axis = .vertical
				line.sourceRect = rect.frame
				edgeViews.append(line)
			}
		}

		for line in edgeViews {
			line.backgroundColor = tintColor
			line.isUserInteractionEnabled = false
			line.isHidden = !areEdgesVisible
			edgesContainer.addSubview(line)
		}
	}

	func drawEdges() {
		let threshold: CGFloat = 5
		let halfWidth = edgeWidth / 2
		for line in edgeViews {
			switch line.axis {
			case .horizontal:
				let size = min(line.sourceRect.size.height, container.bounds.height)
				line.frame = container.convert(
					CGRect(x: line.location, y: line.sourceRect.midY - size / 2, width: 0, height: size),
					to: edgesContainer
				)
				.insetBy(dx: -halfWidth, dy: -threshold)
			case .vertical:
				let size = min(line.sourceRect.size.width, container.bounds.width)
				line.frame = container.convert(
					CGRect(x: line.sourceRect.midX - size / 2, y: line.location, width: size, height: 0),
					to: edgesContainer
				)
				.insetBy(dx: -threshold, dy: -halfWidth)
			}
		}
	}

	func removeEdges() {
		edgeViews.forEach { $0.removeFromSuperview() }
		edgeViews.removeAll()
	}

	func round(point: CGPoint) -> CGPoint {
		guard !show3DView, !isMagnificationEnabled else { return point }
		let point = convert(point, to: snapshot).roundedToScale
		guard areEdgesVisible else { return snapshot.convert(point, to: self) }
		let sortedX = edgeViews
			.filter { isVisible($0) && $0.axis == .horizontal }
			.map { $0.convert($0.bounds, to: snapshot).midX }
			.sorted {
				abs($0 - point.x) < abs($1 - point.x)
			}
		let closestX = sortedX.first ?? point.x
		let sortedY = edgeViews
			.filter { isVisible($0) && $0.axis == .vertical }
			.map { $0.convert($0.bounds, to: snapshot).midY }
			.sorted {
				abs($0 - point.y) < abs($1 - point.y)
			}

		let closestY = sortedY.first ?? point.y
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
		guard areEdgesVisible else { return }
		let currentHighlighted = highlightedEdges
		highlightedEdges = []
		let highlightedWidth = 2.0
		if !points.isEmpty {
			let points = points.map { convert($0, to: container) }
			for edgeView in edgeViews {
				switch edgeView.axis {
				case .horizontal:
					if points.contains(where: { isSameEdge(edgeView.location, $0.x) }) {
						highlightedEdges.insert(edgeView)
						updateWidth(edge: edgeView, width: highlightedWidth)
					}
				case .vertical:
					if points.contains(where: { isSameEdge(edgeView.location, $0.y) }) {
						highlightedEdges.insert(edgeView)
						updateWidth(edge: edgeView, width: highlightedWidth)
					}
				}
			}
		}
		for edgeView in currentHighlighted.subtracting(highlightedEdges) {
			updateWidth(edge: edgeView, width: edgeWidth)
		}
	}

	func isSameEdge(_ value1: CGFloat, _ value2: CGFloat) -> Bool {
		abs(value1 - value2) < 1 / UIScreen.main.scale
	}

	func updateWidth(edge: UIEdgeLine, width: CGFloat) {
		switch edge.axis {
		case .horizontal:
			edge.frame = CGRect(
				origin: CGPoint(x: edge.frame.midX, y: edge.frame.minY),
				size: CGSize(width: 0, height: edge.frame.height)
			)
			.insetBy(dx: -width / 2, dy: 0)
		case .vertical:
			edge.frame = CGRect(
				origin: CGPoint(x: edge.frame.minX, y: edge.frame.midY),
				size: CGSize(width: edge.frame.width, height: 0)
			)
			.insetBy(dx: 0, dy: -width / 2)
		}
	}
}

private extension UIInspector {

	@objc private func handleTap(_ gesture: JustTapGesture) {
		guard let rect = gesture.view as? UIViewInspectorItem else { return }
		let deeps = Dictionary(
			container
				.subviews
				.compactMap { $0 as? UIViewInspectorItem }
				.enumerated()
				.map { ($0.element, $0.offset) }
		) { _, n in n }
		if gesture.state == .ended {
			didTap(
				on: rect,
				underlying: rects.filter {
					$0 !== rect && $0.bounds.contains(gesture.location(in: $0))
				}
				.sorted { deeps[$0, default: 0] > deeps[$1, default: 0] },
				underlyingType: .atThisLocation
			)
		}
	}

	private func didTap(
		on rect: any UIInspectorItem,
		underlying: [any UIInspectorItem],
		underlyingType: Info.UnderlyingType
	) {
		guard let controller else { return }
		feedback.selectionChanged()
		let hostingController = DeinitHostingController(
			rootView: Info(
				view: rect,
				underlying: underlying,
				underlyingType: underlyingType,
				custom: customInfoView
			) { [weak self] in
				self?.selectedRect = $0
			}
		)
		hostingController.onDeinit = { [weak self] in
			self?.selectedRect?.unhighlight()
			self?.selectedRect = nil
		}
		if #available(iOS 15.0, *) {
			hostingController.sheetPresentationController?.detents = [.medium(), .large()]
		}
		controller.present(hostingController, animated: true)
		rect.highlight()
		selectedRect = rect
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
		guard !show3DView else {
			// remove if measurement will be supported in 3D inspector
			return isMagnificationEnabled || isPipetteeEnabled
		}
		return isMeasurementEnabled || isMagnificationEnabled || isPipetteeEnabled
	}
}

private extension UIInspector {
	
	var selectionColor: UIColor {
		tintColor.withAlphaComponent(0.5)
	}

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
			if draggingView != nil || !(show3DView && !isMagnificationEnabled && isMeasurementEnabled) {
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
			guard !show3DView else { return }
			drawSelectionRectGesture(gesture, location: location)
		} else if isPipetteeEnabled {
			let pixel: CGPoint
			let location = gesture.location(in: self)
			if show3DView {
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
			if !show3DView || isMagnificationEnabled {
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
		if show3DView, !isMagnificationEnabled {
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

			if !show3DView || isMagnificationEnabled {
				selectionView.frame = rect
			} else
			if let p0 = inspector3D.convertFromTarget(startPoint),
			   let p1 = inspector3D.convertFromTarget(endPoint)
			{
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
		var buttons: [UIInspectorButton] = [
			UIInspectorButton(
				selectedIcon: UIImage(systemName: "square.stack.3d.down.right.fill"),
				unselectedIcon: UIImage(systemName: "square.stack.3d.down.right"),
				isSelected: show3DView
			) { [weak self] in
				self?.show3DView.toggle()
			},
		]
#if targetEnvironment(simulator)
		buttons.append(
			UIInspectorButton(
				icon: UIImage(systemName: "arrow.up.left.and.down.right.magnifyingglass"),
				isSelected: isMagnificationEnabled
			) { [weak self] in
				self?.isMagnificationEnabled.toggle()
			}
		)
#endif
		buttons += [
			UIInspectorButton(
				selectedIcon: UIImage(systemName: "eyedropper.full"),
				unselectedIcon: UIImage(systemName: "eyedropper"),
				isSelected: isPipetteeEnabled,
				isEnabled: !isMagnificationEnabled
			) { [weak self] in
				guard let self else { return }
				isPipetteeEnabled.toggle()
			},
			UIInspectorButton(
				selectedIcon: UIImage(systemName: "ruler.fill"),
				unselectedIcon: UIImage(systemName: "ruler"),
				isSelected: isMeasurementEnabled,
				isEnabled: !show3DView && !isMagnificationEnabled
			) { [weak self] in
				guard let self else { return }
				isMeasurementEnabled.toggle()
			},
			UIInspectorButton(
				icon: UIImage(systemName: "grid"),
				isSelected: areEdgesVisible
			) { [weak self] in
				self?.areEdgesVisible.toggle()
			},
			UIInspectorButton(
				icon: UIImage(systemName: "arrow.clockwise")
			) { [weak self] in
				self?.update()
			},
		]
		if let onClose {
			buttons.append(
				UIInspectorButton(
					icon: UIImage(systemName: "xmark.circle.fill")
				) {
					onClose()
				}
			)
		}
		buttons += customButtons(self)
		controls.buttons = buttons
	}
}

private extension UIInspector {

	var viewsToDisableDuringMagnification: [UIView] {
		[inspector3D, scroll, container]
	}

	func enableMagnification() {
		for view in viewsToDisableDuringMagnification {
			view.isUserInteractionEnabled = false
		}
	}

	func disableMagnification() {
		for view in viewsToDisableDuringMagnification {
			view.isUserInteractionEnabled = true
		}
	}

	func zoomToFitSelection() {
		guard !show3DView else {
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
