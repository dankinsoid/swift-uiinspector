import SwiftUI

extension UIWindow {

	static var key: UIWindow? {
		UIApplication.shared.connectedScenes
			.compactMap { $0 as? UIWindowScene }
			.flatMap(\.windows)
			.first(where: \.isKeyWindow)
	}
}

extension UIViewController {

	var topPresented: UIViewController {
		let controller = presentedViewController?.topPresented ?? self
		if let nav = controller as? ControllerWithTopChild {
			return nav.topVisibleChildController ?? controller
		}
		return controller
	}

	var allPresented: [UIViewController] {
		[self] + (presentedViewController?.allPresented ?? [])
	}
}

public protocol ControllerWithTopChild {
	var topVisibleChildController: UIViewController? { get }
}

extension UINavigationController: ControllerWithTopChild {
	public var topVisibleChildController: UIViewController? { topViewController }
}

extension UITabBarController: ControllerWithTopChild {
	public var topVisibleChildController: UIViewController? { selectedViewController }
}

extension Collection {

	subscript(safe index: Index) -> Element? {
		guard indices.contains(index) else { return nil }
		return self[index]
	}
}

extension CGRect {

	func inside(_ rect: CGRect) -> CGRect {
		let x = min(max(minX, rect.minX), rect.maxX - width)
		let y = min(max(minY, rect.minY), rect.maxY - height)
		return CGRect(x: x, y: y, width: width, height: height)
	}
}

extension UIView {

	var allSubviews: [UIView] {
		subviews + subviews.flatMap(\.allSubviews)
	}

	var allVisibleSubviewsLayers: [[UIView]] {
		let visible = subviews.filter { !$0.isHidden }
		return ([visible] + visible.flatMap(\.allVisibleSubviewsLayers)).filter { !$0.isEmpty }
	}

	func snapshotImage() -> UIImage {
		let format = UIGraphicsImageRendererFormat()
		format.scale = window?.screen.scale ?? UIScreen.main.scale
		format.opaque = isOpaque
		format.preferredRange = .standard

		let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)
		let result = renderer.image { ctx in
			drawHierarchy(in: bounds, afterScreenUpdates: true)
		}
		return result
	}

	func snapshotImageWithoutSubviews() -> UIImage {
		let format = UIGraphicsImageRendererFormat()
		format.scale = window?.screen.scale ?? UIScreen.main.scale
		format.opaque = false
		format.preferredRange = .standard
		
		let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)
		let result = renderer.image { ctx in
			// Clear to transparent
			ctx.cgContext.clear(CGRect(origin: .zero, size: bounds.size))
			
			// Save current state
			let originalSublayers = layer.sublayers
			let originalBackgroundColor = layer.backgroundColor
			
			// Remove sublayers
			layer.sublayers = nil
			
			// Render just this layer's content
			layer.render(in: ctx.cgContext)
			
			// Restore
			layer.sublayers = originalSublayers
		}
		return result
	}
	
}

extension UIImageView {

	func imagePixelPoint(from viewPoint: CGPoint) -> CGPoint {
		guard let image, let cgImage = image.cgImage else { return viewPoint }

		let viewSize = bounds.size
		let imageSize = CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))

		let imageAspect = image.size.width / image.size.height
		let viewAspect = viewSize.width / viewSize.height

		var drawSize = CGSize.zero
		var origin = CGPoint.zero

		switch contentMode {
		case .scaleAspectFit:
			if imageAspect > viewAspect {
				// image fills width
				drawSize.width = viewSize.width
				drawSize.height = viewSize.width / imageAspect
				origin.y = (viewSize.height - drawSize.height) / 2
			} else {
				// image fills height
				drawSize.height = viewSize.height
				drawSize.width = viewSize.height * imageAspect
				origin.x = (viewSize.width - drawSize.width) / 2
			}

		case .scaleAspectFill:
			if imageAspect > viewAspect {
				// image fills height
				drawSize.height = viewSize.height
				drawSize.width = viewSize.height * imageAspect
				origin.x = (viewSize.width - drawSize.width) / 2
			} else {
				// image fills width
				drawSize.width = viewSize.width
				drawSize.height = viewSize.width / imageAspect
				origin.y = (viewSize.height - drawSize.height) / 2
			}

		case .scaleToFill, .redraw:
			drawSize = viewSize

		default:
			drawSize = image.size
		}

		// Учитываем сдвиг и масштаб
		let normalized = CGPoint(
			x: (viewPoint.x - origin.x) / drawSize.width,
			y: (viewPoint.y - origin.y) / drawSize.height
		)

		guard (0 ... 1).contains(normalized.x), (0 ... 1).contains(normalized.y) else { return viewPoint }

		return CGPoint(
			x: normalized.x * imageSize.width,
			y: normalized.y * imageSize.height
		)
	}
}

extension UIImage {

	var pixelWidth: Int {
		cgImage?.width ?? 0
	}

	var pixelHeight: Int {
		cgImage?.height ?? 0
	}

	func pixelColor(at point: CGPoint) -> UIColor {
		let x = Int(point.x)
		let y = Int(point.y)

		guard 0 ..< pixelWidth ~= x, 0 ..< pixelHeight ~= y else {
			return .clear
		}

		guard
			let cgImage,
			let data = cgImage.dataProvider?.data,
			let dataPtr = CFDataGetBytePtr(data),
			let colorSpaceModel = cgImage.colorSpace?.model,
			let componentLayout = cgImage.bitmapInfo.componentLayout
		else {
			return .clear
		}

		guard colorSpaceModel == .rgb, [32, 64, 24].contains(cgImage.bitsPerPixel) else {
			return .clear
		}
		let bytesPerRow = cgImage.bytesPerRow
		let bytesPerPixel = cgImage.bitsPerPixel / 8
		let pixelOffset = y * bytesPerRow + x * bytesPerPixel

		var alpha: UInt8 = 255
		var red: UInt8 = 0
		var green: UInt8 = 0
		var blue: UInt8 = 0

		let components: [UInt8]
		if cgImage.bitsPerPixel == 64 {
			components = (0 ..< componentLayout.count).map {
				let byte1 = dataPtr[pixelOffset + $0 * 2]
				let byte2 = dataPtr[pixelOffset + $0 * 2 + 1]
				let rawValue = UInt16(byte1) | (UInt16(byte2) << 8)

				// Manual half-float conversion (simplified)
				let sign = (rawValue & 0x8000) != 0
				let exponent = Int((rawValue & 0x7C00) >> 10)
				let mantissa = rawValue & 0x03FF

				var floatValue: Float
				if exponent == 0 {
					floatValue = Float(mantissa) / 1024.0 / 1024.0
				} else {
					floatValue = Float(1024 + mantissa) / 1024.0 * pow(2.0, Float(exponent - 15))
				}

				if sign { floatValue = -floatValue }

				let clampedValue = max(0.0, min(1.0, floatValue))
				return UInt8(clampedValue * 255.0)
			}
		} else {
			components = (0 ..< componentLayout.count).map {
				dataPtr[pixelOffset + $0]
			}
		}

		switch componentLayout {
		case .bgra:
			alpha = components[3]
			red = components[2]
			green = components[1]
			blue = components[0]
		case .abgr:
			alpha = components[0]
			red = components[3]
			green = components[2]
			blue = components[1]
		case .argb:
			alpha = components[0]
			red = components[1]
			green = components[2]
			blue = components[3]
		case .rgba:
			alpha = components[3]
			red = components[0]
			green = components[1]
			blue = components[2]
		case .bgr:
			red = components[2]
			green = components[1]
			blue = components[0]
		case .rgb:
			red = components[0]
			green = components[1]
			blue = components[2]
		default:
			return .clear
		}

		// If chroma components are premultiplied by alpha and the alpha is `0`,
		// keep the chroma components to their current values.
		if cgImage.bitmapInfo.chromaIsPremultipliedByAlpha, alpha != 0 {
			let invisibleUnitAlpha = 255 / CGFloat(alpha)
			red = UInt8((CGFloat(red) * invisibleUnitAlpha).rounded())
			green = UInt8((CGFloat(green) * invisibleUnitAlpha).rounded())
			blue = UInt8((CGFloat(blue) * invisibleUnitAlpha).rounded())
		}

		return UIColor(red: red, green: green, blue: blue, alpha: alpha)
	}
}

extension CGColor {

	var hexString: String {
		guard let cgColor = converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
			  let components = cgColor.components else { return "Unknown" }
		let red = Int(components[0] * 255)
		let green = Int(components[1] * 255)
		let blue = Int(components[2] * 255)
		let alpha = Int(components.count > 3 ? components[3] * 255 : 255)
		if alpha == 255 {
			return String(format: "#%02X%02X%02X", red, green, blue)
		} else {
			return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
		}
	}
}

extension UIColor {

	var hexString: String {
		cgColor.hexString
	}

	convenience init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
		self.init(
			red: CGFloat(red) / 255,
			green: CGFloat(green) / 255,
			blue: CGFloat(blue) / 255,
			alpha: CGFloat(alpha) / 255
		)
	}

	convenience init(dark: UIColor, light: UIColor) {
		self.init { trait in
			if trait.userInterfaceStyle == .light {
				light
			} else {
				dark
			}
		}
	}
}

extension CGBitmapInfo {

	enum ComponentLayout {

		case bgra
		case abgr
		case argb
		case rgba
		case bgr
		case rgb

		var count: Int {
			switch self {
			case .bgr, .rgb: return 3
			default: return 4
			}
		}
	}

	var componentLayout: ComponentLayout? {
		guard let alphaInfo = CGImageAlphaInfo(rawValue: rawValue & Self.alphaInfoMask.rawValue) else { return nil }
		let isLittleEndian = contains(.byteOrder32Little)

		if alphaInfo == .none {
			return isLittleEndian ? .bgr : .rgb
		}
		let alphaIsFirst = alphaInfo == .premultipliedFirst || alphaInfo == .first || alphaInfo == .noneSkipFirst

		if isLittleEndian {
			return alphaIsFirst ? .bgra : .abgr
		} else {
			return alphaIsFirst ? .argb : .rgba
		}
	}

	var chromaIsPremultipliedByAlpha: Bool {
		let alphaInfo = CGImageAlphaInfo(rawValue: rawValue & Self.alphaInfoMask.rawValue)
		return alphaInfo == .premultipliedFirst || alphaInfo == .premultipliedLast
	}
}

extension View {

	@ViewBuilder
	func selectableText() -> some View {
		if #available(iOS 15.0, *) {
			textSelection(.enabled)
		} else {
			self
		}
	}
}

extension CGSize {

	func less(than size: CGSize) -> Bool {
		width < size.width || height < size.height
	}
}

extension UIGestureRecognizer.State {

	var isFinal: Bool {
		self == .ended || self == .failed || self == .cancelled
	}
}

extension CGFloat {

	var roundedToScale: CGFloat {
		let scale = UIScreen.main.scale
		return (self * scale).rounded() / scale
	}
}

extension CGPoint {

	var roundedToScale: CGPoint {
		CGPoint(
			x: x.roundedToScale,
			y: y.roundedToScale
		)
	}
}

extension UIView {

	var controller: UIViewController? {
		var responder: UIResponder? = self
		while responder != nil {
			if let controller = responder as? UIViewController {
				return controller
			}
			responder = responder?.next
		}
		return nil
	}
}

extension Float {

	var degreesToRadians: Float { self * .pi / 180 }
}
