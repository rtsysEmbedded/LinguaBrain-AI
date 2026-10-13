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
                    Text(failure.recoveryGuidance)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await coordinator.retry() }
                    }
                    if coordinator.backupReceipt != nil, !coordinator.legacySourceExists {
                        Button("Restore retained backup") {
                            try? coordinator.restoreBackup()
                        }
                    } else if coordinator.backupReceipt != nil {
                        Text("The retained legacy source is intact; restore is not needed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(32)
    }

    private var title: String {
        switch coordinator.state {
        case .notStarted: "Preparing practice storage"
        case .backingUp: "Backing up learning history"
        case .readingLegacy: "Reading legacy learning history"
        case .migrating: "Migrating learning history"
        case .validating: "Validating migrated learning history"
        case .active: "Practice storage ready"
        case .recoverableFailure: "Practice storage needs recovery"
        }
    }

    private var detail: String {
        switch coordinator.state {
        case .notStarted: "The existing learning store remains unchanged until preparation completes."
        case .backingUp: "A recoverable copy is being created before migration starts."
        case .readingLegacy: "The existing store is opened read-only."
        case .migrating: "The migration can resume safely if the app is interrupted."
        case .validating: "Counts, identities, references, and representative content are being checked."
        case .active: ""
        case .recoverableFailure: "No new practice data has been activated."
        }
    }
}

#Preview("Prototype Root") {
    PrototypeRootView(store: PrototypeStore(inMemory: true))
        .tint(PrototypeTheme.accent)
}
