import SwiftUI

/// Shared visual language for the 3105 × PHUCVN interface.
/// Presentation-only components live here; file, patch and device services are untouched.
enum AppBrand {
    static let name = "3105 × PHUCVN"
    static let artworkAsset = "BrandArtwork"
}

enum AppTheme {
    // Titanium palette: cool silver for primary actions, with restrained semantic accents.
    static let accent = Color(red: 0.93, green: 0.95, blue: 0.985)
    static let accentSoft = Color(red: 0.70, green: 0.77, blue: 0.88)
    static let accentDeep = Color(red: 0.34, green: 0.43, blue: 0.57)
    static let pageBackground = Color(red: 0.012, green: 0.017, blue: 0.027)
    static let consoleBackground = Color(red: 0.043, green: 0.055, blue: 0.074)
    static let elevatedBackground = Color(red: 0.080, green: 0.098, blue: 0.126)
    static let subduedText = Color(red: 0.68, green: 0.73, blue: 0.81)
    static let hairline = Color.white.opacity(0.11)
    static let silverGlow = Color(red: 0.78, green: 0.86, blue: 0.98)
    static let info = Color(red: 0.57, green: 0.73, blue: 0.98)
    static let success = Color(red: 0.48, green: 0.84, blue: 0.69)
    static let warning = Color(red: 0.96, green: 0.72, blue: 0.39)
    static let danger = Color(red: 0.96, green: 0.43, blue: 0.45)

    static let pageInset: CGFloat = 20
    static let rowIconSize: CGFloat = 17
    static let rowIconFrame: CGFloat = 38
    static let fileRowIconSize: CGFloat = 17
    static let fileRowIconFrame: CGFloat = 36
    static let fileRowHeight: CGFloat = 64
    static let appIconSize: CGFloat = 38
    static let emptyIconSize: CGFloat = 30
    static let selectionIconSize: CGFloat = 19
    static let contentCardCornerRadius: CGFloat = 25
    static let contentCardInset: CGFloat = 20
    static let contentCardPadding: CGFloat = 17
}

struct AppCardBorder: View {
    var cornerRadius: CGFloat = AppTheme.contentCardCornerRadius

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            .accessibilityHidden(true)
    }
}

/// A restrained specular layer that gives dark surfaces a glass-and-titanium finish.
struct StudioGlassHighlight: View {
    var cornerRadius: CGFloat = AppTheme.contentCardCornerRadius
    var intensity: Double = 1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(0.06 * intensity), lineWidth: 0.5)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct AppRowIcon: View {
    let systemName: String
    var tint: Color = AppTheme.accent
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.22), tint.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.10), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: frameSize, height: frameSize)
        .accessibilityHidden(true)
    }
}

struct AppLogo: View {
    var size: CGFloat = 44

    var body: some View {
        Image(AppBrand.artworkAsset)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.72), Color.white.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.13), .clear, Color.black.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .shadow(color: AppTheme.silverGlow.opacity(0.27), radius: 20, y: 6)
            .shadow(color: .black.opacity(0.38), radius: 8, y: 4)
            .accessibilityHidden(true)
    }
}

struct StudioEyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(1.65)
            .foregroundStyle(AppTheme.accentSoft)
            .lineLimit(1)
    }
}

struct StudioSectionHeading: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .tracking(-0.25)
                .foregroundStyle(.primary)
            Spacer(minLength: 4)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.subduedText)
            }
        }
    }
}

struct StudioPanel<Content: View>: View {
    var padding: CGFloat = 17
    var cornerRadius: CGFloat = AppTheme.contentCardCornerRadius
    let content: Content

    init(
        padding: CGFloat = 17,
        cornerRadius: CGFloat = AppTheme.contentCardCornerRadius,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                AppTheme.consoleBackground,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay { AppCardBorder(cornerRadius: cornerRadius) }
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }
}

struct AppPageBackground: View {
    var body: some View {
        AppTheme.pageBackground
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

struct BrandIdentityPanel: View {
    let version: String

    var body: some View {
        HStack(spacing: 14) {
            AppLogo(size: 58)
            VStack(alignment: .leading, spacing: 5) {
                Text(AppBrand.name)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .tracking(-0.35)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(version)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.subduedText)
            }
            Spacer(minLength: 0)
            Image(systemName: "sparkle")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppTheme.accentSoft)
                .accessibilityHidden(true)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [AppTheme.elevatedBackground, AppTheme.consoleBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay { StudioGlassHighlight(cornerRadius: 24, intensity: 0.8) }
        .overlay { AppCardBorder(cornerRadius: 24) }
        .shadow(color: .black.opacity(0.28), radius: 20, y: 8)
    }
}

struct AppStatusPill: View {
    let title: String
    var tint: Color = AppTheme.success
    var systemName: String = "checkmark.circle.fill"

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.75)
                .foregroundStyle(AppTheme.accent)
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            tint.opacity(0.10),
            in: Capsule()
        )
        .overlay { Capsule().strokeBorder(tint.opacity(0.28), lineWidth: 1) }
    }
}

struct AppRoundActionButton: View {
    let systemName: String
    let accessibilityTitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 42, height: 42)
                .background(
                    LinearGradient(
                        colors: [AppTheme.elevatedBackground, AppTheme.consoleBackground],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                }
        }
        .buttonStyle(AppPressableStyle())
        .accessibilityLabel(accessibilityTitle)
    }
}


/// Lightweight sheen pass with zero layout overhead.
struct StudioSheenModifier: ViewModifier {
    let cornerRadius: CGFloat
    let delay: Double

    func body(content: Content) -> some View {
        content
    }
}

/// Instant entrance without opacity drops or layout shifts that hide content.
struct AppEntranceModifier: ViewModifier {
    let isVisible: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
    }
}

extension View {
    func appEntrance(isVisible: Bool, delay: Double = 0) -> some View {
        modifier(AppEntranceModifier(isVisible: isVisible, delay: delay))
    }

    func studioSheen(cornerRadius: CGFloat = AppTheme.contentCardCornerRadius, delay: Double = 0) -> some View {
        modifier(StudioSheenModifier(cornerRadius: cornerRadius, delay: delay))
    }
}

/// High-performance responsive touch feedback (120 FPS ProMotion ready)
/// Eliminates 3D transforms, GPU brightness shader passes, and dynamic shadows on scroll/touch.
struct AppPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
