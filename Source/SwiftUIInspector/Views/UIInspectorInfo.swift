import SwiftUI

extension UIInspector {

	struct Info: View {

		let view: UIView
		let custom: (UIView) -> AnyView

		var body: some View {
			let info = (view as? UIInspectorInfoConvertable)?.inspectorInfo ?? view.defaultInspectorInfo
			List {
				ForEach(Array(info.enumerated()), id: \.offset) { _, section in
					SwiftUI.Section {
						ForEach(Array(section.cells.enumerated()), id: \.offset) { _, cell in
							HStack(alignment: .firstTextBaseline, spacing: 4) {
								Text(cell.title)
									.lineLimit(1)
								Text(text(for: cell.value))
									.lineLimit(3)
									.multilineTextAlignment(.trailing)
									.selectableText()
									.frame(maxWidth: .infinity, alignment: .trailing)
									.opacity(0.5)
							}
						}
					} header: {
						Text(section.title)
					}
				}
				custom(view)
			}
		}

		private func text(for value: Any?) -> String {
			(value as? UIInspectorStringConvertible)?.inspectorDescription ?? "\(value ?? "nil")"
		}
	}
}

public extension UIInspector {

	/// A section of related information in the inspector detail view.
	///
	/// Sections are used to group related properties or information about a view.
	struct Section {

		/// The title of the section.
		public var title: String

		/// The cells (rows) of information in this section.
		public var cells: [Cell]

		/// Creates a new section with the specified title and cells.
		///
		/// - Parameters:
		///   - title: The title of the section
		///   - cells: An array of cells to display in this section
		public init(title: String, cells: [Cell]) {
			self.title = title
			self.cells = cells
		}
	}

	/// A single cell (row) of information in an inspector section.
	///
	/// Each cell represents a property or piece of information about a view.
	struct Cell {

		/// The title or label for this cell.
		public var title: String

		/// The value to display for this cell.
		///
		/// If the value conforms to `UIInspectorStringConvertible`, its
		/// `inspectorDescription` will be used for display.
		public var value: Any?

		/// Creates a new cell with the specified title and value.
		///
		/// - Parameters:
		///   - title: The title or label for this cell
		///   - value: The value to display
		public init(_ title: String, _ value: Any?) {
			self.title = title
			self.value = value
		}
	}
}
