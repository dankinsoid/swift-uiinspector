import UIKit

/// A protocol to mark views that should be ignored in the UIInspector.
public protocol UIInspectorIgnorable {
	
	var ignoreInInspector: Bool { get }
}

extension UIView {

	var needIgnoreInInspector: Bool {
		if let ignorable = self as? UIInspectorIgnorable {
			return ignorable.ignoreInInspector
		}
		return false
	}
}

final class IgnoredView: UIView, UIInspectorIgnorable {
	
	var ignoreInInspector = true
}
