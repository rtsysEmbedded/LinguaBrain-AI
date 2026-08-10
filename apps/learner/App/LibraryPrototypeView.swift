import SwiftUI

struct LibraryPrototypeView: View {
    @Environment(PrototypeStore.self) private var store
    @State private var searchText = ""
    @State private var filter = "همه"

    private var filteredWords: [PrototypeWord] {
        store.words.filter { word in
            let matchesSearch = searchText.isEmpty || word.german.localizedCaseInsensitiveContains(searchText) || word.persian.contains(searchText)
            let matchesFilter = filter == "همه" || (filter == "ضعیف" && store.reviewCount(for: word) > 0 && store.strength(for: word) < 0.5) || filter == word.level
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    MetricPill(value: "\(store.words.count)", label: "واژه", symbol: "textformat.abc", color: PrototypeTheme.accent)
                    MetricPill(value: "\(store.weakCount)", label: "ضعیف", symbol: "exclamationmark.triangle.fill", color: .orange)
                    MetricPill(value: "\(store.reviewedCount)", label: "مرور شده", symbol: "bolt.fill", color: PrototypeTheme.mint)
                }

                NavigationLink {
                    CardGalleryPrototypeView()
                } label: {
                    PrototypeCard {
                        HStack(spacing: 14) {
                            Image(systemName: "rectangle.on.rectangle.angled")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(PrototypeTheme.heroGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("گالری کارت‌های MVP")
                                    .font(.headline)
                                Text("۱۰ کارت پایه را پیش از نهایی‌کردن گرافیک بررسی کن")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.left")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)

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
                    ProgressView(value: store.strength(for: word))
                        .frame(width: 72)
                        .tint(store.strength(for: word) < 0.5 ? .orange : PrototypeTheme.mint)
                }
                Image(systemName: "chevron.left").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}

private enum MVPCardKind: String, CaseIterable, Identifiable {
    case word, noun, verb, recognition, reverseTranslation, cloze, listening, feedback, dailyPlan, mastery

    var id: Self { self }

    var title: String {
        switch self {
        case .word: "کارت واژه"
        case .noun: "کارت اسم"
        case .verb: "کارت فعل"
        case .recognition: "مرور تشخیصی"
        case .reverseTranslation: "ترجمهٔ معکوس"
        case .cloze: "جای‌خالی"
        case .listening: "شنیداری"
        case .feedback: "نتیجه و بازخورد"
        case .dailyPlan: "برنامهٔ امروز"
        case .mastery: "وضعیت یادگیری"
        }
    }

    var purpose: String {
        switch self {
        case .word: "معنی، تلفظ، مثال و زمینه"
        case .noun: "Artikel، جمع و کاربرد اسمی"
        case .verb: "صرف‌ها، Perfekt و الگوی کاربرد"
        case .recognition: "تشخیص معنی آلمانی به فارسی"
        case .reverseTranslation: "یادآوری فعال فارسی به آلمانی"
        case .cloze: "انتخاب واژه در بافت جمله"
        case .listening: "تشخیص واژه یا جمله از صدا"
        case .feedback: "خطای مشخص و فرصت اصلاح"
        case .dailyPlan: "ترکیب مرور، واژهٔ جدید و مهارت"
        case .mastery: "نمایش تسلط مستقل هر مهارت"
        }
    }

    var symbol: String {
        switch self {
        case .word: "textformat.abc"
        case .noun: "character.book.closed.fill"
        case .verb: "arrow.triangle.branch"
        case .recognition: "eye.fill"
        case .reverseTranslation: "arrow.left.arrow.right"
        case .cloze: "rectangle.and.pencil.and.ellipsis"
        case .listening: "ear.fill"
        case .feedback: "checkmark.bubble.fill"
        case .dailyPlan: "calendar.badge.clock"
        case .mastery: "chart.bar.fill"
        }
    }

    var color: Color {
        switch self {
        case .word, .recognition: PrototypeTheme.accent
        case .noun, .listening: PrototypeTheme.blue
        case .verb, .cloze: .orange
        case .reverseTranslation, .dailyPlan: PrototypeTheme.pink
        case .feedback, .mastery: PrototypeTheme.mint
        }
    }
}

struct CardGalleryPrototypeView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "حداقل کارت‌های نسخهٔ اول",
                    subtitle: "این گالری برای بررسی محتوا و تعامل است؛ رنگ و گرافیک هنوز نهایی نیست."
                )

                ForEach(MVPCardKind.allCases) { kind in
                    NavigationLink {
                        CardSpecPrototypeView(kind: kind)
                    } label: {
                        PrototypeCard {
                            HStack(spacing: 14) {
                                Image(systemName: kind.symbol)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(kind.color)
                                    .frame(width: 44, height: 44)
                                    .background(kind.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(kind.title).font(.headline)
                                    Text(kind.purpose).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.left").font(.caption.bold()).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(PrototypeBackground())
        .navigationTitle("گالری کارت‌ها")
    }
}

private struct CardSpecPrototypeView: View {
    let kind: MVPCardKind
    @State private var isRevealed = false
    @State private var selectedAnswer: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Label(kind.title, systemImage: kind.symbol)
                        .font(.headline)
                        .foregroundStyle(kind.color)
                    Spacer()
                    Text("نمونهٔ محتوایی")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.quaternary, in: Capsule())
                }

                preview

                PrototypeCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("هدف این کارت").font(.headline)
                        Text(kind.purpose).foregroundStyle(.secondary)
                        Text("در بازبینی، وضوح سؤال، اطلاعات ضروری، پاسخ مورد انتظار و بازخورد را بررسی می‌کنیم؛ تزئینات بصری بعداً نهایی می‌شوند.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(PrototypeBackground())
        .navigationTitle(kind.title)
    }

    @ViewBuilder
    private var preview: some View {
        switch kind {
        case .word:
            learningCard {
                cardHeader(level: "B1", type: "Adjektiv")
                GermanText(text: "zuverlässig", font: .largeTitle.weight(.bold))
                Text("قابل اعتماد").font(.title3)
                Divider()
                GermanText(text: "Sie ist eine sehr zuverlässige Kollegin.", font: .headline)
                Text("او همکار بسیار قابل اعتمادی است.").foregroundStyle(.secondary)
            }
        case .noun:
            learningCard {
                cardHeader(level: "B1", type: "Nomen")
                GermanText(text: "die Entscheidung", font: .largeTitle.weight(.bold))
                Text("تصمیم").font(.title3)
                Divider()
                factRow("Artikel", "die")
                factRow("Plural", "die Entscheidungen")
                factRow("ترکیب رایج", "eine Entscheidung treffen")
            }
        case .verb:
            learningCard {
                cardHeader(level: "A1", type: "Verb")
                GermanText(text: "arbeiten", font: .largeTitle.weight(.bold))
                Text("کار کردن").font(.title3)
                Divider()
                factRow("Präsens", "er arbeitet")
                factRow("Präteritum", "arbeitete")
                factRow("Perfekt", "hat gearbeitet")
            }
        case .recognition:
            questionCard(prompt: "arbeiten", instruction: "معنی این واژه چیست؟", answers: ["کار کردن", "خرید کردن", "منتظر ماندن"])
        case .reverseTranslation:
            learningCard {
                Text("واژهٔ آلمانی را به یاد بیاور").font(.subheadline).foregroundStyle(.secondary)
                Text("تصمیم گرفتن").font(.largeTitle.weight(.bold))
                Divider()
                Button(isRevealed ? "entscheiden" : "نمایش پاسخ") { isRevealed = true }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
        case .cloze:
            questionCard(prompt: "Ich ___ heute von zu Hause.", instruction: "جای خالی را کامل کن", answers: ["arbeite", "arbeitest", "arbeitet"])
        case .listening:
            learningCard {
                Text("گوش بده و پاسخ مناسب را انتخاب کن").font(.headline)
                Button(action: {}) {
                    Image(systemName: "play.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 74, height: 74)
                        .background(PrototypeTheme.blue.gradient, in: Circle())
                }
                .frame(maxWidth: .infinity)
                Text("پخش با سرعت عادی · امکان تکرار").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
        case .feedback:
            learningCard {
                Label("تقریباً درست بود", systemImage: "exclamationmark.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.orange)
                GermanText(text: "Ich arbeite heute.", font: .title2.weight(.semibold))
                Text("فعل درست بود؛ فقط صرف فعل باید با فاعل «ich» هماهنگ شود.").foregroundStyle(.secondary)
                Button("یک‌بار دیگر امتحان کن") { }.buttonStyle(.borderedProminent)
            }
        case .dailyPlan:
            learningCard {
                Text("برنامهٔ امروز · ۲۰ دقیقه").font(.title2.weight(.bold))
                planRow("مرور نزدیک فراموشی", "۸ دقیقه", "arrow.clockwise", PrototypeTheme.accent)
                planRow("۵ واژهٔ جدید", "۵ دقیقه", "plus.circle.fill", PrototypeTheme.pink)
                planRow("شنیداری محیط کار", "۷ دقیقه", "ear.fill", PrototypeTheme.blue)
                Button("شروع جلسه") { }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
            }
        case .mastery:
            learningCard {
                GermanText(text: "arbeiten", font: .title.weight(.bold))
                SkillProgressRow(label: "تشخیص", value: 0.92, color: PrototypeTheme.mint)
                SkillProgressRow(label: "یادآوری", value: 0.68, color: PrototypeTheme.accent)
                SkillProgressRow(label: "شنیداری", value: 0.54, color: PrototypeTheme.blue)
                SkillProgressRow(label: "تولید", value: 0.36, color: .orange)
            }
        }
    }

    private func learningCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 14, content: content)
        }
    }

    private func cardHeader(level: String, type: String) -> some View {
        HStack {
            Text(level).font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 5).background(kind.color.opacity(0.12), in: Capsule())
            Text(type).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button(action: {}) { Image(systemName: "speaker.wave.2.fill") }
        }
    }

    private func factRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).environment(\.layoutDirection, .leftToRight)
        }
    }

    private func questionCard(prompt: String, instruction: String, answers: [String]) -> some View {
        learningCard {
            Text(instruction).font(.subheadline).foregroundStyle(.secondary)
            GermanText(text: prompt, font: .title.weight(.bold))
            Divider()
            ForEach(answers, id: \.self) { answer in
                Button {
                    selectedAnswer = answer
                } label: {
                    HStack {
                        Text(answer)
                        Spacer()
                        Image(systemName: selectedAnswer == answer ? "checkmark.circle.fill" : "circle")
                    }
                    .padding(12)
                    .background(selectedAnswer == answer ? kind.color.opacity(0.12) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func planRow(_ title: String, _ duration: String, _ symbol: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 30)
            Text(title)
            Spacer()
            Text(duration).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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
