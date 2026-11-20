import SwiftUI
import UIKit

struct AppDataBrowserView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var apps: [InstalledApp] = []
    @State private var appSearchText = ""
    @FocusState private var isAppSearchFocused: Bool
    @State private var isLoading = false
    @State private var isResolving = false
    @State private var errorMessage: String?
    @State private var hasLoaded = false
    @State private var workspaceURL: URL?
    @State private var reloadGeneration = 0
    @State private var heroSweepProgress: CGFloat = -1.15
    @State private var heroOrbitRotation: Double = -18
    @State private var heroAuraScale: CGFloat = 0.94
    @State private var heroSweepGeneration = 0

    @Binding private var tabSession: FilesTabSession
    let isActive: Bool
    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    init(
        tabSession: Binding<FilesTabSession>,
        isActive: Bool = true,
        onOpenSettings: @escaping () -> Void = {},
        onOpenLogs: @escaping () -> Void = {}
    ) {
        _tabSession = tabSession
        self.isActive = isActive
        self.onOpenSettings = onOpenSettings
        self.onOpenLogs = onOpenLogs
    }

    private var filteredApps: [InstalledApp] {
        let query = appSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return apps }

        return apps.filter { app in
            app.displayName.localizedStandardContains(query)
                || app.bundleID.localizedStandardContains(query)
                || app.version.localizedStandardContains(query)
        }
    }

    private var hasAppSearchQuery: Bool {
        !appSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var overlayState: AppBrowserOverlayState {
        if (isLoading || isResolving) && apps.isEmpty { return .loading }
        if apps.isEmpty { return .empty }
        return .none
    }

    private var interfaceAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.24)
    }

    var body: some View {
        navigationContent(tabID: tabSession.selectedTabID)
            .id(tabSession.selectedTabID)
    }

    private func navigationContent(tabID: UUID) -> some View {
        NavigationStack(path: navigationPath(for: tabID)) {
            appList
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(AppTheme.pageBackground.opacity(0.96), for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        FilesTabToolbarButton(session: $tabSession)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { reload() } label: {
                            if isResolving {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(isResolving)
                        .accessibilityLabel(language.text("browser.retry"))
                    }
                    AppUtilityToolbar(
                        language: language,
                        onOpenSettings: onOpenSettings,
                        onOpenLogs: onOpenLogs
                    )
                }
                .onAppear {
                    if workspaceURL == nil {
                        workspaceURL = try? PatchWorkspaceService.documentsRootURL()
                        _ = try? PatchWorkspaceService.patchesRootURL()
                    }
                    if !hasLoaded {
                        hasLoaded = true
                        reload()
                    }
                }
                .navigationDestination(for: FileBrowserDestination.self) { destination in
                    if destination.startPath == destination.containerPath {
                        FileBrowserView(
                            containerPath: destination.containerPath,
                            title: destination.title,
                            bundleID: destination.bundleID,
                            filesTabSession: $tabSession
                        )
                    } else {
                        FileBrowserView(
                            containerPath: destination.containerPath,
                            startPath: destination.startPath,
                            title: destination.title,
                            bundleID: destination.bundleID,
                            filesTabSession: $tabSession
                        )
                    }
                }
        }
    }

    /// Write the complete value back through the Binding. This keeps each file tab's
    /// navigation stack in sync when a destination is pushed or popped.
    private func navigationPath(for tabID: UUID) -> Binding<[FileBrowserDestination]> {
        Binding(
            get: { tabSession.navigationPath(for: tabID) },
            set: { newPath in
                var updatedSession = tabSession
                updatedSession.setNavigationPath(newPath, for: tabID)
                tabSession = updatedSession
            }
        )
    }

    private var appList: some View {
        VStack(spacing: 0) {
            browserHero
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.top, 9)
                .padding(.bottom, 13)

            appSearchField
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.bottom, 12)

            if horizontalSizeClass == .regular {
                FilesTabStrip(session: $tabSession)
                    .padding(.bottom, 8)
            }

            appCollection
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background { AppPageBackground() }
        .onAppear {
            if isActive { playHeroSweep() }
        }
        .onChange(of: isActive) { active in
            if active {
                playHeroSweep()
            } else {
                heroSweepGeneration += 1
                heroSweepProgress = -1.15
                heroOrbitRotation = -18
                heroAuraScale = 0.94
            }
        }
    }

    private func playHeroSweep() {
        heroSweepGeneration += 1
        let sequence = heroSweepGeneration
        heroSweepProgress = -1.15
        heroOrbitRotation = -18
        heroAuraScale = 0.94
        guard !reduceMotion else {
            heroOrbitRotation = -7
            heroAuraScale = 1
            return
        }
        DispatchQueue.main.async {
            guard sequence == heroSweepGeneration, isActive else { return }
            withAnimation(.easeInOut(duration: 1.5)) {
                heroSweepProgress = 1.25
            }
            withAnimation(.spring(response: 1.0, dampingFraction: 0.78).delay(0.08)) {
                heroOrbitRotation = 5
                heroAuraScale = 1.06
            }
        }
    }

    private var browserHero: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.19, green: 0.22, blue: 0.28),
                            Color(red: 0.085, green: 0.105, blue: 0.14),
                            AppTheme.consoleBackground
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            GeometryReader { proxy in
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.17), lineWidth: 1)
                        .frame(width: 180, height: 180)
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        .frame(width: 140, height: 140)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AppTheme.silverGlow.opacity(0.22), AppTheme.silverGlow.opacity(0.045), .clear],
                                center: .center,
                                startRadius: 3,
                                endRadius: 84
                            )
                        )
                        .frame(width: 168, height: 168)
                        .scaleEffect(heroAuraScale)
                    Circle()
                        .stroke(AppTheme.silverGlow.opacity(0.25), lineWidth: 1.2)
                        .frame(width: 92, height: 92)
                        .overlay {
                            Circle().stroke(Color.white.opacity(0.08), lineWidth: 5).padding(6)
                        }
                        .scaleEffect(heroAuraScale)
                }
                .offset(x: proxy.size.width - 79, y: -53)
                .rotationEffect(.degrees(heroOrbitRotation))
            }
            .accessibilityHidden(true)

            GeometryReader { proxy in
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.19), Color.white.opacity(0.07), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: max(78, proxy.size.width * 0.32))
                .rotationEffect(.degrees(19))
                .offset(x: heroSweepProgress * proxy.size.width * 1.3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    StudioEyebrow(text: "NMINHIOS  /  DATA STUDIO")
                    Spacer(minLength: 8)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppTheme.success)
                            .frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.1)
                            .foregroundStyle(AppTheme.success)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(AppTheme.success.opacity(0.10), in: Capsule())
                    .overlay { Capsule().strokeBorder(AppTheme.success.opacity(0.25), lineWidth: 1) }
                }

                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Kho dữ liệu")
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                            .tracking(-0.75)
                            .foregroundStyle(.white)
                        Text("Chọn ứng dụng để mở vùng dữ liệu riêng.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.70))
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%02d", filteredApps.count))
                            .font(.system(size: 29, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .tracking(-1)
                            .foregroundStyle(AppTheme.accent)
                            .contentTransition(.numericText())
                        Text("ỨNG DỤNG")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .tracking(1.1)
                            .foregroundStyle(AppTheme.subduedText)
                    }
                }
            }
            .padding(17)
        }
        .frame(minHeight: 134)
        .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
        .overlay { StudioGlassHighlight(cornerRadius: 27, intensity: 1.0) }
        .overlay { AppCardBorder(cornerRadius: 27) }
        .shadow(color: AppTheme.silverGlow.opacity(0.14), radius: 23, y: 10)
        .shadow(color: .black.opacity(0.24), radius: 12, y: 7)
        .rotation3DEffect(.degrees(-1.1), axis: (x: 1, y: 0, z: 0), perspective: 0.8)
    }

    private var appSearchField: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.accentSoft)
                .accessibilityHidden(true)

            TextField(language.text("browser.search_apps_placeholder"), text: $appSearchText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.accent)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isAppSearchFocused)
                .accessibilityLabel(language.text("browser.search_apps_placeholder"))

            if !appSearchText.isEmpty {
                Button {
                    withAnimation(interfaceAnimation) { appSearchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppTheme.subduedText)
                        .frame(width: 30, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(language.text("browser.clear_search"))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.leading, 15)
        .padding(.trailing, 7)
        .frame(height: 51)
        .background {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(AppTheme.elevatedBackground.opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.065), .clear, Color.black.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .overlay { StudioGlassHighlight(cornerRadius: 17, intensity: 0.65) }
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(
                    isAppSearchFocused ? AppTheme.accentSoft.opacity(0.78) : Color.white.opacity(0.13),
                    lineWidth: isAppSearchFocused ? 1.3 : 1
                )
        }
        .shadow(
            color: isAppSearchFocused ? AppTheme.silverGlow.opacity(0.17) : .black.opacity(0.22),
            radius: isAppSearchFocused ? 17 : 12,
            y: 5
        )
        .animation(interfaceAnimation, value: appSearchText.isEmpty)
        .animation(interfaceAnimation, value: isAppSearchFocused)
    }

    /// ScrollView + LazyVStack replaces the nested List. Each navigation row is now
    /// a single full-width hit target with a predictable frame on compact iPhones.
    private var appCollection: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let workspaceURL {
                    workspaceCard(workspaceURL)
                }

                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(hasAppSearchQuery ? "KẾT QUẢ TÌM KIẾM" : "ỨNG DỤNG ĐÃ PHÁT HIỆN")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1.25)
                            .foregroundStyle(AppTheme.accentSoft)
                        Text(hasAppSearchQuery
                             ? language.text("browser.search_count", Int64(filteredApps.count), Int64(apps.count))
                             : language.text("browser.apps_count", Int64(apps.count)))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.subduedText)
                    }
                    Spacer()
                    if isResolving && !apps.isEmpty {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini)
                            Text(language.text("browser.mha_scanning"))
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(AppTheme.subduedText)
                    }
                }
                .padding(.horizontal, 3)
                .padding(.top, 4)
                .padding(.bottom, 1)

                if filteredApps.isEmpty && !apps.isEmpty {
                    appSearchEmptyState
                } else {
                    ForEach(filteredApps) { app in
                        appNavigationRow(app)
                    }
                }

            }
            .padding(.horizontal, AppTheme.pageInset)
            .padding(.top, 9)
            .padding(.bottom, 30)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .overlay {
            Group {
                switch overlayState {
                case .loading:
                    VStack(spacing: 13) {
                        ProgressView().tint(AppTheme.accent)
                        Text(language.text("browser.loading"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.subduedText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.pageBackground.opacity(0.76))
                case .empty:
                    emptyView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.pageBackground.opacity(0.76))
                case .none:
                    EmptyView()
                }
            }
            .transition(.opacity)
            .animation(interfaceAnimation, value: overlayState)
        }
    }

    private func workspaceCard(_ url: URL) -> some View {
        let destination = FileBrowserDestination(
            containerPath: url.path,
            startPath: url.path,
            title: AppBrand.name,
            bundleID: nil
        )

        return Button {
            pushDestination(destination)
        } label: {
            HStack(spacing: 13) {
                AppRowIcon(systemName: "shippingbox.fill", tint: AppTheme.success, symbolSize: 19, frameSize: 45)
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppBrand.name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(language.text("browser.workspace_subtitle"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.subduedText)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.success)
                    .frame(width: 31, height: 31)
                    .background(AppTheme.success.opacity(0.10), in: Circle())
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardSurface(tint: AppTheme.success))
            .contentShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        }
        .buttonStyle(AppPressableStyle())
        .contextMenu {
            openInNewTabButton(destination)
        }
        .accessibilityLabel("Mở không gian dữ liệu \(AppBrand.name)")
    }

    @ViewBuilder
    private func appNavigationRow(_ app: InstalledApp) -> some View {
        let destination = FileBrowserDestination(
            containerPath: app.containerPath,
            startPath: app.containerPath,
            title: app.displayName,
            bundleID: app.bundleID
        )

        if app.containerPath.isEmpty {
            appCard(app, isAvailable: false)
                .accessibilityHint("Không tìm thấy đường dẫn dữ liệu của ứng dụng này")
        } else {
            Button {
                pushDestination(destination)
            } label: {
                appCard(app, isAvailable: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
            }
            .buttonStyle(AppPressableStyle())
            .contextMenu {
                openInNewTabButton(destination)
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint("Chạm để mở dữ liệu ứng dụng")
        }
    }

    private func appCard(_ app: InstalledApp, isAvailable: Bool) -> some View {
        HStack(spacing: 13) {
            BrowserAppIcon(app: app)
                .frame(width: 47, height: 47)
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.035)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.11), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.17), lineWidth: 1)
                }
                .shadow(color: AppTheme.silverGlow.opacity(0.08), radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(app.displayName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.86)

                Text(app.bundleID)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.subduedText)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if !app.version.isEmpty {
                    Text("VERSION  \(app.version)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.45)
                        .foregroundStyle(AppTheme.accentSoft.opacity(0.86))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: isAvailable ? "chevron.right" : "lock.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isAvailable ? AppTheme.accent : AppTheme.subduedText)
                .frame(width: 31, height: 31)
                .background(Color.white.opacity(0.065), in: Circle())
                .overlay { Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1) }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(minHeight: 76)
        .background(cardSurface(tint: isAvailable ? AppTheme.accentSoft : AppTheme.subduedText))
        .opacity(isAvailable ? 1 : 0.58)
    }

    private func cardSurface(tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 21, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        AppTheme.elevatedBackground.opacity(0.98),
                        AppTheme.consoleBackground.opacity(0.97)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.055), .clear, Color.black.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [tint.opacity(0.105), .clear],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: 190
                        )
                    )
            }
            .overlay { StudioGlassHighlight(cornerRadius: 21, intensity: 0.78) }
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [tint.opacity(0.42), Color.white.opacity(0.14), Color.white.opacity(0.045)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.28), radius: 15, y: 7)
            .shadow(color: tint.opacity(0.045), radius: 10, y: -1)
    }

    private var appSearchEmptyState: some View {
        VStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 27, weight: .light))
                .foregroundStyle(AppTheme.accentSoft)
            Text(language.text("browser.search_apps_no_results", appSearchText))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.subduedText)
                .multilineTextAlignment(.center)

            Button(language.text("browser.clear_search")) {
                withAnimation(interfaceAnimation) { appSearchText = "" }
            }
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(AppTheme.pageBackground)
            .padding(.horizontal, 17)
            .padding(.vertical, 10)
            .background(
                LinearGradient(colors: [AppTheme.accent, AppTheme.accentSoft], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Capsule()
            )
            .buttonStyle(AppPressableStyle())
        }
        .frame(maxWidth: .infinity, minHeight: 170)
        .padding(20)
        .background(cardSurface(tint: AppTheme.accentSoft))
    }

    /// Push directly into the selected tab's path from a real Button action. This
    /// avoids relying on implicit NavigationLink path mutations inside a scrolling row.
    private func pushDestination(_ destination: FileBrowserDestination) {
        var updatedSession = tabSession
        let tabID = updatedSession.selectedTabID
        var path = updatedSession.navigationPath(for: tabID)
        path.append(destination)
        updatedSession.setNavigationPath(path, for: tabID)
        tabSession = updatedSession
    }

    private func openInNewTabButton(_ destination: FileBrowserDestination) -> some View {
        Button {
            var updatedSession = tabSession
            updatedSession.openTab(navigationPath: [destination])
            tabSession = updatedSession
        } label: {
            Label(language.text("browser.open_new_tab"), systemImage: "square.on.square")
        }
    }

    private var emptyView: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentSoft.opacity(0.09))
                    .frame(width: 88, height: 88)
                Circle()
                    .strokeBorder(AppTheme.accentSoft.opacity(0.22), lineWidth: 1)
                    .frame(width: 88, height: 88)
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 29, weight: .light))
                    .foregroundStyle(AppTheme.accentSoft)
            }
            Text(errorMessage ?? language.text("browser.empty"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.subduedText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 25)
            Button(language.text("browser.retry")) { reload() }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.pageBackground)
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .background(AppTheme.accent, in: Capsule())
                .buttonStyle(AppPressableStyle())
        }
        .padding(24)
    }

    private func reload() {
        reloadGeneration += 1
        let requestID = reloadGeneration
        isLoading = true
        isResolving = true
        errorMessage = nil
        let emptyMessage = language.text("browser.empty")

        DispatchQueue.global(qos: .userInitiated).async {
            let bundleMetadata = ContainerStore.applicationBundleMetadataCatalog()
            let apiApps = ContainerStore.applyingBundleMetadata(
                to: ContainerStore.installedAppsFromAPI(),
                catalog: bundleMetadata
            )
            if apiApps.isEmpty {
                log("browser: installed-app API unavailable; trying MCM class-2 enumeration...")
            }

            let dynamicIdentifiers = ContainerStore.dynamicAppIdentifiers()
            let mcmApps = ContainerStore.installedAppsFromMCM(
                identifiers: dynamicIdentifiers,
                bundleMetadata: bundleMetadata
            )
            let filesystemApps = ContainerStore.containersFromFilesystem()
            let baseIdentifiedApps = mcmApps + apiApps
            var result = ContainerDiscoveryMerger.merge(
                enumerated: filesystemApps,
                identified: baseIdentifiedApps,
                path: { $0.containerPath }
            )
            log("browser: merged api=\(apiApps.count), MCM=\(mcmApps.count), filesystem=\(filesystemApps.count) -> \(result.count)")
            result.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

            let preliminary = result.filter {
                ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID)
            }
            DispatchQueue.main.async {
                guard requestID == reloadGeneration else { return }
                apps = preliminary
                isLoading = false
            }

            let launchServicesIdentifiers = ContainerStore.launchServicesStoreIdentifiers()
            let mhaIdentifiers = MHAIdentifierCatalog.identifiers(
                dynamic: dynamicIdentifiers,
                installed: apiApps.map(\.bundleID),
                research: ContainerStore.researchAppIdentifiers,
                custom: bundleMetadata.keys.sorted(),
                launchServices: launchServicesIdentifiers
            )
            log(
                "browser: MHA catalog dynamic=\(dynamicIdentifiers.count), " +
                "installed=\(apiApps.count), research=\(ContainerStore.researchAppIdentifiers.count), " +
                "LaunchServices=\(launchServicesIdentifiers.count) -> \(mhaIdentifiers.count) candidates"
            )

            let mhaApps = ContainerStore.installedAppsFromMHACandidates(
                identifiers: mhaIdentifiers,
                bundleMetadata: bundleMetadata
            ) { discoveredApps in
                var progressiveResult = AppDataCatalogMerger.merge(
                    identified: discoveredApps + baseIdentifiedApps,
                    fallback: [],
                    identifier: { $0.bundleID },
                    path: { $0.containerPath }
                )
                progressiveResult = progressiveResult.filter {
                    ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID)
                }
                progressiveResult.sort {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                DispatchQueue.main.async {
                    guard requestID == reloadGeneration else { return }
                    apps = progressiveResult
                }
            }

            let allKnownApps = mhaApps + baseIdentifiedApps
            let identifiedPaths = Set(allKnownApps.map {
                ContainerDiscoveryMerger.canonicalPath($0.containerPath)
            })
            let unmatchedFilesystemApps = filesystemApps.filter {
                !identifiedPaths.contains(ContainerDiscoveryMerger.canonicalPath($0.containerPath))
            }
            let inferredFilesystemApps = ContainerStore.inferUnidentifiedApps(
                in: unmatchedFilesystemApps,
                knownApps: allKnownApps,
                launchServicesIdentifiers: Set(launchServicesIdentifiers)
            ).filter {
                ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID)
            }
            result = AppDataCatalogMerger.merge(
                identified: allKnownApps,
                fallback: inferredFilesystemApps,
                identifier: { $0.bundleID },
                path: { $0.containerPath }
            )
            result = result.filter {
                ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID)
            }
            result.sort {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }

            DispatchQueue.main.async {
                guard requestID == reloadGeneration else { return }
                apps = result
                isLoading = false
                isResolving = false
                if result.isEmpty {
                    errorMessage = emptyMessage
                }
            }
        }
    }
}

private enum AppBrowserOverlayState: Equatable {
    case loading
    case empty
    case none
}

struct BrowserAppIcon: View {
    let app: InstalledApp
    @State private var resolvedIcon: UIImage?
    @State private var didRequestIcon = false

    init(app: InstalledApp) {
        self.app = app
        _resolvedIcon = State(initialValue: app.icon)
    }

    var body: some View {
        Group {
            if let resolvedIcon {
                Image(uiImage: resolvedIcon)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppTheme.accentSoft)
            }
        }
        .frame(width: AppTheme.appIconSize, height: AppTheme.appIconSize)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .accessibilityHidden(true)
        .onAppear {
            guard resolvedIcon == nil, !didRequestIcon else { return }
            didRequestIcon = true
            let bundleID = app.bundleID
            DispatchQueue.global(qos: .utility).async {
                let icon = iconForBundleID(bundleID)
                DispatchQueue.main.async {
                    resolvedIcon = icon
                }
            }
        }
    }
}
