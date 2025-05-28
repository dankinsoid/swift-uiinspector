import UIKit

final class JustTapGesture: UIGestureRecognizer, UIGestureRecognizerDelegate {

	private(set) var translation: CGPoint = .zero
	private var lastLocation: CGPoint = .zero
	private var startDate = Date()
	
	override init(target: Any?, action: Selector?) {
		super.init(target: target, action: action)
		delegate = self
	}

	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
		if event.touches(for: self)?.count == 1 {
			state = .began
			startDate = Date()
			lastLocation = event.touches(for: self)?.first?.location(in: view) ?? .zero
		} else {
			state = .failed
		}
	}

	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
		guard let touches = event.touches(for: self), touches.count == 1 else {
			state = .failed
			return
		}

		let point = touches[touches.startIndex].location(in: view)
		translation = CGPoint(x: point.x - lastLocation.x, y: point.y - lastLocation.y)
		state = .changed
	}

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
		if Date().timeIntervalSince(startDate) < 0.15, max(abs(translation.x), abs(translation.y)) < 5 {
			state = .ended
		} else {
			state = .failed
		}
		reset()
	}

	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
		state = .cancelled
		reset()
	}

	override func reset() {
		translation = .zero
	}
	
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		true
	}
}
