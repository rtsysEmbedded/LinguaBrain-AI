import SwiftUI

struct ProgressPrototypeView: View {
    @Environment(PrototypeStore.self) private var store
    @State private var isResetConfirmationPresented = false
    @State private var persistenceError: String?

    private var week: [Int] { [0, 0, 0, 0, 0, 0, min(store.totalReviews, 50)] }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summary
                weeklyActivity
                skills
                insight
                resetControl
            }
            .padding()
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .background(PrototypeBackground())
        .navigationTitle("پیشرفت")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("ریست وضعیت", systemImage: "arrow.counterclockwise") {
                    isResetConfirmationPresented = true
                }
            }
        }
        .confirmationDialog(
            "همهٔ سابقه‌های مرور پاک شوند؟",
            isPresented: $isResetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("پاک‌کردن کامل سابقه", role: .destructive) {
                resetProgress()
            }
            Button("انصراف", role: .cancel) {}
        } message: {
            Text("این کار ۵۰ واژه را به حالت اولیه برمی‌گرداند و قابل بازگشت نیست.")
        }
        .alert("خطای ذخیره‌سازی", isPresented: persistenceErrorBinding) {
            Button("باشه", role: .cancel) {
                persistenceError = nil
                store.clearPersistenceError()
            }
        } message: {
            Text(persistenceError ?? "خطای ناشناخته")
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("رشد این ماه").font(.title2.bold()).foregroundStyle(.white)
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("\(store.reviewedCount)").font(.largeTitle.bold())
                    Text("واژه مرورشده").font(.caption).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text(store.averageStrength.formatted(.percent.precision(.fractionLength(0)))).font(.largeTitle.bold())
                    Text("قدرت میانگین").font(.caption).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("\(store.totalReviews)").font(.largeTitle.bold())
                    Text("کل پاسخ‌ها").font(.caption).foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding(22)
        .foregroundStyle(.white)
        .background(PrototypeTheme.heroGradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var weeklyActivity: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "فعالیت هفتگی", subtitle: "دقیقه مطالعه در هر روز")
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(Array(week.enumerated()), id: \.offset) { index, value in
                        VStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(index == 5 ? PrototypeTheme.heroGradient : LinearGradient(colors: [PrototypeTheme.accent.opacity(0.36)], startPoint: .top, endPoint: .bottom))
                                .frame(height: CGFloat(value) * 2.2)
                            Text(["ش", "ی", "د", "س", "چ", "پ", "ج"][index])
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 120, alignment: .bottom)
            }
        }
    }

    private var skills: some View {
        PrototypeCard {
            VStack(spacing: 17) {
                SectionHeader(title: "نقشه مهارت‌ها", subtitle: "تسلط واقعی، نه فقط تعداد واژه‌ها")
                SkillProgressRow(label: "تشخیص واژه", value: store.averageStrength, color: PrototypeTheme.mint)
                SkillProgressRow(label: "یادآوری فعال", value: store.averageStrength * 0.72, color: PrototypeTheme.accent)
                SkillProgressRow(label: "شنیداری", value: 0, color: PrototypeTheme.pink)
                SkillProgressRow(label: "نوشتن", value: 0, color: PrototypeTheme.blue)
                SkillProgressRow(label: "استفاده در جمله", value: 0, color: .orange)
            }
        }
    }

    private var insight: some View {
        PrototypeCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "lightbulb.max.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 5) {
                    Text("بینش این هفته").font(.headline)
                    Text(store.reviewedCount == 0 ? "هنوز هیچ داده‌ای ثبت نشده است. پس از مرور، این بخش باید تغییر کند." : "داده‌های فعلی از \(store.totalReviews) پاسخ روی \(store.reviewedCount) واژه ساخته شده‌اند؛ شنیداری و نوشتن هنوز داده ندارند.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var resetControl: some View {
        PrototypeCard {
            HStack(spacing: 14) {
                Image(systemName: "testtube.2")
                    .font(.title2)
                    .foregroundStyle(PrototypeTheme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("حالت آزمایش عملکرد").font(.headline)
                    Text("همهٔ ۵۰ واژه را به وضعیت اولیه و بدون مرور برگردان.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("ریست") {
                    isResetConfirmationPresented = true
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }

    private func resetProgress() {
        guard store.reset() else {
            persistenceError = store.lastPersistenceError
            return
        }
    }

    private var persistenceErrorBinding: Binding<Bool> {
        Binding(
            get: { persistenceError != nil },
            set: { if !$0 { persistenceError = nil } }
        )
    }
}
