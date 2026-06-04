import SwiftUI

struct ServeResult: Equatable {
    let mph: Double
    let kmh: Double
}

enum Phase: Equatable {
    case idle
    case calibrating
    case ready
    case recording
    case analyzing
    case result(ServeResult)
    case failed(String)
}

struct ContentView: View {
    @StateObject private var camera = CameraManager()
    @State private var phase: Phase = .idle
    @State private var corners: [CGPoint] = []
    @State private var calibration: Homography?

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            overlay
                .animation(.easeInOut(duration: 0.2), value: phase)
        }
        .task { await camera.configure() }
    }

    @ViewBuilder
    private var overlay: some View {
        switch phase {
        case .idle:                idleOverlay
        case .calibrating:         calibrationOverlay
        case .ready:               readyOverlay
        case .recording:           recordingOverlay
        case .analyzing:           analyzingOverlay
        case .result(let r):       resultOverlay(r)
        case .failed(let msg):     failedOverlay(msg)
        }
    }

    private var idleOverlay: some View {
        VStack {
            Spacer()
            Text("Serve Speed")
                .font(.system(size: 44, weight: .bold, design: .rounded))
            Text("Point the phone behind the server.\nCalibrate by tapping the far service box corners.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .opacity(0.8)
            Spacer()
            Button {
                corners = []
                phase = .calibrating
            } label: {
                Text("Calibrate Court")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    private var calibrationOverlay: some View {
        CalibrationView(corners: $corners) {
            guard corners.count == 4,
                  let h = Homography.fromServiceBox(imagePoints: corners) else {
                phase = .failed("Calibration failed — try again with corners further apart")
                return
            }
            calibration = h
            phase = .ready
        }
    }

    private var readyOverlay: some View {
        VStack {
            HStack {
                Button("Recalibrate") {
                    corners = []
                    phase = .calibrating
                }
                .buttonStyle(.bordered)
                .padding()
                Spacer()
            }
            Spacer()
            Text("Tap to record your serve")
                .padding(.bottom, 8)
                .opacity(0.8)
            Button {
                camera.startRecording()
                phase = .recording
            } label: {
                Circle()
                    .fill(.red)
                    .frame(width: 78, height: 78)
                    .overlay(Circle().stroke(.white, lineWidth: 4).padding(4))
            }
            .padding(.bottom, 40)
        }
    }

    private var recordingOverlay: some View {
        VStack {
            HStack {
                Circle().fill(.red).frame(width: 12, height: 12)
                Text("REC").font(.caption.bold())
            }
            .padding(.top, 60)
            Spacer()
            Button {
                Task { await finishRecording() }
            } label: {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.red)
                    .frame(width: 78, height: 78)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white, lineWidth: 4).padding(4))
            }
            .padding(.bottom, 40)
        }
    }

    private var analyzingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.6)
                .tint(.white)
            Text("Analyzing serve…")
                .font(.headline)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func resultOverlay(_ r: ServeResult) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Text(String(format: "%.0f", r.mph))
                .font(.system(size: 140, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("MPH")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(String(format: "%.0f km/h", r.kmh))
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 8)
            Spacer()
            Button {
                phase = .ready
            } label: {
                Text("Next Serve")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .background(.black.opacity(0.55))
    }

    private func failedOverlay(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)
            Text(msg)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Button("Try Again") { phase = .ready }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 40)
        }
        .background(.black.opacity(0.55))
    }

    private func finishRecording() async {
        let url = await camera.stopRecording()
        guard let url, let cal = calibration else {
            phase = .failed("Recording failed")
            return
        }
        phase = .analyzing
        if let result = await SpeedCalculator.process(videoURL: url, calibration: cal) {
            phase = .result(result)
        } else {
            phase = .failed("Couldn't detect the ball. Check lighting and try again.")
        }
    }
}
