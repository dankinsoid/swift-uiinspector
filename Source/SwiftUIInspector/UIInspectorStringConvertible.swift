import SwiftUI

/// A protocol for objects that can provide a custom string representation for the inspector.
///
/// Implement this protocol to control how your custom types are displayed in the inspector.
public protocol UIInspectorStringConvertible {

	/// A string representation of the object suitable for display in the inspector.
	var inspectorDescription: String { get }
}

extension CGSize: UIInspectorStringConvertible {

	public var inspectorDescription: String {
		String(format: "%.1f × %.1f", width, height)
	}
}

extension CGPoint: UIInspectorStringConvertible {

	public var inspectorDescription: String {
		String(format: "(%.1f, %.1f)", x, y)
	}
}

extension CGRect: UIInspectorStringConvertible {

	public var inspectorDescription: String {
		"\(origin.inspectorDescription) @ \(size.inspectorDescription)"
	}
}

extension UIColor: UIInspectorStringConvertible {

	public var inspectorDescription: String { hexString }
}

extension CATransform3D: UIInspectorStringConvertible {

	public var inspectorDescription: String {
		let isPerspective = m14 != 0 || m24 != 0 || m34 != 0 || m44 != 1
		let translation = CGPoint(x: m41, y: m42)
		let scaleX = sqrt(m11 * m11 + m21 * m21 + m31 * m31)
		let scaleY = sqrt(m12 * m12 + m22 * m22 + m32 * m32)
		let scaleZ = sqrt(m13 * m13 + m23 * m23 + m33 * m33)

		if !isPerspective, scaleX == 1, scaleY == 1, translation == .zero { return "none" }

		var result = String(format: "Translate: (%.1f, %.1f), Scale: (%.2f, %.2f, %.2f)",
		                    translation.x, translation.y, scaleX, scaleY, scaleZ)

		if isPerspective {
			result += String(format: ", Perspective: [%.2f %.2f %.2f %.2f]",
			                 m14, m24, m34, m44)
		}
		return result
	}
}

public extension UIView {

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
