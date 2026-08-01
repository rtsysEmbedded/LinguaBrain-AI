import SwiftUI

struct LibraryPrototypeView: View {
    @State private var searchText = ""
    @State private var filter = "همه"

    private var filteredWords: [PrototypeWord] {
        PrototypeData.words.filter { word in
            let matchesSearch = searchText.isEmpty || word.german.localizedCaseInsensitiveContains(searchText) || word.persian.contains(searchText)
            let matchesFilter = filter == "همه" || (filter == "ضعیف" && word.strength < 0.5) || filter == word.level
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    MetricPill(value: "۱٬۲۴۸", label: "واژه", symbol: "textformat.abc", color: PrototypeTheme.accent)
                    MetricPill(value: "۳۲", label: "ضعیف", symbol: "exclamationmark.triangle.fill", color: .orange)
                    MetricPill(value: "۶۸٪", label: "فعال", symbol: "bolt.fill", color: PrototypeTheme.mint)
                }

                Picker("فیلتر", selection: $filter) {
                    ForEach(["همه", "ضعیف", "A1", "B1", "B2"], id: \.self) { Text($0) }
                }
                .pickerStyle(.segmented)

                LazyVStack(spacing: 12) {
                    ForEach(filteredWords) { word in
                        NavigationLink {
                            WordDetailPrototypeView(word: word)
                        } label: {
                            wordRow(word)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .background(PrototypeBackground())
        .navigationTitle("کتابخانه")
        .searchable(text: $searchText, prompt: "جست‌وجوی فارسی یا آلمانی")
    }

    private func wordRow(_ word: PrototypeWord) -> some View {
        PrototypeCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(PrototypeTheme.accent.opacity(0.11))
                    Text(word.level).font(.caption.bold()).foregroundStyle(PrototypeTheme.accent)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 4) {
                    GermanText(text: word.german, font: .headline)
                    Text(word.persian).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(word.partOfSpeech).font(.caption).foregroundStyle(.secondary)
                    ProgressView(value: word.strength).frame(width: 72).tint(word.strength < 0.5 ? .orange : PrototypeTheme.mint)
                }
                Image(systemName: "chevron.left").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}

struct WordDetailPrototypeView: View {
    let word: PrototypeWord

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                PrototypeCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(word.level)
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(PrototypeTheme.accent.opacity(0.12), in: Capsule())
                            Text(word.partOfSpeech).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button(action: {}) { Image(systemName: "speaker.wave.2.fill") }
                        }
                        GermanText(text: word.german, font: .largeTitle.weight(.bold))
                        Text(word.persian).font(.title3)
                    }
                }

                PrototypeCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("مثال").font(.headline)
                        GermanText(text: word.example, font: .title3)
                        Text(word.exampleTranslation).foregroundStyle(.secondary)
                    }
                }

                PrototypeCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("شبکه واژگان").font(.headline)
                        HStack {
                            ForEach(["Arbeit", "Arbeitsplatz", "Arbeitgeber"], id: \.self) { item in
                                Text(item)
                                    .font(.subheadline)
                                    .environment(\.layoutDirection, .leftToRight)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(PrototypeTheme.accent.opacity(0.1), in: Capsule())
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(PrototypeBackground())
        .navigationTitle(word.german)
    }
}
