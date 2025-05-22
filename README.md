# SwiftUIInspector

SwiftUIInspector is a powerful debugging tool for iOS apps that allows you to inspect and analyze UI elements at runtime. It provides a visual inspector that can be overlaid on top of your app to examine view hierarchies, measure dimensions, and pick colors.

## Features

- 🔍 **View Hierarchy Inspection**: Visualize and navigate through your app's view hierarchy
- 📏 **Dimension Measurement**: Measure the size and position of UI elements
- 🎨 **Color Picker**: Extract colors from any pixel in your UI
- 📊 **Detailed Properties**: View detailed information about UI components
- 📱 **Live Updates**: See changes in real-time as you interact with your app
- 📐 **Grid Overlay**: Enable grid lines for precise alignment

## Requirements

- iOS 14.0+
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

## Inspector Controls

The inspector provides several controls:
- **Layers**: Toggle visibility of the view hierarchy layers
- **Tool**: Switch between color picker and dimension measurement tools
- **Grid**: Toggle grid overlay for alignment
- **Refresh**: Update the inspector view
- **Close**: Dismiss the inspector

## TODO

- **3D Rotation**: The 3D rotation feature is not implemented yet. This will be needed to properly visualize and interact with overlapping views in the hierarchy.

## License

This package is available under the MIT license.
