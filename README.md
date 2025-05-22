# SwiftUIInspector

SwiftUIInspector is a powerful debugging tool for iOS apps that allows you to inspect and analyze UI elements at runtime. It provides a visual inspector that can be overlaid on top of your app to examine view hierarchies, measure dimensions, and pick colors.

## Features

- 🔍 **View Hierarchy Inspection**: Visualize your app's view hierarchy
- 📏 **Dimension Measurement**: Measure the size and position of UI elements
- 🎨 **Color Picker**: Extract colors from any pixel in your UI
- 📊 **Detailed Properties**: View detailed information about UI components
- 📐 **Grid Overlay**: Enable grid lines for precise alignment

## Requirements

- iOS 13.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftUIInspector.git", from: "1.0.0")
]
```

Or add it directly in Xcode using File > Add Packages...

## Usage

```swift
import SwiftUIInspector

// Present the inspector over your current view
Button("Show Inspector") {
    UIInspectorController.present()
}

// Or present it for a specific view
Button("Inspect This View") {
    UIInspectorController.present(for: myView)
}

// Customize the inspector
Button("Custom Inspector") {
    UIInspectorController.present { inspector in
        inspector.tintColor = .systemBlue
        inspector.customInfoView = { view in
            AnyView(
                Text("Custom info for \(type(of: view))")
            )
        }
    }
}
```

## Screenshots

Here are some screenshots showing the main features of SwiftUIInspector:

### View Hierarchy Layers
<img src="https://github.com/dankinsoid/Resources/raw/main/SwiftUIInspector/layers.PNG" width="300">

### Grid Overlay with Layers
<img src="https://github.com/dankinsoid/Resources/raw/main/SwiftUIInspector/layers.grid.PNG" width="300">

### Color Picker Tool
<img src="https://github.com/dankinsoid/Resources/raw/main/SwiftUIInspector/pipette.PNG" width="300">

### Measurement Tool with Grid
<img src="https://github.com/dankinsoid/Resources/raw/main/SwiftUIInspector/selection.grid.PNG" width="300">

## Inspector Controls

The inspector provides several controls:
- **Layers**: Toggle visibility of the view hierarchy layers
- **Tool**: Switch between color picker and dimension measurement tools
- **Grid**: Toggle grid overlay for alignment
- **Refresh**: Update the inspector view
- **Close**: Dismiss the inspector

## TODO

- **3D Rotation**: The 3D rotation feature is not implemented yet. This will be needed to properly visualize and interact with overlapping views in the hierarchy.
- **Better SwiftUI Integration**: While the current implementation works for SwiftUI views (for now), there are still some limitations.
- **macOS Support**: Currently, the inspector is designed for iOS. Future versions may include support for macOS.

## License

This package is available under the MIT license.
