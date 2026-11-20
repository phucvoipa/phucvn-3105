import SwiftUI

struct AppUtilityToolbar: ToolbarContent {
    let language: AppLanguage
    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button(action: onOpenSettings) {
                    Label(language.text("settings.title"), systemImage: "gearshape")
                }
                Button(action: onOpenLogs) {
                    Label(language.text("accessibility.open_logs"), systemImage: "apple.terminal")
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.elevatedBackground, AppTheme.consoleBackground],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay { StudioGlassHighlight(cornerRadius: 14, intensity: 0.75) }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    }
            }
            .buttonStyle(AppPressableStyle())
            .accessibilityLabel(language.text("accessibility.open_settings"))
        }
    }
}

extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .installed: return "tab.installed"
        case .files: return "tab.files"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .installed: return "square.stack.3d.up.fill"
        case .files: return "folder.fill"
        }
    }
}
