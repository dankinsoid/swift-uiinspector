import Foundation

/// A protocol for objects that can provide custom information for the inspector.
///
/// Implement this protocol on your custom views or view controllers to provide
/// additional information in the inspector detail view.
public protocol UIInspectorInfoConvertable {

	/// The sections of information to display in the inspector.
	///
	/// Return an array of `UIInspector.Section` objects, each containing
	/// related information cells to display.
	var inspectorInfo: [UIInspector.Section] { get }
}

public extension UIView {

	/// Default inspector information for UIView.
	///
	/// This includes the view's class, frame size and location, background color,
	var defaultInspectorInfo: [UIInspector.Section] {
		[
			UIInspector.Section(
				title: "Type",
				cells: [
					UIInspector.Cell("Class", Self.self),
				]
			),
			UIInspector.Section(
				title: "Frame",
				cells: [
					UIInspector.Cell("Size", frame.size),
					UIInspector.Cell("Location", frame.origin),
				]
			),
			UIInspector.Section(
				title: "Basic",
				cells: [
					UIInspector.Cell("Background", backgroundColor ?? UIColor.clear),
					UIInspector.Cell("Tint", tintColor ?? UIColor.clear),
					UIInspector.Cell("Opacity", alpha),
					UIInspector.Cell("Transform", transform3D),
				]
			),
		]
	}
}

extension UILabel: UIInspectorInfoConvertable {

	public var inspectorInfo: [UIInspector.Section] {
		defaultInspectorInfo + [
			UIInspector.Section(title: "Label", cells: [
				UIInspector.Cell("Text", text ?? ""),
				UIInspector.Cell("Font", font),
				UIInspector.Cell("Text Color", textColor ?? UIColor.clear),
				UIInspector.Cell("Text Alignment", textAlignment),
				UIInspector.Cell("Line Break Mode", lineBreakMode),
			]),
		]
	}
}
