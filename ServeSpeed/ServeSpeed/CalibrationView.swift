import SwiftUI

struct CalibrationView: View {
    @Binding var corners: [CGPoint]
    let onConfirm: () -> Void

    private let labels = [
        "Back-left (service line, far sideline)",
        "Back-right (service line, center line)",
        "Front-right (net, center line)",
        "Front-left (net, far sideline)"
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard corners.count < 4 else { return }
                        corners.append(CGPoint(
                            x: location.x / geo.size.width,
                            y: location.y / geo.size.height
                        ))
                    }

                quadPath(in: geo.size)
                    .stroke(.yellow, lineWidth: 2)

                ForEach(Array(corners.enumerated()), id: \.offset) { idx, normalized in
                    let pt = CGPoint(x: normalized.x * geo.size.width,
                                     y: normalized.y * geo.size.height)
                    ZStack {
                        Circle().fill(.yellow).frame(width: 24, height: 24)
                        Text("\(idx + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.black)
                    }
                    .position(pt)
                }

                VStack {
                    Text(corners.count < 4
                         ? "Tap corner \(corners.count + 1)/4:\n\(labels[corners.count])"
                         : "Confirm to lock calibration")
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
                        .padding(.top, 20)

                    Spacer()

                    HStack(spacing: 16) {
                        Button("Reset") { corners = [] }
                            .buttonStyle(.bordered)
                        if corners.count == 4 {
                            Button("Confirm") { onConfirm() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 20)
            }
        }
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
}
