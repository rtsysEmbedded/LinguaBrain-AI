import SwiftUI

struct PrototypeRootView: View {
    @State private var selection: PrototypeSection = .today

    var body: some View {
        #if os(macOS)
        desktopLayout
        #else
        mobileLayout
        #endif
    }

    #if os(macOS)
    private var desktopLayout: some View {
        NavigationSplitView {
            List(PrototypeSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbol)
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
                        Text("سعید").font(.subheadline.weight(.semibold))
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
                    Label(section.title, systemImage: section.symbol)
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
        case .settings:
            SettingsPrototypeView()
        }
    }
}

#Preview("Prototype Root") {
    PrototypeRootView()
        .environment(\.layoutDirection, .rightToLeft)
        .tint(PrototypeTheme.accent)
}
