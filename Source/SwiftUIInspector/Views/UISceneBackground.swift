import UIKit

final class UISceneBackground: UIView {
	
	override class var layerClass: AnyClass {
		return CAGradientLayer.self
	}
	
	override var tintColor: UIColor! {
		didSet {
			updateColors()
		}
	}
	
	init() {
		super.init(frame: .zero)
		updateColors()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)
		updateColors()
	}
	
	func updateColors() {
		guard let gradientLayer = self.layer as? CAGradientLayer else { return }
		
		let baseColor = tintColor ?? UIInspector.tintColor
		var hue: CGFloat = 0
		var saturation: CGFloat = 0
		var brightness: CGFloat = 0
		var alpha: CGFloat = 0
		
		baseColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
		
		let dark: CGColor
		let light: CGColor
		if traitCollection.userInterfaceStyle == .dark {
			dark = UIColor(hue: hue, saturation: 0.25, brightness: 0.35, alpha: 1).cgColor
			light = UIColor(hue: hue, saturation: 0.22, brightness: 0.37, alpha: 1).cgColor
		} else {
			dark = UIColor(hue: hue, saturation: 0.25, brightness: 0.65, alpha: 1).cgColor
			light = UIColor(hue: hue, saturation: 0.22, brightness: 0.69, alpha: 1).cgColor
		}
		let count = 5
		gradientLayer.colors = (0..<count).flatMap { $0 % 2 == 0 ? [dark, dark] : [light, light] }
		let step = 1 / Double(count)
		gradientLayer.locations = (0..<count).flatMap { [Double($0) * step, Double($0 + 1) * step] }.map { $0 as NSNumber }
		
		gradientLayer.startPoint = CGPoint(x: 0, y: 1)
		gradientLayer.endPoint = CGPoint(x: 1, y: 0)
	}
}
