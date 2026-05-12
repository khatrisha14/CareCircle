import SwiftUI

// MARK: - Global typography (SF Pro Rounded, Dynamic Type friendly)

enum AppTextStyle {
    static let title = Font.system(.title, design: .rounded).weight(.bold)
    static let sectionTitle = Font.system(.title2, design: .rounded).weight(.semibold)
    static let body = Font.system(.body, design: .rounded)
    static let secondary = Font.system(.subheadline, design: .rounded)
    static let button = Font.system(.headline, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded)
}

// MARK: - CareCircle green theme (inspired by calm, nature-forward UI)

enum AppTheme {
    /// Dark forest green – primary buttons, selected states
    static let primaryGreen = Color(red: 0.11, green: 0.26, blue: 0.20)      // #1C4332
    /// Slightly lighter – hover/pressed
    static let primaryGreenLight = Color(red: 0.18, green: 0.42, blue: 0.33) // #2D6A54
    /// Mint / light green – gradient top
    static let mintGreen = Color(red: 0.58, green: 0.84, blue: 0.69)        // #95D7B0
    /// Mid green – gradient middle
    static let forestGreen = Color(red: 0.18, green: 0.42, blue: 0.33)      // #2D6A54
    /// Dark – gradient bottom
    static let darkForest = Color(red: 0.11, green: 0.26, blue: 0.20)      // #1C4332

    /// Full-screen gradient (light mint top → dark forest bottom)
    static var screenGradient: LinearGradient {
        LinearGradient(
            colors: [mintGreen, forestGreen, darkForest],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Card background (white with slight warmth)
    static let cardBackground = Color(red: 0.99, green: 0.99, blue: 0.98)
    /// Secondary card / unselected pills
    static let cardSecondary = Color(red: 0.95, green: 0.96, blue: 0.95)

    /// Soft white–green blend for liquid glass panels (muted, not loud)
    static let liquidGlassTint = Color.white.opacity(0.5)
    static let liquidGlassGreenTint = Color(red: 0.85, green: 0.95, blue: 0.88) // very light mint
}

// MARK: - Reusable card container (solid)

struct ThemedCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Liquid glass card (iOS 26+ native .glassEffect(), else material + tint fallback)

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(LiquidGlassCardModifier(cornerRadius: 20))
    }
}

/// iOS 26+: native .glassEffect(). Earlier: material + tint fallback.
struct LiquidGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(AppTheme.primaryGreen.opacity(0.2)), in: .rect(cornerRadius: cornerRadius))
                .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
        } else {
            content
                .background(liquidGlassFallbackBackground(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.6), Color.white.opacity(0.25)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        }
    }

    private func liquidGlassFallbackBackground(cornerRadius: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.liquidGlassGreenTint.opacity(0.45),
                            AppTheme.liquidGlassTint.opacity(0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

// MARK: - Primary green button style

struct PrimaryGreenButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTextStyle.button)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(configuration.isPressed ? AppTheme.primaryGreenLight : AppTheme.primaryGreen)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Secondary (bordered) button

struct SecondaryGreenButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTextStyle.button)
            .foregroundStyle(AppTheme.primaryGreen)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.cardSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppTheme.primaryGreen.opacity(0.4), lineWidth: 1.5)
            )
    }
}

// MARK: - Section title (for use on gradient)

struct ThemedSectionTitle: View {
    let title: String
    var body: some View {
        Text(title)
            .font(AppTextStyle.sectionTitle)
            .foregroundStyle(.primary)
    }
}
