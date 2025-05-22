import SwiftUI

public struct Inspector: UIViewRepresentable {

	private let view: UIView?
	private let configure: (UIInspector) -> Void

	public init(
		for view: UIView? = nil,
		configure: @escaping (UIInspector) -> Void = { _ in }
	) {
		self.view = view ?? UIWindow.key?.rootViewController?.topPresented.view
		self.configure = configure
	}

	public func makeUIView(context: Context) -> UIInspector {
		UIInspector()
	}

	public func updateUIView(_ uiView: UIInspector, context: Context) {
		configure(uiView)
		if let view, view !== uiView.targetView {
			uiView.inspect(view: view)
		}
	}
}
