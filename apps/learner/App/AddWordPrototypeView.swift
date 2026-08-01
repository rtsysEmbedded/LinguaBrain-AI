import SwiftUI

struct AddWordPrototypeView: View {
    @State private var word = "arbeiten"
    @State private var domain = "عمومی"
    @State private var showPreview = true

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("یک واژه اضافه کن")
                        .font(.largeTitle.bold())
                    Text("نمونه کارت با داده Mock ساخته شده و هنوز به AI متصل نیست.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                PrototypeCard {
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("واژه یا عبارت آلمانی", text: $word)
                            .textFieldStyle(.roundedBorder)
                            .font(.title3)
                            .environment(\.layoutDirection, .leftToRight)

                        Picker("حوزه", selection: $domain) {
                            Text("عمومی").tag("عمومی")
                            Text("محیط کار").tag("محیط کار")
                            Text("نرم‌افزار").tag("نرم‌افزار")
                            Text("پزشکی").tag("پزشکی")
                        }
                        .pickerStyle(.segmented)

                        Button {
                            withAnimation { showPreview = true }
                        } label: {
                            Label("ساخت پیش‌نمایش کارت", systemImage: "wand.and.stars")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if showPreview {
                    cardPreview
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(PrototypeBackground())
        .navigationTitle("افزودن")
    }

    private var cardPreview: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label("پیشنهاد آماده بررسی", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PrototypeTheme.mint)
                    Spacer()
                    Text("A1 · Verb").font(.caption).foregroundStyle(.secondary)
                }
                GermanText(text: word.isEmpty ? "arbeiten" : word, font: .largeTitle.bold())
                Text("کار کردن").font(.title2)
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("مثال").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    GermanText(text: "Ich arbeite heute von zu Hause.", font: .title3)
                    Text("من امروز از خانه کار می‌کنم.").foregroundStyle(.secondary)
                }
                HStack {
                    Label("Verben", systemImage: "square.stack.3d.up.fill")
                    Label("A1", systemImage: "graduationcap.fill")
                    Label(domain, systemImage: "tag.fill")
                }
                .font(.caption)
                .foregroundStyle(PrototypeTheme.accent)
                Button(action: {}) {
                    Label("تأیید و افزودن", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
