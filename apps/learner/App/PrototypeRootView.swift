import SwiftUI
import LinguaBrainApplication
import LinguaBrainPersistence

struct PrototypeRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: PrototypeSection = .today
    @State private var store: PrototypeStore
    @State private var aiSettings = PrototypeAISettings()
    @State private var cloudBackup = PrototypeCloudBackupController()
    @State private var practiceCutover: PracticeCutoverCoordinator
    @State private var practiceComposition: PracticeComposition?
    @State private var localization: PrototypeLocalization
    @State private var languageSettings: PrototypeLanguageSettings

    init(
        store: PrototypeStore = PrototypeStore(),
        practiceCutover: PracticeCutoverCoordinator = PracticeCutoverCoordinator(
            repositoryBuilder: { try GRDBPracticeRepository(url: $0) }
        ),
        practiceComposition: PracticeComposition? = nil,
        localization: PrototypeLocalization = PrototypeLocalization(),
        languageSettings: PrototypeLanguageSettings = PrototypeLanguageSettings()
    ) {
        _store = State(initialValue: store)
        _practiceCutover = State(initialValue: practiceCutover)
        _practiceComposition = State(initialValue: practiceComposition)
        _localization = State(initialValue: localization)
        _languageSettings = State(initialValue: languageSettings)
    }

    var body: some View {
        Group {
            if practiceCutover.state.isActive {
                #if os(macOS)
                desktopLayout
                #else
                mobileLayout
                #endif
            } else {
                PracticeCutoverStatusView(coordinator: practiceCutover)
            }
        }
        .environment(store)
        .environment(practiceCutover)
        .environment(aiSettings)
        .environment(cloudBackup)
        .environment(localization)
        .environment(languageSettings)
        .environment(\.locale, localization.language.locale)
        .environment(\.layoutDirection, localization.language.layoutDirection)
        .task { await cloudBackup.syncIfEnabled(store: store) }
        .task {
            await practiceCutover.start()
            if practiceCutover.state.isActive {
                if practiceComposition == nil, let repository = practiceCutover.repository {
                    // This is an explicit composition choice, not a hidden
                    // fallback: no provider adapter is enabled in T009, so
                    // the capability reports unavailable until a later task.
                    practiceComposition = PracticeComposition(
                        repository: repository,
                        evaluator: UnavailablePracticeEvaluator(),
                        clock: SystemPracticeClock(),
                        scheduler: PracticeFSRS6Scheduler()
                    )
                }
            }
        }
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
            .navigationTitle(localization.localized("app.name"))
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
                        Text(localization.localized("root.profile.placeholderName")).font(.subheadline.weight(.semibold))
                        Text(localization.localized("root.profile.placeholderLevel")).font(.caption).foregroundStyle(.secondary)
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
            TodayPrototypeView(practiceComposition: practiceComposition)
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

private struct PracticeCutoverStatusView: View {
    @Bindable var coordinator: PracticeCutoverCoordinator
    @Environment(PrototypeLocalization.self) private var localization

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(title)
                .font(.headline)
            Text(detail)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if case let .migrating(completed, total) = coordinator.state {
                ProgressView(value: Double(completed), total: Double(max(total, 1)))
                    .frame(maxWidth: 320)
            }
            if case let .recoverableFailure(failure) = coordinator.state {
                VStack(spacing: 10) {
                    Text(localization.localized(failure.recoveryGuidanceKey))
                        .font(.callout)
                        .multilineTextAlignment(.center)
                    Button(localization.localized("common.retry")) {
                        Task { await coordinator.retry() }
                    }
                    if coordinator.backupReceipt != nil, !coordinator.legacySourceExists {
                        Button(localization.localized("cutover.restoreBackup")) {
                            try? coordinator.restoreBackup()
                        }
                    } else if coordinator.backupReceipt != nil {
                        Text(localization.localized("cutover.sourceIntact"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(32)
    }

    private var stateKey: String {
        switch coordinator.state {
        case .notStarted: "notStarted"
        case .backingUp: "backingUp"
        case .readingLegacy: "readingLegacy"
        case .migrating: "migrating"
        case .validating: "validating"
        case .active: "active"
        case .recoverableFailure: "recoverableFailure"
        }
    }

    private var title: String {
        localization.localized("cutover.title.\(stateKey)")
    }

    private var detail: String {
        coordinator.state == .active ? "" : localization.localized("cutover.detail.\(stateKey)")
    }
}

#Preview("Prototype Root") {
    PrototypeRootView(store: PrototypeStore(inMemory: true))
        .tint(PrototypeTheme.accent)
}
