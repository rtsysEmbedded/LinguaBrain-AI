import SwiftUI

@main
struct LinguaBrainPrototypeApp: App {
    var body: some Scene {
        WindowGroup {
            PrototypeRootView()
                .environment(\.layoutDirection, .rightToLeft)
                .tint(PrototypeTheme.accent)
        }
        #if os(macOS)
        .defaultSize(width: 1120, height: 760)
        #endif
    }
}
