import SwiftUI
import SwiftUIInspector

struct ContentView: View {

    var body: some View {
		VStack(spacing: 14) {
			Image(systemName: "globe")
				.imageScale(.large)
				.foregroundColor(.blue)
			Text("Hello, world!")

			Button("Show Inspector") {
				UIInspectorController.present()
			}
		}
		.padding()
    }
}

#Preview {
    ContentView()
}
