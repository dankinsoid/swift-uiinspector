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
									.textSelection(.enabled)
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

		private func text(for value: Any) -> String {
			(value as? UIInspectorStringConvertible)?.inspectorDescription ?? "\(value)"
		}
	}
}

extension UIInspector {

	public struct Section {
		
		public var title: String
		public var cells: [Cell]
		
		public init(title: String, cells: [Cell]) {
			self.title = title
			self.cells = cells
		}
	}
	
	public struct Cell {

		public var title: String
		public var value: Any

		public init(_ title: String, _ value: Any) {
			self.title = title
			self.value = value
		}
	}
}
