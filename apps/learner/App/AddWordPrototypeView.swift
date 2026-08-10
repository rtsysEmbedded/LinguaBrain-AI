import SwiftUI
import UniformTypeIdentifiers

struct AddWordPrototypeView: View {
    @State private var word = "arbeiten"
    @State private var domain = "عمومی"
    @State private var showPreview = true
    @State private var isImporterPresented = false
    @State private var isInspectingPackage = false
    @State private var packagePreview: APKGImportPreview?
    @State private var packageError: String?

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

                packageImporter

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
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.ankiDeckPackage],
            allowsMultipleSelection: false
        ) { result in
            inspectSelectedPackage(result)
        }
        .alert("فایل Anki قابل بررسی نیست", isPresented: packageErrorBinding) {
            Button("باشه", role: .cancel) { packageError = nil }
        } message: {
            Text(packageError ?? "خطای ناشناخته")
        }
    }

    private var packageImporter: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("ورود فایل Anki", systemImage: "square.and.arrow.down")
                        .font(.headline)
                    Spacer()
                    Text("پیش‌بررسی امن")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PrototypeTheme.accent)
                }

                if isInspectingPackage {
                    ProgressView("در حال بررسی ساختار بسته…")
                } else if let packagePreview {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(packagePreview.fileName, systemImage: "checkmark.shield.fill")
                            .foregroundStyle(PrototypeTheme.mint)
                        Text("\(packagePreview.entryCount) فایل · \(packagePreview.mediaEntryCount) رسانه · دیتابیس: \(packagePreview.collectionName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("حجم بازشدهٔ اعلام‌شده: \(packagePreview.expandedBytes.formatted(.byteCount(style: .file)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("هنوز هیچ داده‌ای وارد LinguaBrain نشده است.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                } else {
                    Text("فایل قبل از استخراج از نظر مسیرهای خطرناک، رمزگذاری، تعداد فایل، حجم بازشده و نسبت فشرده‌سازی بررسی می‌شود.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    isImporterPresented = true
                } label: {
                    Label("انتخاب فایل .apkg", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isInspectingPackage)
            }
        }
    }

    private func inspectSelectedPackage(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            isInspectingPackage = true
            packagePreview = nil
            Task {
                do {
                    let preview = try await Task.detached(priority: .userInitiated) {
                        let hasAccess = url.startAccessingSecurityScopedResource()
                        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
                        return try APKGArchiveInspector().inspect(url: url)
                    }.value
                    packagePreview = preview
                } catch {
                    packageError = error.localizedDescription
                }
                isInspectingPackage = false
            }
        } catch {
            packageError = error.localizedDescription
        }
    }

    private var packageErrorBinding: Binding<Bool> {
        Binding(
            get: { packageError != nil },
            set: { if !$0 { packageError = nil } }
        )
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

private extension UTType {
    static let ankiDeckPackage = UTType(filenameExtension: "apkg") ?? .archive
}

struct APKGImportPreview: Sendable {
    let fileName: String
    let entryCount: Int
    let mediaEntryCount: Int
    let expandedBytes: Int64
    let collectionName: String
}

enum APKGInspectionError: LocalizedError {
    case fileTooLarge
    case malformedArchive
    case unsupportedZip64
    case tooManyEntries
    case unsafePath(String)
    case encryptedEntry(String)
    case unsupportedCompression(String)
    case expandedSizeExceeded
    case suspiciousCompressionRatio(String)
    case duplicateEntry(String)
    case missingCollection

    var errorDescription: String? {
        switch self {
        case .fileTooLarge: "حجم فایل از حد مجاز ۵۱۲ مگابایت بیشتر است."
        case .malformedArchive: "ساختار ZIP فایل معتبر نیست."
        case .unsupportedZip64: "بسته‌های ZIP64 فعلاً پشتیبانی نمی‌شوند."
        case .tooManyEntries: "تعداد فایل‌های داخل بسته از حد ایمن بیشتر است."
        case .unsafePath(let path): "مسیر ناامن داخل بسته پیدا شد: \(path)"
        case .encryptedEntry(let path): "فایل رمزگذاری‌شده پشتیبانی نمی‌شود: \(path)"
        case .unsupportedCompression(let path): "روش فشرده‌سازی این فایل پشتیبانی نمی‌شود: \(path)"
        case .expandedSizeExceeded: "حجم بازشدهٔ بسته از حد ایمن بیشتر است."
        case .suspiciousCompressionRatio(let path): "نسبت فشرده‌سازی مشکوک است: \(path)"
        case .duplicateEntry(let path): "نام تکراری داخل بسته پیدا شد: \(path)"
        case .missingCollection: "فایل دیتابیس Anki داخل بسته پیدا نشد."
        }
    }
}

struct APKGArchiveInspector: Sendable {
    private let maximumArchiveBytes: UInt64 = 512 * 1_024 * 1_024
    private let maximumExpandedBytes: UInt64 = 1_024 * 1_024 * 1_024
    private let maximumEntryBytes: UInt64 = 128 * 1_024 * 1_024
    private let maximumEntries = 10_000
    private let maximumCompressionRatio: UInt64 = 200

    func inspect(url: URL) throws -> APKGImportPreview {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let fileSize = try handle.seekToEnd()
        guard fileSize <= maximumArchiveBytes else { throw APKGInspectionError.fileTooLarge }

        let tailSize = min(fileSize, 65_557)
        try handle.seek(toOffset: fileSize - tailSize)
        guard let tail = try handle.read(upToCount: Int(tailSize)),
              let eocd = tail.lastIndex(ofLittleEndianUInt32: 0x06054B50),
              eocd + 22 <= tail.count else {
            throw APKGInspectionError.malformedArchive
        }

        let disk = tail.uint16LE(at: eocd + 4)
        let centralDisk = tail.uint16LE(at: eocd + 6)
        let entriesOnDisk = tail.uint16LE(at: eocd + 8)
        let entryCount = tail.uint16LE(at: eocd + 10)
        let centralSize = tail.uint32LE(at: eocd + 12)
        let centralOffset = tail.uint32LE(at: eocd + 16)
        guard disk == 0, centralDisk == 0, entriesOnDisk == entryCount else {
            throw APKGInspectionError.malformedArchive
        }
        guard entryCount != UInt16.max,
              centralSize != UInt32.max,
              centralOffset != UInt32.max else {
            throw APKGInspectionError.unsupportedZip64
        }
        guard Int(entryCount) <= maximumEntries else { throw APKGInspectionError.tooManyEntries }
        guard UInt64(centralOffset) + UInt64(centralSize) <= fileSize,
              centralSize <= 32 * 1_024 * 1_024 else {
            throw APKGInspectionError.malformedArchive
        }

        try handle.seek(toOffset: UInt64(centralOffset))
        guard let central = try handle.read(upToCount: Int(centralSize)), central.count == Int(centralSize) else {
            throw APKGInspectionError.malformedArchive
        }

        var cursor = 0
        var expandedBytes: UInt64 = 0
        var names = Set<String>()
        var collectionName: String?
        var mediaEntries = 0

        for _ in 0..<Int(entryCount) {
            guard cursor + 46 <= central.count,
                  central.uint32LE(at: cursor) == 0x02014B50 else {
                throw APKGInspectionError.malformedArchive
            }
            let flags = central.uint16LE(at: cursor + 8)
            let method = central.uint16LE(at: cursor + 10)
            let compressed = UInt64(central.uint32LE(at: cursor + 20))
            let expanded = UInt64(central.uint32LE(at: cursor + 24))
            let externalAttributes = central.uint32LE(at: cursor + 38)
            let nameLength = Int(central.uint16LE(at: cursor + 28))
            let extraLength = Int(central.uint16LE(at: cursor + 30))
            let commentLength = Int(central.uint16LE(at: cursor + 32))
            let end = cursor + 46 + nameLength + extraLength + commentLength
            guard nameLength > 0, end <= central.count,
                  let name = String(data: central.subdata(in: cursor + 46..<cursor + 46 + nameLength), encoding: .utf8) else {
                throw APKGInspectionError.malformedArchive
            }

            try validatePath(name)
            guard names.insert(name).inserted else { throw APKGInspectionError.duplicateEntry(name) }
            guard flags & 0x1 == 0 else { throw APKGInspectionError.encryptedEntry(name) }
            guard method == 0 || method == 8 else { throw APKGInspectionError.unsupportedCompression(name) }
            let unixFileType = (externalAttributes >> 16) & 0xF000
            guard unixFileType != 0xA000 else { throw APKGInspectionError.unsafePath(name) }
            guard expanded <= maximumEntryBytes else { throw APKGInspectionError.expandedSizeExceeded }
            expandedBytes += expanded
            guard expandedBytes <= maximumExpandedBytes else { throw APKGInspectionError.expandedSizeExceeded }
            if compressed == 0, expanded > 0 {
                throw APKGInspectionError.suspiciousCompressionRatio(name)
            }
            if compressed > 0, expanded / compressed > maximumCompressionRatio {
                throw APKGInspectionError.suspiciousCompressionRatio(name)
            }

            if ["collection.anki21b", "collection.anki21", "collection.anki2"].contains(name) {
                collectionName = preferredCollection(current: collectionName, candidate: name)
            } else if name == "media" || name.allSatisfy(\.isNumber) {
                mediaEntries += 1
            }
            cursor = end
        }

        guard cursor == central.count, let collectionName else {
            throw APKGInspectionError.missingCollection
        }
        return APKGImportPreview(
            fileName: url.lastPathComponent,
            entryCount: Int(entryCount),
            mediaEntryCount: mediaEntries,
            expandedBytes: Int64(expandedBytes),
            collectionName: collectionName
        )
    }

    private func validatePath(_ name: String) throws {
        let normalized = name.replacingOccurrences(of: "\\", with: "/")
        let components = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard !normalized.hasPrefix("/"),
              !normalized.hasPrefix("~"),
              !normalized.contains(":"),
              !components.contains(".."),
              !components.contains(".") else {
            throw APKGInspectionError.unsafePath(name)
        }
    }

    private func preferredCollection(current: String?, candidate: String) -> String {
        let priority = ["collection.anki2": 0, "collection.anki21": 1, "collection.anki21b": 2]
        guard let current else { return candidate }
        return (priority[candidate] ?? 0) > (priority[current] ?? 0) ? candidate : current
    }
}

private extension Data {
    func uint16LE(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }

    func uint32LE(at offset: Int) -> UInt32 {
        UInt32(self[offset])
            | UInt32(self[offset + 1]) << 8
            | UInt32(self[offset + 2]) << 16
            | UInt32(self[offset + 3]) << 24
    }

    func lastIndex(ofLittleEndianUInt32 value: UInt32) -> Int? {
        guard count >= 4 else { return nil }
        for index in stride(from: count - 4, through: 0, by: -1) {
            if uint32LE(at: index) == value { return index }
        }
        return nil
    }
}
