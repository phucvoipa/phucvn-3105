import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @State private var tabNavigation: AppTabNavigationState
    @State private var activeUtilitySheet: RootUtilitySheet?

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-installed-tab")
            || arguments.contains("--simulate-patch-tab") {
            initialTab = AppSection.installed.rawValue
        } else if arguments.contains("--simulate-files-tab") {
            initialTab = AppSection.files.rawValue
        } else {
            initialTab = AppSection.home.rawValue
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
        _activeUtilitySheet = State(
            initialValue: arguments.contains("--simulate-settings") ? .settings : nil
        )
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
        _activeUtilitySheet = State(initialValue: nil)
#endif
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .tint(AppTheme.accent)
        .preferredColorScheme(.dark)
        .imageScale(.medium)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { selectSection(AppSection.installed.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { selectSection(AppSection.installed.rawValue) }
        }
        .onAppear {
            var updatedNavigation = tabNavigation
            updatedNavigation.reconcileSelection(with: featureVisibility)
            tabNavigation = updatedNavigation
        }
        .sheet(item: $activeUtilitySheet) { sheet in
            switch sheet {
            case .settings:
                SettingsView()
            case .logs:
                LogView()
            }
        }
    }

    private var compactLayout: some View {
        ZStack {
            AppPageBackground()
            ForEach(featureVisibility.visibleSections) { section in
                sectionContent(section)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(selectedVisibleSection == section ? 1 : 0)
                    .allowsHitTesting(selectedVisibleSection == section)
                    .accessibilityHidden(selectedVisibleSection != section)
                    .zIndex(selectedVisibleSection == section ? 1 : 0)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StudioTabBar(
                sections: featureVisibility.visibleSections,
                selectedTab: tabSelection
            )
        }
        .patchStorePresentation(patchStore)
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectSection(section.rawValue)
                        }
                    } label: {
                        Label(language.text(section.titleKey), systemImage: section.systemImage)
                            .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        section.rawValue == tabNavigation.selectedTab
                            ? AppTheme.accent.opacity(0.14)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        section.rawValue == tabNavigation.selectedTab ? .isSelected : []
                    )
                }
            }
            .navigationTitle(AppBrand.name)
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            sectionContent(selectedVisibleSection)
                .id(selectedVisibleSection.rawValue)
        }
        .navigationSplitViewStyle(.balanced)
        .patchStorePresentation(patchStore)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            HomeDashboardView(
                isActive: selectedVisibleSection == .home,
                onSelectSection: { selectSection($0.rawValue) },
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .installed:
            PatchProjectsView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .files:
            AppDataBrowserView(
                tabSession: filesTabSession,
                isActive: selectedVisibleSection == .files,
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { selectSection($0) }
        )
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { newSession in
                var updatedNavigation = tabNavigation
                updatedNavigation.setFilesTabs(newSession)
                tabNavigation = updatedNavigation
            }
        )
    }

    private func selectSection(_ newSelection: Int) {
        var updatedNavigation = tabNavigation
        updatedNavigation.select(newSelection)
        tabNavigation = updatedNavigation
    }

    private var featureVisibility: FeatureVisibility { FeatureVisibility() }

    private var selectedVisibleSection: AppSection {
        let selected = AppSection(rawValue: tabNavigation.selectedTab)
        return selected.flatMap {
            featureVisibility.isVisible($0) ? $0 : nil
        } ?? .home
    }

    private func openSettings() {
        activeUtilitySheet = .settings
    }

    private func openLogs() {
        activeUtilitySheet = .logs
    }
}

private enum RootUtilitySheet: String, Identifiable {
    case settings
    case logs

    var id: String { rawValue }
}

private struct StudioTabBar: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace
    let sections: [AppSection]
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(sections) { section in
                let isSelected = selectedTab == section.rawValue
                Button {
                    guard !isSelected else { return }
                    if reduceMotion {
                        selectedTab = section.rawValue
                    } else {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            selectedTab = section.rawValue
                        }
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: section.systemImage)
                            .font(.system(size: 17, weight: isSelected ? .bold : .medium))
                            .symbolRenderingMode(.hierarchical)
                            .scaleEffect(isSelected ? 1.04 : 1)
                        Text(language.text(section.titleKey))
                            .font(.system(size: 9, weight: isSelected ? .bold : .medium, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(isSelected ? AppTheme.pageBackground : AppTheme.subduedText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white, AppTheme.accent, AppTheme.accentSoft],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.58), lineWidth: 0.8)
                                }
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(AppPressableStyle())
                .accessibilityLabel(language.text(section.titleKey))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(AppTheme.consoleBackground.opacity(0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
        }
        .padding(.horizontal, 15)
        .padding(.top, 8)
        .padding(.bottom, 5)
        .background {
            LinearGradient(
                colors: [AppTheme.pageBackground.opacity(0), AppTheme.pageBackground.opacity(0.97)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }
}
