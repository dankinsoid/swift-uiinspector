import SwiftUI
import SwiftUIInspector

struct ContentView: View {

    @State private var selectedColor: Color = .blue
	@State private var isInspectorPresented = false
    
    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
    
	var body: some View {
		ScrollView {
			VStack(spacing: 20) {
				Text("Grid Layout Examples")
					.font(.title2)
					.bold()
					.padding(.top)
				
				// Basic grid
				LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 15) {
					ForEach(0..<8) { index in
						RoundedRectangle(cornerRadius: 10)
							.fill(colors[index % colors.count])
							.frame(height: 100)
							.overlay(
								Text("\(index + 1)")
									.font(.title)
									.bold()
									.foregroundColor(.white)
							)
					}
				}
				.padding(.horizontal)
				
				Divider()
					.padding(.vertical)
				
				// Complex nested layout
				VStack(spacing: 15) {
					Text("Nested Layout")
						.font(.headline)
					
					HStack(spacing: 15) {
						// Left column
						VStack(spacing: 15) {
							RoundedRectangle(cornerRadius: 10)
								.fill(colors[0])
								.frame(height: 100)
							
							HStack(spacing: 15) {
								RoundedRectangle(cornerRadius: 10)
									.fill(colors[1])
									.frame(height: 100)
								
								RoundedRectangle(cornerRadius: 10)
									.fill(colors[2])
									.frame(height: 100)
							}
						}
						
						// Right column
						VStack(spacing: 15) {
							HStack(spacing: 15) {
								RoundedRectangle(cornerRadius: 10)
									.fill(colors[3])
									.frame(height: 100)
								
								RoundedRectangle(cornerRadius: 10)
									.fill(colors[4])
									.frame(height: 100)
							}
							
							RoundedRectangle(cornerRadius: 10)
								.fill(colors[5])
								.frame(height: 100)
						}
					}
				}
				.padding(.horizontal)
				
				Button("Inspect Grid") {
					UIInspectorController.present()
				}
				.padding()
				.background(selectedColor)
				.foregroundColor(.white)
				.cornerRadius(10)
				.padding(.vertical)
			}
		}
	}
}

#Preview {
    ContentView()
		.previewInspector()
}
