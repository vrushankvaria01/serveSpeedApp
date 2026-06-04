import AVFoundation
import Combine

@MainActor
final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var recordingContinuation: CheckedContinuation<URL?, Never>?

    @Published private(set) var isConfigured = false
    @Published private(set) var isRecording = false
    @Published private(set) var activeFPS: Double = 0

    func configure() async {
        guard !isConfigured else { return }
        guard await requestPermission() else { return }

        session.beginConfiguration()
        session.sessionPreset = .inputPriority

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            session.commitConfiguration()
            return
        }

        let hd1080Formats = device.formats.filter { f in
            let dims = CMVideoFormatDescriptionGetDimensions(f.formatDescription)
            return dims.width == 1920 && dims.height == 1080
        }
        let best = hd1080Formats.max { a, b in
            (a.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0) <
            (b.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0)
        }

        do {
            try device.lockForConfiguration()
            if let format = best,
               let range = format.videoSupportedFrameRateRanges.first {
                device.activeFormat = format
                let fps = min(240.0, range.maxFrameRate)
                let duration = CMTime(value: 1, timescale: Int32(fps))
                device.activeVideoMinFrameDuration = duration
                device.activeVideoMaxFrameDuration = duration
                activeFPS = fps
            }
            device.unlockForConfiguration()

            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
        } catch {
            session.commitConfiguration()
            return
        }

        if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }

        if let connection = movieOutput.connection(with: .video),
           connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = .off
        }

        session.commitConfiguration()
        isConfigured = true

        Task.detached { [session] in
            session.startRunning()
        }
    }

    private func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    func startRecording() {
        guard isConfigured, !movieOutput.isRecording else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
    }

    func stopRecording() async -> URL? {
        guard movieOutput.isRecording else { return nil }
        return await withCheckedContinuation { cont in
            self.recordingContinuation = cont
            movieOutput.stopRecording()
        }
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                                didFinishRecordingTo outputFileURL: URL,
                                from connections: [AVCaptureConnection],
                                error: Error?) {
        Task { @MainActor in
            self.isRecording = false
            let url: URL? = (error == nil) ? outputFileURL : nil
            self.recordingContinuation?.resume(returning: url)
            self.recordingContinuation = nil
        }
    }
}
