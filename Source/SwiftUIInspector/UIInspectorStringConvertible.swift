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

extension CGColor: UIInspectorStringConvertible {

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

extension UIFont: UIInspectorStringConvertible {

	public var inspectorDescription: String {
		let name = familyName
		let size = pointSize
		let traits = fontDescriptor.symbolicTraits
		var result = "\(name) \(size)"
		if traits.contains(.traitBold) { result += " Bold" }
		if traits.contains(.traitItalic) { result += " Italic" }
		return result
	}
}

extension Optional: UIInspectorStringConvertible {

	public var inspectorDescription: String {
		guard let wrapped = self else { return "nil" }
		if let wrapped = wrapped as? UIInspectorStringConvertible {
			return wrapped.inspectorDescription
		}
		return "\(wrapped)"
	}
}

extension CALayerCornerCurve: UIInspectorStringConvertible {

	public var inspectorDescription: String {
		switch self {
		case .circular:
			return "Circular"
		case .continuous:
			return "Continuous"
		default:
			return rawValue.capitalized
		}
	}
}

extension UIView.ContentMode: UIInspectorStringConvertible {
	
	public var inspectorDescription: String {
		switch self {
		case .scaleToFill:
			return "Scale to Fill"
		case .scaleAspectFit:
			return "Aspect Fit"
		case .scaleAspectFill:
			return "Aspect Fill"
		case .redraw:
			return "Redraw"
		case .center:
			return "Center"
		case .top:
			return "Top"
		case .bottom:
			return "Bottom"
		case .left:
			return "Left"
		case .right:
			return "Right"
		case .topLeft:
			return "Top Left"
		case .topRight:
			return "Top Right"
		case .bottomLeft:
			return "Bottom Left"
		case .bottomRight:
			return "Bottom Right"
		@unknown default:
			return rawValue.description
		}
	}
}

extension UIImage.RenderingMode: UIInspectorStringConvertible {

	public var inspectorDescription: String {
		switch self {
		case .automatic:
			return "Automatic"
		case .alwaysOriginal:
			return "Original"
		case .alwaysTemplate:
			return "Template"
		@unknown default:
			return rawValue.description
		}
	}
}

extension UIImage.ResizingMode: UIInspectorStringConvertible {
	
	public var inspectorDescription: String {
		switch self {
		case .tile:
			return "Tile"
		case .stretch:
			return "Stretch"
		@unknown default:
			return rawValue.description
		}
	}
}

extension NSTextAlignment: UIInspectorStringConvertible {
	
	public var inspectorDescription: String {
		switch self {
		case .left:
			return "Left"
		case .center:
			return "Center"
		case .right:
			return "Right"
		case .justified:
			return "Justified"
		case .natural:
			return "Natural"
		default:
			return rawValue.description
		}
	}
}

extension NSLineBreakMode: UIInspectorStringConvertible {
	
	public var inspectorDescription: String {
		switch self {
		case .byWordWrapping:
			return "Word Wrapping"
		case .byCharWrapping:
			return "Character Wrapping"
		case .byClipping:
			return "Clipping"
		case .byTruncatingHead:
			return "Truncate Head"
		case .byTruncatingTail:
			return "Truncate Tail"
		case .byTruncatingMiddle:
			return "Truncate Middle"
		default:
			return rawValue.description
		}
	}
}

extension UIControl.ContentHorizontalAlignment: UIInspectorStringConvertible {
	
	public var inspectorDescription: String {
		switch self {
		case .center:
			return "Center"
		case .left:
			return "Left"
		case .right:
			return "Right"
		case .fill:
			return "Fill"
		case .leading:
			return "Leading"
		case .trailing:
			return "Trailing"
		default:
			return rawValue.description
		}
	}
}

extension UIControl.ContentVerticalAlignment: UIInspectorStringConvertible {
	
	public var inspectorDescription: String {
		switch self {
		case .center:
			return "Center"
		case .top:
			return "Top"
		case .bottom:
			return "Bottom"
		case .fill:
			return "Fill"
		default:
			return rawValue.description
		}
	}
}

extension UIControl.State: UIInspectorStringConvertible {
	
	public var inspectorDescription: String {
		guard !isEmpty else { return "None" }
		var states = [String]()
		var state: UIControl.State = []
		if contains(.normal) { states.append("Normal"); state.insert(.normal) }
		if contains(.highlighted) { states.append("Highlighted"); state.insert(.highlighted) }
		if contains(.disabled) { states.append("Disabled"); state.insert(.disabled) }
		if contains(.selected) { states.append("Selected"); state.insert(.selected) }
		if contains(.focused) { states.append("Focused"); state.insert(.focused) }
		if contains(.application) { states.append("Application"); state.insert(.application) }
		if contains(.reserved) { states.append("Reserved"); state.insert(.reserved) }
		if self != state {
			return rawValue.hexString
		}
		return states.joined(separator: ", ")
	}
}

extension NSDirectionalEdgeInsets: UIInspectorStringConvertible {
	
	public var inspectorDescription: String {
		String(format: "Top: %.1f, Leading: %.1f, Bottom: %.1f, Trailing: %.1f",
			   top, leading, bottom, trailing)
	}
}

extension UIEdgeInsets: UIInspectorStringConvertible {
	
	public var inspectorDescription: String {
		String(format: "Top: %.1f, Left: %.1f, Bottom: %.1f, Right: %.1f",
			   top, left, bottom, right)
	}
}

extension UIStackView.Alignment: UIInspectorStringConvertible {
	
	public var inspectorDescription: String {
		switch self {
		case .fill:
			return "Fill"
		case .leading:
			return "Leading"
		case .trailing:
			return "Trailing"
		case .top:
			return "Top"
		case .bottom:
			return "Bottom"
		case .center:
			return "Center"
		default:
			return "\(self)"
		}
	}
}

extension UIStackView.Distribution: UIInspectorStringConvertible {
	
	public var inspectorDescription: String {
		switch self {
		case .fill:
			return "Fill"
		case .fillEqually:
			return "Fill Equally"
		case .fillProportionally:
			return "Fill Proportionally"
		case .equalSpacing:
			return "Equal Spacing"
		case .equalCentering:
			return "Equal Centering"
		default:
			return "\(self)"
		}
	}
}

extension NSLayoutConstraint.Axis: UIInspectorStringConvertible {

	public var inspectorDescription: String {
		switch self {
		case .horizontal:
			return "Horizontal"
		case .vertical:
			return "Vertical"
		default:
			return "\(self)"
		}
	}
}

@available(iOS 13.4, *)
extension UIAxis: UIInspectorStringConvertible {

	public var inspectorDescription: String {
		switch self {
		case .horizontal:
			return "Horizontal"
		case .vertical:
			return "Vertical"
		default:
			return "\(self)"
		}
	}
}

extension UITextField.BorderStyle: UIInspectorStringConvertible {
	
	public var inspectorDescription: String {
		switch self {
		case .none:
			return "None"
		case .line:
			return "Line"
		case .bezel:
			return "Bezel"
		case .roundedRect:
			return "Rounded Rect"
		default:
			return "\(self)"
		}
	}
}

extension UIKeyboardType: UIInspectorStringConvertible {
	 
	public var inspectorDescription: String {
		switch self {
		case .default:
			return "Default"
		case .asciiCapable:
			return "ASCII Capable"
		case .numbersAndPunctuation:
			return "Numbers and Punctuation"
		case .URL:
			return "URL"
		case .numberPad:
			return "Number Pad"
		case .phonePad:
			return "Phone Pad"
		case .namePhonePad:
			return "Name Phone Pad"
		case .emailAddress:
			return "Email Address"
		case .decimalPad:
			return "Decimal Pad"
		case .twitter:
			return "Twitter"
		case .webSearch:
			return "Web Search"
		case .asciiCapableNumberPad:
			return "ASCII Capable Number Pad"
		default:
			return "\(self)"
		}
	}
}

extension UITextField.ViewMode: UIInspectorStringConvertible {
	
	public var inspectorDescription: String {
		switch self {
		case .never:
			return "Never"
		case .whileEditing:
			return "While Editing"
		case .unlessEditing:
			return "Unless Editing"
		case .always:
			return "Always"
		default:
			return "\(self)"
		}
	}
}
