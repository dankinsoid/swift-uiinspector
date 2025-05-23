# UIInspector

UIInspector is a powerful debugging tool for iOS apps that allows you to inspect and analyze UI elements at runtime. It provides a visual inspector that can be overlaid on top of your app to examine view hierarchies, measure dimensions, and pick colors.

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
    .package(url: "https://github.com/dankinsoid/swift-uiinspector.git", from: "1.1.0")
]
```

Or add it directly in Xcode using File > Add Packages...

## Screenshots

Here are some screenshots showing the main features of SwiftUIInspector:

### Measurement Tool with Grid
<img src="https://github.com/dankinsoid/Resources/raw/main/SwiftUIInspector/selection.grid.PNG" width="300">

### View Hierarchy Layers
<img src="https://github.com/dankinsoid/Resources/raw/main/SwiftUIInspector/inspector3d.PNG" width="300">

### Color Picker Tool
<img src="https://github.com/dankinsoid/Resources/raw/main/SwiftUIInspector/pipette.PNG" width="300">

### View Info
<img src="https://github.com/dankinsoid/Resources/raw/main/SwiftUIInspector/info3d.PNG" width="300">

## Usage

```swift
import SwiftUIInspector

// Present the inspector over your current view
UIInspectorController.present()

// Or present it for a specific view
UIInspectorController.present(for: myView)

// Customize the inspector
UIInspectorController.present { inspector in
    inspector.tintColor = .systemBlue
    inspector.customInfoView = { view in
        AnyView(
            Text("Custom info for \(type(of: view))")
        )
    }
}
```

You can use the following gestures:
- **Long Press**: Start measuring dimensions or color picking. Also can be used to move the controls.
- **Pinch**: Zoom in/out to adjust the inspector view.
- **Tap**: Show a detailed info of the view, enabled when layers are visible.

## Inspector Controls

The inspector provides several controls:
- **Layers**: Toggle visibility of the view hierarchy layers
- **Tool**: Switch between color picker and dimension measurement tools
- **Grid**: Toggle grid overlay for alignment
- **Refresh**: Update the inspector view
- **Close**: Dismiss the inspector

## TODO

- **macOS Support**: Currently, the inspector is designed for iOS. Future versions may include support for macOS.
- **CATransform3D Support**: Enhancements to support 3D Z-axis transformations in the inspector.

## License

This package is available under the MIT license.
