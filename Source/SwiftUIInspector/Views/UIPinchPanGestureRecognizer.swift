import UIKit

final class UIPinchPanGestureRecognizer: UIGestureRecognizer {

	private(set) var scale: CGFloat = 1.0
	private(set) var translation: CGPoint = .zero

	private var lastDistance: CGFloat?
	private var lastMidPoint: CGPoint?

	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
		print(touches.count)
		if event.touches(for: self)?.count == 2 {
			state = .began
			updateMetrics(with: event)
		} else {
			state = .possible
		}
	}

	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
		guard let touches = event.touches(for: self), touches.count == 2 else {
			state = .failed
			return
		}

		guard let prevDistance = lastDistance,
			  let prevMid = lastMidPoint
		else {
			updateMetrics(with: event)
			return
		}

		let points = touches.map { $0.location(in: view) }
		let currDistance = distance(points[0], points[1])
		let currMid = midpoint(points[0], points[1])

		scale = currDistance / max(prevDistance, 0.01)
		translation = CGPoint(x: currMid.x - prevMid.x, y: currMid.y - prevMid.y)

		lastDistance = currDistance
		lastMidPoint = currMid

		state = .changed
	}

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
		state = .ended
		reset()
	}

	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
		state = .cancelled
		reset()
	}

	override func reset() {
		lastDistance = nil
		lastMidPoint = nil
		scale = 1.0
		translation = .zero
	}

	private func updateMetrics(with event: UIEvent) {
		guard var touches = event.touches(for: self), touches.count == 2 else { return }

		let point1 = touches.removeFirst()
		let point2 = touches[touches.startIndex]

		lastDistance = distance(point1.location(in: view), point2.location(in: view))
		lastMidPoint = midpoint(point1.location(in: view), point2.location(in: view))
	}
}

private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
	hypot(b.x - a.x, b.y - a.y)
}

private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
	CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
}
