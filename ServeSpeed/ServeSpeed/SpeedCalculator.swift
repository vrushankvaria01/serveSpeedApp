import Foundation
import CoreGraphics

enum SpeedCalculator {
    static func process(videoURL: URL, calibration: Homography) async -> ServeResult? {
        let analyzer = TrajectoryAnalyzer()
        guard let (trajectories, fps) = try? await analyzer.analyze(videoURL: videoURL),
              !trajectories.isEmpty else {
            return nil
        }

        let trajectory = trajectories.max(by: { $0.points.count < $1.points.count })
        guard let points = trajectory?.points, points.count >= 2 else { return nil }

        let worldPoints: [CGPoint] = points.map { p in
            let flipped = CGPoint(x: p.x, y: 1 - p.y)
            return calibration.project(flipped)
        }

        let dt = 1.0 / fps
        var peakMPS = 0.0
        for i in 1..<worldPoints.count {
            let dx = Double(worldPoints[i].x - worldPoints[i-1].x)
            let dy = Double(worldPoints[i].y - worldPoints[i-1].y)
            let segment = (dx*dx + dy*dy).squareRoot()
            let speed = segment / dt
            if speed.isFinite { peakMPS = max(peakMPS, speed) }
        }

        guard peakMPS > 1, peakMPS < 200 else { return nil }

        return ServeResult(mph: peakMPS * 2.23694, kmh: peakMPS * 3.6)
    }
}
