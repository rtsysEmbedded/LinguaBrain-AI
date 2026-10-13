import SwiftUI
import LinguaBrainPersistence

@main
struct LinguaBrainPrototypeApp: App {
    @State private var practiceCutover = PracticeCutoverCoordinator(
        repositoryBuilder: { try GRDBPracticeRepository(url: $0) }
    )

    var body: some Scene {
        WindowGroup {
            PrototypeRootView(practiceCutover: practiceCutover)
                .tint(PrototypeTheme.accent)
        }
        #if os(macOS)
        .defaultSize(width: 1120, height: 760)
        #endif
    }
}
