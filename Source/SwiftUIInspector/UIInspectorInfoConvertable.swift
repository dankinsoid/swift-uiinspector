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
