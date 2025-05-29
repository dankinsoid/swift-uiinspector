import SwiftUI

extension UIInspector {

	struct Info: View {

		let view: any UIInspectorItem
		let underlying: [any UIInspectorItem]
		let custom: (UIView) -> AnyView
		let onSelect: (any UIInspectorItem) -> Void
		@State private var selected: any UIInspectorItem
	
		init(view: any UIInspectorItem, underlying: [any UIInspectorItem], custom: @escaping (UIView) -> AnyView, onSelect: @escaping (any UIInspectorItem) -> Void) {
			self.view = view
			self.underlying = underlying
			self.custom = custom
			self.onSelect = onSelect
			_selected = State(initialValue: view)
		}
	
		var selectedView: UIView {
			([view] + underlying).first(where: { $0.source === selected.source })?.source ?? view.source
		}
		
		var info: [UIInspector.Section] {
			(selectedView as? UIInspectorInfoConvertable)?.inspectorInfo ?? selectedView.defaultInspectorInfo
		}

		var body: some View {
			let info = info
			NavigationView {
				VStack(spacing: 0) {
					if !underlying.isEmpty {
						ScrollView(.horizontal, showsIndicators: false) {
							HStack(spacing: 0) {
								ForEach([view] + underlying, id: \.source.objectID) { view in
									Button {
										selected.unhighlight()
										selected = view
										selected.highlight()
										onSelect(view)
									} label: {
										title(for: view.source)
											.foregroundColor(view.source === selected.source ? .accentColor : .secondary)
											.padding(4)
											.frame(maxHeight: .infinity)
											.contentShape(.rect)
									}
									if view.source !== underlying.last?.source {
										Text("❯")
											.foregroundColor(.secondary)
									}
								}
							}
							.frame(height: 40)
							.font(.subheadline)
							.padding(.vertical, 4)
							.padding(.horizontal, 16)
						}
					}
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
						custom(view.source)
					}
				}
				.navigationBarTitle("")
				.navigationBarHidden(true)
			}
		}
		
		@ViewBuilder
		func title(for view: UIView) -> some View {
			Text(String(describing: type(of: view)))
				.truncationMode(.middle)
				.frame(maxWidth: 200)
		}

		private func text(for value: Any?) -> String {
			(value as? UIInspectorStringConvertible)?.inspectorDescription ?? value.map { String(reflecting: $0) } ?? ""
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
