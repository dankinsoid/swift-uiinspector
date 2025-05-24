import UIKit

final class UISceneBackground: UIView {
	
	private let tintIntensity: CGFloat = 0.15
	
	// MARK: - Initialization
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setupBackground()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setupBackground()
	}
	
	// MARK: - Setup
	
	private func setupBackground() {
		updateGradient()
	}

	// MARK: - Gradient Update
	
	private func updateGradient() {
		let isDarkMode: Bool
		
		if #available(iOS 13.0, *) {
			isDarkMode = traitCollection.userInterfaceStyle == .dark
		} else {
			isDarkMode = false
		}
		
		let baseColor = getBaseColors(for: isDarkMode)
		backgroundColor = applyTint(to: baseColor)
	}
	
	private func getBaseColors(for isDarkMode: Bool) -> UIColor {
		if isDarkMode {
			return UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
		} else {
			return UIColor(red: 0.92, green: 0.92, blue: 0.94, alpha: 1.0)
		}
	}
	
	private func applyTint(to color: UIColor) -> UIColor {
		guard let tintColor else { return color }
		return blendColors(base: color, tint: tintColor, intensity: tintIntensity)
	}

	private func blendColors(base: UIColor, tint: UIColor, intensity: CGFloat) -> UIColor {
		var baseR: CGFloat = 0, baseG: CGFloat = 0, baseB: CGFloat = 0, baseA: CGFloat = 0
		var tintR: CGFloat = 0, tintG: CGFloat = 0, tintB: CGFloat = 0, tintA: CGFloat = 0
		
		base.getRed(&baseR, green: &baseG, blue: &baseB, alpha: &baseA)
		tint.getRed(&tintR, green: &tintG, blue: &tintB, alpha: &tintA)
		
		let blendedR = baseR + (tintR - baseR) * intensity
		let blendedG = baseG + (tintG - baseG) * intensity
		let blendedB = baseB + (tintB - baseB) * intensity
		
		return UIColor(red: blendedR, green: blendedG, blue: blendedB, alpha: baseA)
	}
	
	
	override func tintColorDidChange() {
		super.tintColorDidChange()
		updateGradient()
	}
	
	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)
		updateGradient()
	}
}
