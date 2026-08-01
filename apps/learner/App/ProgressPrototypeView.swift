import SwiftUI

struct ProgressPrototypeView: View {
    private let week = [18, 24, 10, 32, 28, 42, 35]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summary
                weeklyActivity
                skills
                insight
            }
            .padding()
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .background(PrototypeBackground())
        .navigationTitle("پیشرفت")
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("رشد این ماه").font(.title2.bold()).foregroundStyle(.white)
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("+۱۲۸").font(.largeTitle.bold())
                    Text("واژه فعال").font(.caption).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("۸۴٪").font(.largeTitle.bold())
                    Text("نرخ یادآوری").font(.caption).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("۷ روز").font(.largeTitle.bold())
                    Text("پیوستگی").font(.caption).foregroundStyle(.white.opacity(0.8))
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
                SkillProgressRow(label: "تشخیص واژه", value: 0.86, color: PrototypeTheme.mint)
                SkillProgressRow(label: "یادآوری فعال", value: 0.64, color: PrototypeTheme.accent)
                SkillProgressRow(label: "شنیداری", value: 0.48, color: PrototypeTheme.pink)
                SkillProgressRow(label: "نوشتن", value: 0.58, color: PrototypeTheme.blue)
                SkillProgressRow(label: "استفاده در جمله", value: 0.41, color: .orange)
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
                    Text("واژه‌ها را هنگام خواندن خوب می‌شناسی، اما برای استفاده در مکالمه به تمرین Recall بیشتری نیاز داری.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
