import SwiftUI
import SwiftUIInspector

struct ContentView: View {
    @State private var sliderValue: Double = 0.5
    @State private var toggleValue: Bool = false
    @State private var selectedTab: Int = 0
    @State private var textInput: String = ""
    @State private var selectedDate = Date()
    @State private var showSheet = false
    @State private var selectedColor: Color = .blue
    
    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // First Tab - Controls
                ScrollView {
                    VStack(spacing: 20) {
                        headerView
                        
                        controlsSection
                        
                        colorsSection
                        
                        imagesSection
                        
                        inspectorButton
                    }
                    .padding()
                }
                .tabItem {
                    Label("Controls", systemImage: "slider.horizontal.3")
                }
                .tag(0)
                
                // Second Tab - List
                listTab
                    .tabItem {
                        Label("List", systemImage: "list.bullet")
                    }
                    .tag(1)
                
                // Third Tab - Grid
                gridTab
                    .tabItem {
                        Label("Grid", systemImage: "square.grid.2x2")
                    }
                    .tag(2)
            }
            .navigationTitle("SwiftUI Inspector Demo")
            .navigationBarItems(trailing: Button(action: {
                showSheet = true
            }) {
                Image(systemName: "info.circle")
            })
            .sheet(isPresented: $showSheet) {
                VStack(spacing: 20) {
                    Text("About SwiftUI Inspector")
                        .font(.title)
                        .bold()
                    
                    Text("This demo app showcases various SwiftUI components that can be inspected using the SwiftUI Inspector tool.")
                        .multilineTextAlignment(.center)
                    
                    Image(systemName: "viewfinder")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .foregroundColor(.blue)
                    
                    Button("Dismiss") {
                        showSheet = false
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
            }
        }
    }
    
    // MARK: - Component Views
    
    private var headerView: some View {
        VStack(spacing: 10) {
            Image(systemName: "viewfinder.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(selectedColor)
                .shadow(radius: 5)
            
            Text("SwiftUI Inspector")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Explore the UI hierarchy")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    private var controlsSection: some View {
        GroupBox(label: Text("Interactive Controls").bold()) {
            VStack(alignment: .leading, spacing: 15) {
                Toggle("Enable Feature", isOn: $toggleValue)
                
                Slider(value: $sliderValue, in: 0...1) {
                    Text("Slider")
                } minimumValueLabel: {
                    Text("0")
                } maximumValueLabel: {
                    Text("1")
                }
                
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                
                TextField("Enter text", text: $textInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Stepper("Adjust Value: \(Int(sliderValue * 100))", value: .init(
                    get: { Int(sliderValue * 100) },
                    set: { sliderValue = Double($0) / 100 }
                ), in: 0...100)
            }
            .padding()
        }
    }
    
    private var colorsSection: some View {
        GroupBox(label: Text("Color Palette").bold()) {
            VStack(spacing: 15) {
                Text("Selected Color: \(colorName(selectedColor))")
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                )
                                .shadow(radius: 2)
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    .padding(.horizontal, 5)
                }
            }
            .padding()
        }
    }
    
    private var imagesSection: some View {
        GroupBox(label: Text("System Images").bold()) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 15) {
                ForEach(["heart.fill", "star.fill", "bell.fill", "person.fill", "gear", "globe"], id: \.self) { imageName in
                    VStack {
                        Image(systemName: imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                            .foregroundColor(selectedColor)
                        
                        Text(imageName.replacingOccurrences(of: ".fill", with: ""))
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
    }
    
    private var inspectorButton: some View {
        Button(action: {
            UIInspectorController.present()
        }) {
            HStack {
                Image(systemName: "magnifyingglass")
                Text("Show UI Inspector")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(selectedColor)
            .foregroundColor(.white)
            .cornerRadius(10)
            .shadow(radius: 3)
        }
    }
    
    private var listTab: some View {
        List {
            Section(header: Text("Basic Items")) {
                ForEach(1...5, id: \.self) { item in
                    HStack {
                        Image(systemName: "number.\(item).circle.fill")
                            .foregroundColor(selectedColor)
                        Text("List Item \(item)")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Section(header: Text("Expandable Content")) {
                DisclosureGroup("Tap to expand") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Hidden content revealed!")
                        
                        HStack {
                            ForEach(0..<3) { i in
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(colors[i])
                                    .frame(height: 40)
                            }
                        }
                        
                        Button("Nested Inspector") {
                            UIInspectorController.present()
                        }
                        .padding(8)
                        .background(selectedColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Section(header: Text("Custom Elements")) {
                HStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    VStack(alignment: .leading) {
                        Text("Gradient Circle")
                            .font(.headline)
                        Text("With nested elements")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.yellow)
                            .frame(width: 50, height: 50)
                        
                        Text("ZS")
                            .bold()
                            .foregroundColor(.black)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("ZStack Example")
                            .font(.headline)
                        Text("Text over shape")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private var gridTab: some View {
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
    
    // Helper function to get color name
    private func colorName(_ color: Color) -> String {
        if color == .red { return "Red" }
        if color == .orange { return "Orange" }
        if color == .yellow { return "Yellow" }
        if color == .green { return "Green" }
        if color == .blue { return "Blue" }
        if color == .purple { return "Purple" }
        if color == .pink { return "Pink" }
        return "Unknown"
    }
}

#Preview {
    ContentView()
}
