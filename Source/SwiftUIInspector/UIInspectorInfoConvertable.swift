import SwiftUI

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
		var result = [
			UIInspector.Section(
				title: "Basic",
				cells: [
					UIInspector.Cell("Class", Self.self),
					UIInspector.Cell("Size", frame.size),
					UIInspector.Cell("Location", frame.origin),
					UIInspector.Cell("Background", backgroundColor ),
					UIInspector.Cell("Tint", tintColor ),
					UIInspector.Cell("Opacity", alpha),
					UIInspector.Cell("Transform", transform3D),
				]
			),
		]
		if let scroll = self as? UIScrollView {
			result += scroll.defaultScrollInspectorInfo
		}
		return result
	}
}

extension UILabel: UIInspectorInfoConvertable {

	public var inspectorInfo: [UIInspector.Section] {
		defaultInspectorInfo + [
			UIInspector.Section(title: "Label", cells: [
				UIInspector.Cell("Text", text ?? ""),
				UIInspector.Cell("Font", font),
				UIInspector.Cell("Text Color", textColor ),
				UIInspector.Cell("Text Alignment", textAlignment),
				UIInspector.Cell("Line Break Mode", lineBreakMode),
				UIInspector.Cell("Number of Lines", numberOfLines),
				UIInspector.Cell("Adjusts Font Size", adjustsFontSizeToFitWidth),
			]),
		]
	}
}

extension UIButton: UIInspectorInfoConvertable {

	public var inspectorInfo: [UIInspector.Section] {
		defaultInspectorInfo + [
			UIInspector.Section(title: "Button", cells: [
				UIInspector.Cell("Title", title(for: .normal) ?? ""),
				UIInspector.Cell("Title Color", titleColor(for: .normal) ),
				UIInspector.Cell("Image", currentImage != nil ? "Set" : "None"),
				UIInspector.Cell("Font", titleLabel?.font ?? UIFont.systemFont(ofSize: 17)),
				UIInspector.Cell("Content Horizontal", contentHorizontalAlignment),
				UIInspector.Cell("Content Vertical", contentVerticalAlignment),
				UIInspector.Cell("Is Enabled", isEnabled),
				UIInspector.Cell("Is Selected", isSelected),
				UIInspector.Cell("Is Highlighted", isHighlighted),
			]),
		]
	}
}

extension UIImageView: UIInspectorInfoConvertable {

	public var inspectorInfo: [UIInspector.Section] {
		var cells: [UIInspector.Cell] = [
			UIInspector.Cell("Content Mode", contentMode),
			UIInspector.Cell("Is Highlighted", isHighlighted),
		]

		if let image {
			cells.append(contentsOf: [
				UIInspector.Cell("Image Size", image.size),
				UIInspector.Cell("Image Scale", image.scale),
				UIInspector.Cell("Rendering Mode", image.renderingMode),
				UIInspector.Cell("Pixel Dimensions", "\(image.pixelWidth) × \(image.pixelHeight)"),
			])
		} else {
			cells.append(UIInspector.Cell("Image", "None"))
		}

		return defaultInspectorInfo + [
			UIInspector.Section(title: "Image View", cells: cells),
		]
	}
}

extension UITextField: UIInspectorInfoConvertable {

	public var inspectorInfo: [UIInspector.Section] {
		defaultInspectorInfo + [
			UIInspector.Section(title: "Text Field", cells: [
				UIInspector.Cell("Text", text ?? ""),
				UIInspector.Cell("Placeholder", placeholder ?? ""),
				UIInspector.Cell("Font", font ?? UIFont.systemFont(ofSize: 17)),
				UIInspector.Cell("Text Color", textColor ),
				UIInspector.Cell("Text Alignment", textAlignment),
				UIInspector.Cell("Border Style", borderStyle),
				UIInspector.Cell("Keyboard Type", keyboardType),
				UIInspector.Cell("Return Key", returnKeyType),
				UIInspector.Cell("Is Secure", isSecureTextEntry),
				UIInspector.Cell("Is Editing", isEditing),
				UIInspector.Cell("Clear Button", clearButtonMode),
			]),
		]
	}
}

extension UITextView: UIInspectorInfoConvertable {

	public var inspectorInfo: [UIInspector.Section] {
		defaultInspectorInfo + [
			UIInspector.Section(title: "Text View", cells: [
				UIInspector.Cell("Text", text ?? ""),
				UIInspector.Cell("Font", font),
				UIInspector.Cell("Text Color", textColor ),
				UIInspector.Cell("Text Alignment", textAlignment),
				UIInspector.Cell("Is Editable", isEditable),
				UIInspector.Cell("Is Selectable", isSelectable),
				UIInspector.Cell("Data Detector Types", dataDetectorTypes.rawValue),
				UIInspector.Cell("Is Scrollable", isScrollEnabled),
				UIInspector.Cell("Line Break Mode", textContainer.lineBreakMode),
			]),
		]
	}
}

extension UISwitch: UIInspectorInfoConvertable {

	public var inspectorInfo: [UIInspector.Section] {
		defaultInspectorInfo + [
			UIInspector.Section(title: "Switch", cells: [
				UIInspector.Cell("Is On", isOn),
				UIInspector.Cell("On Tint Color", onTintColor ),
				UIInspector.Cell("Thumb Tint Color", thumbTintColor ),
			]),
		]
	}
}

extension UISlider: UIInspectorInfoConvertable {

	public var inspectorInfo: [UIInspector.Section] {
		defaultInspectorInfo + [
			UIInspector.Section(title: "Slider", cells: [
				UIInspector.Cell("Value", value),
				UIInspector.Cell("Minimum", minimumValue),
				UIInspector.Cell("Maximum", maximumValue),
				UIInspector.Cell("Minimum Track Tint", minimumTrackTintColor ),
				UIInspector.Cell("Maximum Track Tint", maximumTrackTintColor ),
				UIInspector.Cell("Thumb Tint", thumbTintColor ),
				UIInspector.Cell("Is Continuous", isContinuous),
			]),
		]
	}
}

extension UIProgressView: UIInspectorInfoConvertable {

	public var inspectorInfo: [UIInspector.Section] {
		defaultInspectorInfo + [
			UIInspector.Section(title: "Progress View", cells: [
				UIInspector.Cell("Progress", progress),
				UIInspector.Cell("Progress Tint", progressTintColor ),
				UIInspector.Cell("Track Tint", trackTintColor ),
				UIInspector.Cell("Progress Style", progressViewStyle),
			]),
		]
	}
}

extension UISegmentedControl: UIInspectorInfoConvertable {

	public var inspectorInfo: [UIInspector.Section] {
		var segmentCells: [UIInspector.Cell] = []
		for i in 0 ..< numberOfSegments {
			if let title = titleForSegment(at: i) {
				segmentCells.append(UIInspector.Cell("Segment \(i) Title", title))
			} else if let image = imageForSegment(at: i) {
				segmentCells.append(UIInspector.Cell("Segment \(i) Image", "Set (\(image.size.width) × \(image.size.height))"))
			}
		}

		return defaultInspectorInfo + [
			UIInspector.Section(title: "Segmented Control", cells: [
				UIInspector.Cell("Selected Index", selectedSegmentIndex),
				UIInspector.Cell("Number of Segments", numberOfSegments),
				UIInspector.Cell("Is Momentary", isMomentary),
				UIInspector.Cell("Selected Tint", selectedSegmentTintColor ),
			]),
			UIInspector.Section(title: "Segments", cells: segmentCells),
		]
	}
}

extension UITableView: UIInspectorInfoConvertable {

	public var inspectorInfo: [UIInspector.Section] {
		defaultInspectorInfo + [
			UIInspector.Section(title: "Table View", cells: [
				UIInspector.Cell("Style", style),
				UIInspector.Cell("Number of Sections", numberOfSections),
				UIInspector.Cell("Total Rows", (0 ..< numberOfSections).reduce(0) { $0 + numberOfRows(inSection: $1) }),
				UIInspector.Cell("Separator Style", separatorStyle),
				UIInspector.Cell("Separator Color", separatorColor),
				UIInspector.Cell("Selection Style", allowsSelection ? (allowsMultipleSelection ? "Multiple" : "Single") : "None"),
				UIInspector.Cell("Row Height", rowHeight),
				UIInspector.Cell("Section Header Height", sectionHeaderHeight),
				UIInspector.Cell("Section Footer Height", sectionFooterHeight),
				UIInspector.Cell("Is Editing", isEditing),
			]),
		]
	}
}

extension UICollectionView: UIInspectorInfoConvertable {

	public var inspectorInfo: [UIInspector.Section] {
		defaultInspectorInfo + [
			UIInspector.Section(title: "Collection View", cells: [
				UIInspector.Cell("Number of Sections", numberOfSections),
				UIInspector.Cell("Total Items", (0 ..< numberOfSections).reduce(0) { $0 + numberOfItems(inSection: $1) }),
				UIInspector.Cell("Selection Style", allowsSelection ? (allowsMultipleSelection ? "Multiple" : "Single") : "None"),
				UIInspector.Cell("Is Prefetching", isPrefetchingEnabled),
				UIInspector.Cell("Is Dragging", isDragging),
				UIInspector.Cell("Is Decelerating", isDecelerating),
			]),
		]
	}
}

extension UIStackView: UIInspectorInfoConvertable {

	public var inspectorInfo: [UIInspector.Section] {
		defaultInspectorInfo + [
			UIInspector.Section(title: "Stack View", cells: [
				UIInspector.Cell("Axis", axis),
				UIInspector.Cell("Distribution", distribution),
				UIInspector.Cell("Alignment", alignment),
				UIInspector.Cell("Spacing", spacing),
				UIInspector.Cell("Is Baseline", isBaselineRelativeArrangement),
				UIInspector.Cell("Is Layout Margins Relative", isLayoutMarginsRelativeArrangement),
				UIInspector.Cell("Arranged Subviews", arrangedSubviews.count),
			]),
		]
	}
}

extension UIScrollView {

	public var defaultScrollInspectorInfo: [UIInspector.Section] {
		[
			UIInspector.Section(title: "Scroll View", cells: [
				UIInspector.Cell("Content Size", contentSize),
				UIInspector.Cell("Content Offset", contentOffset),
				UIInspector.Cell("Content Inset", contentInset),
				UIInspector.Cell("Zoom Scale", zoomScale),
				UIInspector.Cell("Min Zoom Scale", minimumZoomScale),
				UIInspector.Cell("Max Zoom Scale", maximumZoomScale),
				UIInspector.Cell("Is Scrolling", isScrollEnabled),
				UIInspector.Cell("Is Paging", isPagingEnabled),
				UIInspector.Cell("Is Bouncing", bounces),
				UIInspector.Cell("Shows Indicators", showsVerticalScrollIndicator || showsHorizontalScrollIndicator),
				UIInspector.Cell("Is Dragging", isDragging),
				UIInspector.Cell("Is Decelerating", isDecelerating),
			]),
		]
	}
}
