import Vision
import AVFoundation
import CoreMedia

struct DetectedTrajectory {
    let points: [CGPoint]
    let firstFrameIndex: Int
}

actor TrajectoryAnalyzer {
    func analyze(videoURL: URL) async throws -> (trajectories: [DetectedTrajectory], fps: Double) {
        let asset = AVURLAsset(url: videoURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else { return ([], 240) }

        let nominalFPS = try await track.load(.nominalFrameRate)
        let fps = nominalFPS > 0 ? Double(nominalFPS) : 240

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { return ([], fps) }
        reader.add(output)
        reader.startReading()

        var collected: [DetectedTrajectory] = []

        let request = VNDetectTrajectoriesRequest(
            frameAnalysisSpacing: .zero,
            trajectoryLength: 5
        ) { req, _ in
            guard let observations = req.results as? [VNTrajectoryObservation] else { return }
            for obs in observations {
                let pts = obs.detectedPoints.map(\.location)
                collected.append(DetectedTrajectory(points: pts, firstFrameIndex: 0))
            }
        }
        request.objectMinimumNormalizedRadius = 0.002
        request.objectMaximumNormalizedRadius = 0.05

        let handler = VNSequenceRequestHandler()

        while reader.status == .reading, let sample = output.copyNextSampleBuffer() {
            try? handler.perform([request], on: sample)
        }

        var unique: [DetectedTrajectory] = []
        for t in collected where unique.allSatisfy({ !sameTrajectory($0, t) }) {
            unique.append(t)
        }
        return (unique, fps)
    }

    private func sameTrajectory(_ a: DetectedTrajectory, _ b: DetectedTrajectory) -> Bool {
        guard a.points.count == b.points.count else { return false }
        for (p, q) in zip(a.points, b.points) {
            if hypot(p.x - q.x, p.y - q.y) > 0.001 { return false }
        }
        return true
    }
}
