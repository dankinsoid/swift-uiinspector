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

extension View {

	/// Adds a button to show the inspector in the specified alignment.
	///
	/// - Parameter alignment: The alignment of the inspector button
	/// - Returns: A view with the inspector button overlay
	///
	/// - Warning: This modifier works only on iOS simulators.
	@ViewBuilder
	public func previewInspector(
		alignment: Alignment = .bottomTrailing
	) -> some View {
		modifier(ShowInspectorModifier(alignment: alignment))
	}
}

private struct ShowInspectorModifier: ViewModifier {

	let alignment: Alignment
	@State private var inspectorPresented = false
	
	func body(content: Content) -> some View {
		#if targetEnvironment(simulator)
		content
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
			.overlay(
				Group {
					if !inspectorPresented {
						Button {
							inspectorPresented = true
							DispatchQueue.main.async {
								UIInspectorController.present()?.onDismiss = {
									inspectorPresented = false
								}
							}
						} label: {
							Image(systemName: "eyeglasses")
								.resizable()
								.aspectRatio(contentMode: .fit)
								.foregroundColor(Color(UIInspector.foregroundColor))
								.padding(6)
								.frame(width: 36, height: 36)
								.background(Circle().fill(Color(UIInspector.backgroundColor)))
								.shadow(
									color: Color(UIInspector.foregroundColor).opacity(0.17),
									radius: 4,
									x: 0,
									y: 1
								)
						}
						.padding(20)
					}
				},
				alignment: alignment
			)
		#else
		content
		#endif
	}
}

