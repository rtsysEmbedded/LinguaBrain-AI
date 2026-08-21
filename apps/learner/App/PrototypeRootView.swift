import SwiftUI

struct PrototypeRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: PrototypeSection = .today
    @State private var store: PrototypeStore
    @State private var aiSettings = PrototypeAISettings()
    @State private var cloudBackup = PrototypeCloudBackupController()
    @State private var localization: PrototypeLocalization
    @State private var languageSettings: PrototypeLanguageSettings

    init(
        store: PrototypeStore = PrototypeStore(),
        localization: PrototypeLocalization = PrototypeLocalization(),
        languageSettings: PrototypeLanguageSettings = PrototypeLanguageSettings()
    ) {
        _store = State(initialValue: store)
        _localization = State(initialValue: localization)
        _languageSettings = State(initialValue: languageSettings)
    }

    var body: some View {
        Group {
            #if os(macOS)
            desktopLayout
            #else
            mobileLayout
            #endif
        }
        .environment(store)
        .environment(aiSettings)
        .environment(cloudBackup)
        .environment(localization)
        .environment(languageSettings)
        .environment(\.locale, localization.language.locale)
        .environment(\.layoutDirection, localization.language.layoutDirection)
        .task { await cloudBackup.syncIfEnabled(store: store) }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await cloudBackup.syncIfEnabled(store: store) }
        }
    }

    #if os(macOS)
    private var desktopLayout: some View {
        NavigationSplitView {
            List(PrototypeSection.allCases, selection: $selection) { section in
                Label(section.title(for: localization.language), systemImage: section.symbol)
                    .tag(section)
                    .padding(.vertical, 4)
            }
            .navigationTitle("LinguaBrain")
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(PrototypeTheme.heroGradient)
                        .frame(width: 34, height: 34)
                        .overlay {
                            Image(systemName: "brain.head.profile.fill")
                                .foregroundStyle(.white)
                        }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Saeid").font(.subheadline.weight(.semibold))
                        Text("Deutsch · B1").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
            }
        } detail: {
            NavigationStack {
                destination(for: selection)
            }
        }
    }
    #endif

    private var mobileLayout: some View {
        TabView(selection: $selection) {
            ForEach(PrototypeSection.allCases) { section in
                NavigationStack {
                    destination(for: section)
                }
                .tabItem {
                    Label(section.title(for: localization.language), systemImage: section.symbol)
                }
                .tag(section)
            }
        }
    }

    @ViewBuilder
    private func destination(for section: PrototypeSection) -> some View {
        switch section {
        case .today:
            TodayPrototypeView()
        case .library:
            LibraryPrototypeView()
        case .add:
            AddWordPrototypeView()
        case .progress:
            ProgressPrototypeView()
        case .utilities:
            UtilitiesPrototypeView()
        case .settings:
            SettingsPrototypeView()
        }
    }
}

#Preview("Prototype Root") {
    PrototypeRootView(store: PrototypeStore(inMemory: true))
        .tint(PrototypeTheme.accent)
}
