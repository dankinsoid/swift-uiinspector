import SwiftUI

public final class UIInspectorController: UIViewController {

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

	private let inspector = UIInspector()

	public override func loadView() {
		view = inspector
	}
	
	public init() {
		super.init(nibName: nil, bundle: nil)
		modalPresentationStyle = .overFullScreen
		modalTransitionStyle = .crossDissolve
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	public override func viewDidLoad() {
		super.viewDidLoad()
		inspector.controller = self
		inspector.onClose = { [weak self] in
			self?.dismiss(animated: true)
		}
	}

	public func inspect(view: UIView) {
		inspector.inspect(view: view)
	}
}
