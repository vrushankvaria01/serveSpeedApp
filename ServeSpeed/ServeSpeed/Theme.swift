import SwiftUI
import UIKit

enum Theme {
    // Tennis-ball yellow-green — used sparingly for accents and CTAs
    static let accent      = Color(red: 0.84, green: 1.00, blue: 0.18)
    static let accentSoft  = Color(red: 0.84, green: 1.00, blue: 0.18).opacity(0.18)

    // Deep court surfaces
    static let background       = Color(red: 0.04, green: 0.05, blue: 0.07)
    static let surface          = Color(red: 0.09, green: 0.10, blue: 0.13)
    static let surfaceElevated  = Color(red: 0.13, green: 0.14, blue: 0.18)
    static let stroke           = Color.white.opacity(0.08)

    // Text
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.72)
    static let textTertiary  = Color.white.opacity(0.45)

    static let danger  = Color(red: 1.00, green: 0.27, blue: 0.27)
    static let warning = Color(red: 1.00, green: 0.78, blue: 0.18)

    // MARK: - Typography
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func ui(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Haptics

enum Haptic {
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: - Reusable styles

struct PillButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent
    var foreground: Color = .black

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.ui(17, weight: .bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule().fill(tint)
                    .shadow(color: tint.opacity(0.35), radius: 18, y: 8)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GhostPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.ui(15, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule().fill(.ultraThinMaterial)
                    .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct StatusPill: View {
    let systemImage: String
    let text: String
    var tint: Color = Theme.accent

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(Theme.ui(12, weight: .semibold))
                .tracking(0.4)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(tint.opacity(0.15))
                .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 1))
        )
    }
}
