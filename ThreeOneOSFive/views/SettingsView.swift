import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    pageHeading
                    deviceCard

                    SettingsGroup(title: "THÔNG TIN PHIÊN BẢN") {
                        SettingsValueRow(
                            symbol: "gearshape.2.fill",
                            title: "Phiên bản iOS",
                            value: AppInfo.osVersion
                        )
                        SettingsRowDivider()
                        SettingsValueRow(
                            symbol: "number",
                            title: "Mã bản dựng iOS",
                            value: AppInfo.osBuild
                        )
                        SettingsRowDivider()
                        SettingsValueRow(
                            symbol: "app.badge",
                            title: "Phiên bản ứng dụng",
                            value: appVersion
                        )
                        SettingsRowDivider()
                        SettingsValueRow(
                            symbol: "hammer.fill",
                            title: "Bản dựng ứng dụng",
                            value: appBuild
                        )
                        SettingsRowDivider()
                        SettingsValueRow(
                            symbol: "person.crop.circle.fill",
                            title: "Tác giả / Phát triển",
                            value: "PHUCVN"
                        )
                    }

                    SettingsGroup(title: "BẢN QUYỀN & MÁY CHỦ KEY") {
                        SettingsValueRow(
                            symbol: "key.fill",
                            title: "Mã Key hiện tại",
                            value: KeyAuthManager.shared.currentKey.isEmpty ? "Chưa kích hoạt" : KeyAuthManager.shared.currentKey
                        )
                        SettingsRowDivider()
                        SettingsValueRow(
                            symbol: "clock.fill",
                            title: "Thời hạn bản quyền",
                            value: KeyAuthManager.shared.expiryText.isEmpty ? "Vĩnh Viễn" : KeyAuthManager.shared.expiryText
                        )
                        SettingsRowDivider()
                        SettingsValueRow(
                            symbol: "crown.fill",
                            title: "Cấp độ tài khoản",
                            value: KeyAuthManager.shared.role
                        )
                        SettingsRowDivider()
                        Button {
                            KeyAuthManager.shared.unlinkKey()
                        } label: {
                            HStack {
                                SettingsSymbol(symbol: "rectangle.portrait.and.arrow.right", tint: AppTheme.danger)
                                Text("Hủy kích hoạt / Đổi Key mới")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.danger)
                                Spacer()
                            }
                            .padding(.vertical, 7)
                        }
                    }

                    SettingsGroup(title: "TRẠNG THÁI HỆ THỐNG") {
                        HStack(spacing: 12) {
                            SettingsSymbol(symbol: "hammer.fill", tint: AppTheme.accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Chế độ nhà phát triển")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("Được bật cố định. Không có tùy chọn tắt trong ứng dụng.")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(AppTheme.subduedText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 5)
                            AppStatusPill(title: "LUÔN BẬT", tint: AppTheme.success, systemName: "lock.fill")
                        }
                        .padding(.vertical, 7)

                        SettingsRowDivider()

                        HStack(spacing: 12) {
                            SettingsSymbol(
                                symbol: "checkmark.shield.fill",
                                tint: appState.isSupported ? AppTheme.success : AppTheme.warning
                            )
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Khả năng tương thích")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("iOS \(AppInfo.osVersion) · \(AppInfo.osBuild)")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(AppTheme.subduedText)
                            }
                            Spacer(minLength: 8)
                            Text(language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"))
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .tracking(0.45)
                                .foregroundStyle(appState.isSupported ? AppTheme.success : AppTheme.warning)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 7)
                                .background(
                                    (appState.isSupported ? AppTheme.success : AppTheme.warning).opacity(0.12),
                                    in: Capsule()
                                )
                        }
                        .padding(.vertical, 8)
                    }

                    SettingsGroup(title: "CÔNG CỤ VÀ BẢO TRÌ") {
                        NavigationLink {
                            CleanerView()
                        } label: {
                            SettingsNavigationRow(
                                symbol: "sparkles",
                                title: "Dọn dẹp & bảo trì",
                                detail: "Quét bộ nhớ đệm và tệp tạm an toàn"
                            )
                        }
                        .buttonStyle(.plain)

                        if WallpaperFeatureSupportPolicy.isSupported(major: AppInfo.versionTuple.major) {
                            SettingsRowDivider()
                            NavigationLink {
                                WallpaperResetSettingsView()
                            } label: {
                                SettingsNavigationRow(
                                    symbol: "arrow.counterclockwise",
                                    title: "Đặt lại hình nền",
                                    detail: language.text("wallpaper.reset_settings_footer")
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    footer
                }
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.top, 17)
                .padding(.bottom, 32)
            }
            .background { AppPageBackground() }
            .navigationTitle("Cài đặt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.pageBackground.opacity(0.92), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { dismiss() }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .tint(AppTheme.accent)
    }

    private var pageHeading: some View {
        HStack(spacing: 13) {
            AppLogo(size: 52)
            VStack(alignment: .leading, spacing: 4) {
                StudioEyebrow(text: "TÙY CHỈNH HỆ THỐNG")
                Text("Cài đặt")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .tracking(-0.55)
                    .foregroundStyle(.white)
                Text("Thông tin thiết bị và trạng thái vận hành")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.subduedText)
            }
            Spacer(minLength: 0)
        }
    }

    private var deviceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                StudioEyebrow(text: "THIẾT BỊ HIỆN TẠI")
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.success)
            }

            HStack(alignment: .center, spacing: 15) {
                ZStack {
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.17), Color.white.opacity(0.035)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    Image(systemName: "iphone.gen3")
                        .font(.system(size: 31, weight: .ultraLight))
                        .foregroundStyle(AppTheme.accent)
                }
                .frame(width: 70, height: 78)

                VStack(alignment: .leading, spacing: 5) {
                    Text(AppInfo.hardwareDisplayName)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .tracking(-0.35)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Text("iOS \(AppInfo.osVersion)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.accentSoft)
                    Text("Mã bản dựng: \(AppInfo.osBuild)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.subduedText)
                }
                Spacer(minLength: 0)
            }

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ỨNG DỤNG")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.subduedText)
                    Text("3105 × PHUCVN")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text("v\(appVersion)  ·  \(appBuild)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.accentSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(red: 0.14, green: 0.16, blue: 0.20), AppTheme.consoleBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 27, style: .continuous)
        )
        .overlay { StudioGlassHighlight(cornerRadius: 27, intensity: 0.9) }
        .overlay { AppCardBorder(cornerRadius: 27) }
        .shadow(color: .black.opacity(0.32), radius: 22, y: 10)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text("3105 × PHUCVN")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.75)
                .foregroundStyle(AppTheme.accentSoft.opacity(0.8))
            Text("Giao diện quản lý thiết bị")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(AppTheme.subduedText.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(1.55)
                .foregroundStyle(AppTheme.accentSoft)
                .padding(.horizontal, 3)

            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.elevatedBackground.opacity(0.94), AppTheme.consoleBackground],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay { StudioGlassHighlight(cornerRadius: 22, intensity: 0.75) }
            .overlay { AppCardBorder(cornerRadius: 22) }
        }
    }
}

private struct SettingsValueRow: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 11) {
            SettingsSymbol(symbol: symbol, tint: AppTheme.accentSoft)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.subduedText)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .padding(.vertical, 8)
    }
}

private struct SettingsNavigationRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            SettingsSymbol(symbol: symbol, tint: AppTheme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.subduedText)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.subduedText)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

private struct SettingsSymbol: View {
    let symbol: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(tint.opacity(0.12))
            .frame(width: 35, height: 35)
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
            }
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }
    }
}

private struct SettingsRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.hairline)
            .frame(height: 1)
            .padding(.leading, 47)
    }
}
