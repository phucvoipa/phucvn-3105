import SwiftUI

struct HomeDashboardView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showCleaner = false
    @State private var showWallpaper = false

    let isActive: Bool
    let onSelectSection: (AppSection) -> Void
    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    heading
                    heroPanel
                    deviceOverview
                    quickAccess
                    maintenancePanel
                    footer
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.top, 13)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.immediately)
            .background { AppPageBackground() }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCleaner) {
                CleanerView()
            }
            .sheet(isPresented: $showWallpaper) {
                WallpaperLabView(
                    onOpenSettings: onOpenSettings,
                    onOpenLogs: onOpenLogs
                )
            }
        }
    }

    private var heading: some View {
        HStack(spacing: 12) {
            AppLogo(size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(AppBrand.name)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .tracking(-0.45)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text("TRUNG TÂM ĐIỀU KHIỂN")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.65)
                    .foregroundStyle(AppTheme.subduedText)
            }

            Spacer(minLength: 0)

            Menu {
                Button(action: onOpenSettings) {
                    Label("Cài đặt", systemImage: "gearshape")
                }
                Button(action: onOpenLogs) {
                    Label("Nhật ký hoạt động", systemImage: "apple.terminal")
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.consoleBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.17), lineWidth: 1)
                    }
            }
            .accessibilityLabel("Cài đặt và nhật ký")
        }
        .padding(.top, 4)
    }

    private var heroPanel: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 29, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.17, green: 0.19, blue: 0.23),
                            Color(red: 0.075, green: 0.087, blue: 0.105),
                            Color(red: 0.035, green: 0.045, blue: 0.060)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    StudioEyebrow(text: "KHÔNG GIAN QUẢN LÝ")
                    Spacer()
                    Text("3105")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(Color.white.opacity(0.82))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.075), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("Kiểm soát thiết bị.\nĐơn giản và chính xác.")
                        .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 26 : 28, weight: .bold, design: .rounded))
                        .tracking(-0.85)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white, AppTheme.silverGlow, Color.white.opacity(0.83)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Công cụ, dữ liệu và bảo trì được sắp xếp trong một nơi.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.66))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                AppStatusPill(title: "HỆ THỐNG SẴN SÀNG", tint: AppTheme.success)
            }
            .padding(21)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 224)
        .clipShape(RoundedRectangle(cornerRadius: 29, style: .continuous))
        .overlay { AppCardBorder(cornerRadius: 29) }
        .shadow(color: .black.opacity(0.24), radius: 12, y: 6)
    }

    private var deviceOverview: some View {
        Button(action: onOpenSettings) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.13), Color.white.opacity(0.035)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                    Image(systemName: "iphone.gen3")
                        .font(.system(size: 23, weight: .light))
                        .foregroundStyle(AppTheme.accent)
                }
                .frame(width: 54, height: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text("THIẾT BỊ HIỆN TẠI")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(1.25)
                        .foregroundStyle(AppTheme.subduedText)
                    Text(AppInfo.hardwareDisplayName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("iOS \(AppInfo.osVersion) · \(AppInfo.osBuild)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.subduedText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.accentSoft)
            }
            .padding(13)
            .background(
                LinearGradient(
                    colors: [AppTheme.elevatedBackground, AppTheme.consoleBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 23, style: .continuous)
            )
            .overlay { StudioGlassHighlight(cornerRadius: 23, intensity: 0.8) }
            .overlay { AppCardBorder(cornerRadius: 23) }
        }
        .buttonStyle(AppPressableStyle())
        .accessibilityLabel("Thông tin thiết bị và phiên bản")
    }

    private var quickAccess: some View {
        VStack(alignment: .leading, spacing: 13) {
            StudioSectionHeading(title: "Công cụ chính", detail: "04 CÔNG CỤ")

            LazyVGrid(columns: columns, spacing: 12) {
                Button {
                    onSelectSection(.installed)
                } label: {
                    HomeToolCard(
                        symbol: "square.stack.3d.up.fill",
                        title: "Dự án của tôi",
                        detail: "Tạo và quản lý dự án",
                        tint: AppTheme.accent
                    )
                }
                .buttonStyle(AppPressableStyle())

                Button {
                    onSelectSection(.files)
                } label: {
                    HomeToolCard(
                        symbol: "folder.fill",
                        title: "Quản lý tệp",
                        detail: "Duyệt dữ liệu ứng dụng",
                        tint: AppTheme.info
                    )
                }
                .buttonStyle(AppPressableStyle())

                Button {
                    showCleaner = true
                } label: {
                    HomeToolCard(
                        symbol: "sparkles",
                        title: "Dọn dẹp",
                        detail: "Bảo trì bộ nhớ tạm",
                        tint: AppTheme.success
                    )
                }
                .buttonStyle(AppPressableStyle())

                if WallpaperFeatureSupportPolicy.isSupported(major: AppInfo.versionTuple.major) {
                    Button {
                        showWallpaper = true
                    } label: {
                        HomeToolCard(
                            symbol: "photo.on.rectangle.angled",
                            title: "Công cụ hình nền",
                            detail: "Quản lý gói hình nền",
                            tint: AppTheme.accentSoft
                        )
                    }
                    .buttonStyle(AppPressableStyle())
                } else {
                    Button(action: onOpenSettings) {
                        HomeToolCard(
                            symbol: "iphone.gen3",
                            title: "Thông tin thiết bị",
                            detail: "Phiên bản và trạng thái",
                            tint: AppTheme.accentSoft
                        )
                    }
                    .buttonStyle(AppPressableStyle())
                }
            }
        }
    }

    private var maintenancePanel: some View {
        Button {
            showCleaner = true
        } label: {
            HStack(spacing: 14) {
                AppRowIcon(
                    systemName: "shield.lefthalf.filled",
                    tint: AppTheme.success,
                    symbolSize: 20,
                    frameSize: 48
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Dọn dẹp & bảo trì")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Quét bộ nhớ tạm trong phạm vi an toàn")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.subduedText)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.07), in: Circle())
            }
            .padding(15)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.105, green: 0.145, blue: 0.135), AppTheme.consoleBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay { StudioGlassHighlight(cornerRadius: 22, intensity: 0.75) }
            .overlay { AppCardBorder(cornerRadius: 22) }
        }
        .buttonStyle(AppPressableStyle())
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(AppTheme.accentSoft.opacity(0.45))
                .frame(width: 20, height: 2)
            Text("3105 × PHUCVN")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(AppTheme.subduedText.opacity(0.7))
            Capsule()
                .fill(AppTheme.accentSoft.opacity(0.45))
                .frame(width: 20, height: 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }
}

private struct HomeToolCard: View {
    let symbol: String
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                HomeToolSymbol(symbolName: symbol, tint: tint)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.subduedText)
                    .frame(width: 27, height: 27)
                    .background(Color.white.opacity(0.055), in: Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(-0.15)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(detail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AppTheme.subduedText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .padding(14)
        .background(
            AppTheme.consoleBackground,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay { AppCardBorder(cornerRadius: 22) }
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }
}

private struct HomeToolSymbol: View {
    let symbolName: String
    let tint: Color

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
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: symbolName)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(tint)
                .shadow(color: tint.opacity(0.34), radius: 7, y: 1)
        }
        .frame(width: 43, height: 43)
        .shadow(color: tint.opacity(0.10), radius: 9, y: 3)
    }
}
