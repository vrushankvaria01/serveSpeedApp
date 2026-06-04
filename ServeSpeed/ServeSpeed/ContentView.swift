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

enum SpeedUnit: String, CaseIterable {
    case mph = "MPH"
    case kmh = "KM/H"
}

struct ContentView: View {
    @StateObject private var camera = CameraManager()
    @State private var phase: Phase = .idle
    @State private var corners: [CGPoint] = []
    @State private var calibration: Homography?
    @State private var unit: SpeedUnit = .mph
    @State private var recordingStarted: Date?
    @State private var elapsed: TimeInterval = 0
    @State private var ticker: Timer?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            CameraPreview(session: camera.session)
                .ignoresSafeArea()
                .opacity(showCameraPreview ? 1 : 0.25)
                .blur(radius: showCameraPreview ? 0 : 12)
                .animation(.easeInOut(duration: 0.35), value: showCameraPreview)

            LinearGradient(
                colors: [.black.opacity(0.55), .clear, .black.opacity(0.85)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            content
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: phase)
        }
        .task { await camera.configure() }
        .preferredColorScheme(.dark)
    }

    private var showCameraPreview: Bool {
        switch phase {
        case .ready, .recording, .calibrating: return true
        default: return false
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:                  IdleScreen(onStart: startCalibration)
        case .calibrating:           calibrationScreen
        case .ready:                 readyScreen
        case .recording:             recordingScreen
        case .analyzing:             AnalyzingScreen()
        case .result(let r):         resultScreen(r)
        case .failed(let msg):       failedScreen(msg)
        }
    }

    // MARK: - Screens

    private var calibrationScreen: some View {
        CalibrationView(corners: $corners) {
            guard corners.count == 4,
                  let h = Homography.fromServiceBox(imagePoints: corners) else {
                Haptic.error()
                phase = .failed("Calibration failed — try again with corners further apart.")
                return
            }
            calibration = h
            Haptic.success()
            phase = .ready
        } onCancel: {
            phase = calibration == nil ? .idle : .ready
        }
    }

    private var readyScreen: some View {
        VStack {
            topBar(title: "Ready", actions: {
                Button("Recalibrate") {
                    Haptic.tap(.light)
                    corners = []
                    phase = .calibrating
                }
                .buttonStyle(GhostPillStyle())
            })

            Spacer()

            VStack(spacing: 12) {
                StatusPill(systemImage: "checkmark.seal.fill", text: "COURT LOCKED")
                Text("Tap to record your serve")
                    .font(Theme.ui(15))
                    .foregroundStyle(Theme.textSecondary)
            }

            ShutterButton(mode: .record) {
                Haptic.tap(.heavy)
                camera.startRecording()
                recordingStarted = Date()
                startTicker()
                phase = .recording
            }
            .padding(.top, 24)
            .padding(.bottom, 36)
        }
        .padding(.horizontal, 20)
    }

    private var recordingScreen: some View {
        VStack {
            topBar(title: "Recording", actions: {
                StatusPill(systemImage: "record.circle.fill", text: "REC", tint: Theme.danger)
                    .symbolEffect(.pulse, options: .repeating)
            })

            Spacer()

            Text(String(format: "%.1fs", elapsed))
                .font(Theme.display(64))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Text("\(Int(camera.activeFPS)) FPS · 1080p")
                .font(Theme.ui(13, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .tracking(1)

            ShutterButton(mode: .stop) {
                Haptic.tap(.heavy)
                stopTicker()
                Task { await finishRecording() }
            }
            .padding(.top, 24)
            .padding(.bottom, 36)
        }
        .padding(.horizontal, 20)
        .overlay {
            Rectangle()
                .stroke(Theme.danger.opacity(0.75), lineWidth: 3)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private func resultScreen(_ r: ServeResult) -> some View {
        ResultScreen(
            result: r,
            unit: $unit,
            onNext: {
                Haptic.tap(.light)
                phase = .ready
            },
            onRecalibrate: {
                Haptic.tap(.light)
                corners = []
                phase = .calibrating
            }
        )
        .onAppear { Haptic.success() }
    }

    private func failedScreen(_ msg: String) -> some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.warning.opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(Theme.warning)
            }

            VStack(spacing: 10) {
                Text("Couldn't read that serve")
                    .font(Theme.display(26, weight: .bold))
                Text(msg)
                    .font(Theme.ui(15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button("Try Again") {
                Haptic.tap(.light)
                phase = .ready
            }
            .buttonStyle(PillButtonStyle())
            .padding(.horizontal, 32)
            .padding(.bottom, 36)
        }
    }

    // MARK: - Components

    private func topBar(title: String, @ViewBuilder actions: () -> some View) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "tennisball.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 18, weight: .bold))
                Text(title.uppercased())
                    .font(Theme.ui(13, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            actions()
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func startCalibration() {
        Haptic.tap(.light)
        corners = []
        phase = .calibrating
    }

    private func finishRecording() async {
        let url = await camera.stopRecording()
        guard let url, let cal = calibration else {
            Haptic.error()
            phase = .failed("Recording failed. Please try again.")
            return
        }
        phase = .analyzing
        if let result = await SpeedCalculator.process(videoURL: url, calibration: cal) {
            phase = .result(result)
        } else {
            Haptic.warning()
            phase = .failed("Couldn't detect the ball. Check lighting, framing, and try again.")
        }
    }

    private func startTicker() {
        elapsed = 0
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let start = recordingStarted {
                elapsed = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
        recordingStarted = nil
    }
}

// MARK: - Idle screen

private struct IdleScreen: View {
    let onStart: () -> Void
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 240, height: 240)
                    .scaleEffect(pulse ? 1.08 : 1)
                    .opacity(pulse ? 0.5 : 1)
                Circle()
                    .fill(Theme.accent.opacity(0.18))
                    .frame(width: 170, height: 170)
                Image(systemName: "tennisball.fill")
                    .font(.system(size: 92))
                    .foregroundStyle(Theme.accent)
                    .shadow(color: Theme.accent.opacity(0.5), radius: 24)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }

            VStack(spacing: 12) {
                Text("Serve Speed")
                    .font(Theme.display(44, weight: .black))
                    .foregroundStyle(.white)
                Text("Radar-style speed measurement\nfor your tennis serve.")
                    .font(Theme.ui(16, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 44)

            Spacer()

            VStack(spacing: 16) {
                ChecklistRow(icon: "camera.fill", text: "Phone behind the server, ~6–10 ft back")
                ChecklistRow(icon: "sun.max.fill", text: "Good daylight (240 fps needs light)")
                ChecklistRow(icon: "viewfinder", text: "Frame the far service box")
            }
            .padding(.horizontal, 24)

            Spacer()

            Button("Calibrate Court", action: onStart)
                .buttonStyle(PillButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
        }
    }
}

private struct ChecklistRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.surfaceElevated)
                )
            Text(text)
                .font(Theme.ui(14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
    }
}

// MARK: - Analyzing screen

private struct AnalyzingScreen: View {
    @State private var spin = false
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .stroke(Theme.surfaceElevated, lineWidth: 6)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: 0.32)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                Image(systemName: "tennisball.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.accent)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    spin = true
                }
            }

            VStack(spacing: 6) {
                Text("Analyzing serve")
                    .font(Theme.display(22, weight: .bold))
                Text("Detecting ball trajectory…")
                    .font(Theme.ui(14))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
        }
    }
}

// MARK: - Result screen

private struct ResultScreen: View {
    let result: ServeResult
    @Binding var unit: SpeedUnit
    let onNext: () -> Void
    let onRecalibrate: () -> Void

    @State private var displayValue: Double = 0

    private var targetValue: Double {
        unit == .mph ? result.mph : result.kmh
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "tennisball.fill")
                        .foregroundStyle(Theme.accent)
                        .font(.system(size: 18, weight: .bold))
                    Text("SERVE COMPLETE")
                        .font(Theme.ui(13, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Button("Recalibrate", action: onRecalibrate)
                    .buttonStyle(GhostPillStyle())
            }
            .padding(.top, 8)
            .padding(.horizontal, 20)

            Spacer()

            VStack(spacing: 8) {
                Text(String(format: "%.0f", displayValue))
                    .font(Theme.display(180, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: displayValue))
                    .shadow(color: Theme.accent.opacity(0.35), radius: 28)

                Picker("Unit", selection: $unit) {
                    ForEach(SpeedUnit.allCases, id: \.self) { u in
                        Text(u.rawValue).tag(u)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .onChange(of: unit) { _, _ in Haptic.tap(.light) }
            }

            Spacer()

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    StatCard(label: "MPH", value: String(format: "%.0f", result.mph))
                    StatCard(label: "KM/H", value: String(format: "%.0f", result.kmh))
                    StatCard(label: "M/S",  value: String(format: "%.1f", result.kmh / 3.6))
                }

                Button("Next Serve", action: onNext)
                    .buttonStyle(PillButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .onAppear {
            displayValue = 0
            withAnimation(.spring(response: 1.1, dampingFraction: 0.9)) {
                displayValue = targetValue
            }
        }
        .onChange(of: unit) { _, _ in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                displayValue = targetValue
            }
        }
    }
}

private struct StatCard: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(Theme.display(22, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label)
                .font(Theme.ui(11, weight: .heavy))
                .tracking(1.3)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke, lineWidth: 1)
                )
        )
    }
}

// MARK: - Shutter button

private struct ShutterButton: View {
    enum Mode { case record, stop }
    let mode: Mode
    let action: () -> Void
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.9), lineWidth: 4)
                    .frame(width: 86, height: 86)

                Group {
                    if mode == .record {
                        Circle()
                            .fill(Theme.danger)
                            .frame(width: 66, height: 66)
                            .scaleEffect(pulse ? 1.06 : 1.0)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.danger)
                            .frame(width: 38, height: 38)
                    }
                }
                .shadow(color: Theme.danger.opacity(0.6), radius: 16, y: 4)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
