import SwiftUI

/// A view controller that presents and manages a `UIInspector` view.
///
/// This controller handles presenting the inspector as a modal overlay on top of your app.
/// It's the main entry point for using the SwiftUIInspector framework.
///
/// ## Basic Usage
///
/// ```swift
/// // Present the inspector for a top view controller
/// UIInspectorController.present()
///
/// // Present the inspector for a specific view
/// UIInspectorController.present(for: myCustomView)
/// ```
///
/// ## Advanced Configuration
///
/// You can customize the inspector's appearance and behavior using the configure closure:
///
/// ```swift
/// UIInspectorController.present { inspector in
///     // Change the highlight color
///     inspector.tintColor = .systemGreen
///
///     // Customize how view layers are displayed
///     inspector.layerConfiguration = { view in
///         view.backgroundColor = .systemBlue.withAlphaComponent(0.2)
///         view.layer.borderWidth = 1
///         view.layer.borderColor = UIColor.systemBlue.cgColor
///     }
///
///     // Add custom information to the inspector detail view
///     inspector.customInfoView = { view in
///         AnyView(
///             VStack {
///                 if let button = view as? UIButton {
///                     Text("Button Title: \(button.title(for: .normal) ?? "None")")
///                 }
///                 Text("Alpha: \(view.alpha)")
///                 Text("Tag: \(view.tag)")
///             }
///         )
///     }
/// }
/// ```
///
/// ## SwiftUI Integration
///
/// You can use the inspector in SwiftUI by wrapping it in a button action:
///
/// ```swift
/// Button("Show Inspector") {
///     UIInspectorController.present()
/// }
/// ```
public final class UIInspectorController: UIViewController {

	/// Presents the inspector over the current view hierarchy.
	///
	/// This method finds the top-most view controller and presents the inspector over it.
	/// If the inspector is already presented, it updates the existing instance.
	///
	/// - Parameters:
	///   - view: Optional view to inspect. If nil, the root view of the top view controller is used.
	///   - configure: A closure to configure the inspector before it's displayed.
	/// - Returns: The presented inspector controller, or nil if presentation failed.
	@discardableResult
	public static func present(for view: UIView? = nil, configure: @escaping (UIInspector) -> Void = { _ in }) -> UIInspectorController? {
		guard let top = UIWindow.key?.rootViewController?.topPresented else { return nil }
		var isCurrent = false
		let inspector: UIInspectorController
		if let current = top as? UIInspectorController {
			isCurrent = true
			inspector = current
		} else {
			inspector = UIInspectorController()
		}
		configure(inspector.inspector)
		DispatchQueue.main.async {
			if isCurrent {
				if let view {
					inspector.inspect(view: view)
				} else {
					inspector.inspector.update()
				}
				return
			}
			top.present(inspector, animated: false)
			if let targetView = view ?? top.view {
				inspector.inspect(view: targetView)
			}
		}
		return inspector
	}

	public let inspector = UIInspector()

	override public func loadView() {
		view = inspector
	}

	/// Initializes a new inspector controller.
	///
	/// The controller is configured to present as a full-screen overlay with a fade transition.
	public init() {
		super.init(nibName: nil, bundle: nil)
		modalPresentationStyle = .overFullScreen
		modalTransitionStyle = .crossDissolve
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override public func viewDidLoad() {
		super.viewDidLoad()
		inspector.onClose = { [weak self] in
			self?.dismiss(animated: true)
		}
	}

	/// Inspects the specified view using this controller's inspector.
	///
	/// - Parameter view: The view to inspect
	public func inspect(view: UIView) {
		inspector.inspect(view: view)
	}
}
