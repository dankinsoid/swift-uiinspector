import SwiftUI

extension UIInspector {

	struct Info: View {

		let view: any UIInspectorItem
		let underlying: [any UIInspectorItem]?
		let custom: (UIView) -> AnyView
		let onSelect: (any UIInspectorItem) -> Void
		@State private var selected: any UIInspectorItem
		private let padding: CGFloat = 14
		private let smallPadding: CGFloat = 8
	
		init(
			view: any UIInspectorItem,
			underlying: [any UIInspectorItem]?,
			custom: @escaping (UIView) -> AnyView,
			onSelect: @escaping (any UIInspectorItem) -> Void
		) {
			self.view = view
			self.underlying = underlying
			self.custom = custom
			self.onSelect = onSelect
			_selected = State(initialValue: view)
		}
	
		var selectedView: UIViewSnapshot {
			selected.snapshot
		}

		var info: [UIInspector.Section] {
			selectedView.info
		}

		var body: some View {
			NavigationView {
				VStack(spacing: 0) {
					List {
						if let underlying, !underlying.isEmpty {
							list("All views at this point", [view] + underlying)
						}
						if selected.parentItem != nil {
							list("Superviews", [selected] + selected.parents)
						}
						list("Subviews", selected.children)
						ForEach(Array(info.enumerated()), id: \.offset) { _, section in
							SwiftUI.Section {
								ForEach(Array(section.cells.enumerated()), id: \.offset) { _, cell in
									HStack(alignment: .firstTextBaseline, spacing: 4) {
										Text(cell.title)
											.lineLimit(1)
										Text(text(for: cell.value))
											.lineLimit(5)
											.multilineTextAlignment(.trailing)
											.selectableText()
											.frame(maxWidth: .infinity, alignment: .trailing)
											.opacity(0.5)
									}
									.padding(.vertical, 13)
									.listRowInsets(EdgeInsets(top: 0, leading: padding, bottom: 0, trailing: padding))
								}
							} header: {
								Text(section.title)
							}
						}
						custom(view.snapshot.source)
							.listRowInsets(EdgeInsets(top: 0, leading: padding, bottom: 0, trailing: padding))
					}
				}
				.navigationBarTitle("")
				.navigationBarHidden(true)
			}
			.animation(.easeInOut(duration: 0.15), value: selected.snapshot.id)
		}
		
		@ViewBuilder
		func title(for view: UIView) -> some View {
			Text(String(describing: type(of: view)))
				.truncationMode(.middle)
				.frame(maxWidth: 200)
		}
		
		@ViewBuilder
		func list(_ title: String, _ list: [any UIInspectorItem]) -> some View {
			if !list.isEmpty {
				SwiftUI.Section {
					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 0) {
							ForEach(list, id: \.snapshot.id) { view in
								Button {
									selected.unhighlight()
									selected = view
									selected.highlight()
									onSelect(view)
								} label: {
									self.title(for: view.snapshot.source)
								}
								.buttonStyle(ItemButton(isSelected: view.snapshot.id == selected.snapshot.id, padding: padding))
								if view.snapshot.id != list.last?.snapshot.id {
									Divider()
										.foregroundColor(.secondary)
										.padding(.vertical, smallPadding)
								}
							}
						}
					}
					.listRowInsets(EdgeInsets())
				} header: {
					Text(title)
				}
			}
		}

		struct ItemButton: ButtonStyle {
			
			let isSelected: Bool
			let padding: CGFloat
			
			func makeBody(configuration: Configuration) -> some View {
				configuration.label
					.font(.subheadline)
					.frame(maxHeight: .infinity)
					.padding(.horizontal, padding)
					.lineLimit(1)
					.foregroundColor(isSelected ? .primary : .secondary)
					.background(
						Group {
							if isSelected || configuration.isPressed {
								RoundedRectangle(cornerRadius: 8)
									.fill(Color.primary.opacity(0.2))
							}
						}
					)
			}
		}

		private func text(for value: Any?) -> String {
			(value as? UIInspectorStringConvertible)?.inspectorDescription ?? value.map { String(reflecting: $0) } ?? ""
		}
		
		enum UnderlyingType: String, CaseIterable {
			
			case hierarchy = "Hierarchy"
			case atThisLocation = "All views at this location"
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
