import SwiftUI

/// A view that presents a UI inspector for debugging and inspecting views in SwiftUI.
public struct Inspector: UIViewRepresentable {

	private let view: UIView?
	private let rect: CGRect?
	private let configure: (UIInspector) -> Void

	public init(
		for view: UIView? = nil,
		at rect: CGRect? = nil,
		configure: @escaping (UIInspector) -> Void = { _ in }
	) {
		self.view = view ?? UIWindow.key?.rootViewController?.topPresented.view
		self.rect = rect
		self.configure = configure
	}

	public func makeUIView(context: Context) -> UIInspector {
		UIInspector()
	}

	public func updateUIView(_ uiView: UIInspector, context: Context) {
		uiView.inspectTargetRect = rect
		if #available(iOS 14.0, *) {
			uiView.tintColor = UIColor(Color.accentColor)
		}
		configure(uiView)
		if let view = view ?? UIWindow.key?.rootViewController?.topPresented.view, view !== uiView.targetView {
			uiView.inspect(view: view, at: rect)
		}
	}
}

public extension View {

	/// Presents a UI inspector for the view.
	func inspector(_ isPresented: Binding<Bool>, configure: @escaping (UIInspector) -> Void = { _ in }) -> some View {
		modifier(InspectControllerModifier(isPresented: isPresented, configure: configure))
	}
}

private struct InspectControllerModifier: ViewModifier {
	
	@Binding var isPresented: Bool
	let configure: (UIInspector) -> Void

	func body(content: Content) -> some View {
		content
			.background(
				Background(isPresented: $isPresented, configure: configure)
					.allowsHitTesting(false)
			)
	}

	private struct Background: UIViewRepresentable {

		@Binding var isPresented: Bool
		let configure: (UIInspector) -> Void

		func makeUIView(context: Context) -> UIView {
			IgnoredView()
		}

		func updateUIView(_ uiView: UIView, context: Context) {
			guard isPresented != context.coordinator.wasPresented else {
				return
			}
			context.coordinator.wasPresented = isPresented
			if isPresented {
				context.coordinator.inspector = UIInspectorController.present(at: uiView.convert(uiView.bounds, to: nil)) {
					if #available(iOS 14.0, *) {
						$0.tintColor = UIColor(Color.accentColor)
					}
					configure($0)
				}
				context.coordinator.inspector?.onDismiss = {
					context.coordinator.wasPresented = false
					isPresented = false
				}
			} else {
				context.coordinator.inspector?.dismiss(animated: true)
			}
		}

		func makeCoordinator() -> Coordinator {
			Coordinator()
		}
		
		final class Coordinator {
			
			weak var inspector: UIInspectorController?
			var wasPresented = false
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
								let controller = UIInspectorController.present {
									if #available(iOS 14.0, *) {
										$0.tintColor = UIColor(Color.accentColor)
									}
								}
								controller?.onDismiss = {
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

