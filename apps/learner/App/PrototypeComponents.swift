import SwiftUI

struct PrototypeCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.primary.opacity(0.07), lineWidth: 1)
            }
    }
}

struct SectionHeader: View {
    @Environment(PrototypeLocalization.self) private var localization
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(localization.localized(title))
                .font(.title3.weight(.bold))
            if let subtitle {
                Text(localization.localized(subtitle))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MetricPill: View {
    @Environment(PrototypeLocalization.self) private var localization
    let value: String
    let label: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(localization.localized(value)).font(.headline)
                Text(localization.localized(label))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.background.opacity(0.74), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct GermanText: View {
    let text: String
    var font: Font = .body
    var color: Color = .primary

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .environment(\.layoutDirection, .leftToRight)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LanguageText: View {
    let text: String
    let languageTag: String
    var font: Font = .body
    var color: Color = .primary

    private var direction: LayoutDirection {
        languageTag == "fa" ? .rightToLeft : .leftToRight
    }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .environment(\.layoutDirection, direction)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SkillProgressRow: View {
    @Environment(PrototypeLocalization.self) private var localization
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(localization.localized(label)).font(.subheadline.weight(.medium))
                Spacer()
                Text(value, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: value)
                .tint(color)
        }
    }
}

struct PrototypeBackground: View {
    var body: some View {
        LinearGradient(
            colors: [PrototypeTheme.accent.opacity(0.09), PrototypeTheme.pink.opacity(0.04), Color.clear],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
        .ignoresSafeArea()
    }
}
