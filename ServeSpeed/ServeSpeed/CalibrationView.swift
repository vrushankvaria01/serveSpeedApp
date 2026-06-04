import SwiftUI

struct CalibrationView: View {
    @Binding var corners: [CGPoint]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private let labels = [
        "Back-left (service line × far sideline)",
        "Back-right (service line × center line)",
        "Front-right (net × center line)",
        "Front-left (net × far sideline)"
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard corners.count < 4 else { return }
                        Haptic.tap(.light)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            corners.append(CGPoint(
                                x: location.x / geo.size.width,
                                y: location.y / geo.size.height
                            ))
                        }
                    }

                quadPath(in: geo.size)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: corners.count == 4 ? [] : [6, 6]))
                quadFill(in: geo.size)
                    .fill(Theme.accent.opacity(0.10))

                ForEach(Array(corners.enumerated()), id: \.offset) { idx, normalized in
                    let pt = CGPoint(x: normalized.x * geo.size.width,
                                     y: normalized.y * geo.size.height)
                    CornerMarker(index: idx + 1)
                        .position(pt)
                        .transition(.scale.combined(with: .opacity))
                }

                VStack {
                    headerCard
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    Spacer()
                    footerControls
                        .padding(.horizontal, 20)
                        .padding(.bottom, 36)
                }
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.accentSoft)
                    .frame(width: 44, height: 44)
                Text("\(min(corners.count + 1, 4))")
                    .font(Theme.display(20, weight: .black))
                    .foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(corners.count < 4 ? "Tap corner \(corners.count + 1) of 4" : "Confirm calibration")
                    .font(Theme.ui(15, weight: .bold))
                    .foregroundStyle(.white)
                Text(corners.count < 4 ? labels[corners.count] : "Lock the homography to start recording")
                    .font(Theme.ui(12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke, lineWidth: 1))
        )
    }

    private var footerControls: some View {
        HStack(spacing: 12) {
            Button {
                Haptic.tap(.light)
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))
            }
            .foregroundStyle(.white)

            Button {
                Haptic.tap(.light)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    corners = []
                }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))
            }
            .foregroundStyle(.white)

            if corners.count == 4 {
                Button("Confirm Calibration", action: onConfirm)
                    .buttonStyle(PillButtonStyle())
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                Color.clear.frame(height: 56)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: corners.count)
    }

    private func quadPath(in size: CGSize) -> Path {
        Path { p in
            guard corners.count >= 2 else { return }
            let pts = corners.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
            p.move(to: pts[0])
            for pt in pts.dropFirst() { p.addLine(to: pt) }
            if pts.count == 4 { p.closeSubpath() }
        }
    }

    private func quadFill(in size: CGSize) -> Path {
        Path { p in
            guard corners.count == 4 else { return }
            let pts = corners.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
            p.move(to: pts[0])
            for pt in pts.dropFirst() { p.addLine(to: pt) }
            p.closeSubpath()
        }
    }
}

private struct CornerMarker: View {
    let index: Int
    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.25))
                .frame(width: 42, height: 42)
            Circle()
                .fill(Theme.accent)
                .frame(width: 22, height: 22)
            Text("\(index)")
                .font(Theme.ui(11, weight: .heavy))
                .foregroundStyle(.black)
        }
        .shadow(color: Theme.accent.opacity(0.45), radius: 10)
    }
}
