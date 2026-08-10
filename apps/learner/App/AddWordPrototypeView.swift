import SwiftUI
import UniformTypeIdentifiers
import SQLite3
import zlib

struct AddWordPrototypeView: View {
    @Environment(PrototypeStore.self) private var store
    @State private var word = "arbeiten"
    @State private var domain = "عمومی"
    @State private var showPreview = true
    @State private var isImporterPresented = false
    @State private var isInspectingPackage = false
    @State private var packagePreview: APKGImportPreview?
    @State private var packageError: String?
    @State private var isImportingPackage = false
    @State private var importResult: PrototypeImportResult?

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
                        if let importResult {
                            Label("\(importResult.addedCount) جدید · \(importResult.updatedCount) اصلاح‌شده · \(importResult.skippedCount) تکراری", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PrototypeTheme.mint)
                        } else {
                            Text("فایل آماده است؛ برای ثبت کارت‌ها دکمهٔ ورود را بزن.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
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
                .disabled(isInspectingPackage || isImportingPackage)

                if let packagePreview, importResult == nil {
                    Button {
                        importPackage(packagePreview)
                    } label: {
                        if isImportingPackage {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("تأیید و ورود به LinguaBrain", systemImage: "square.and.arrow.down.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isImportingPackage)
                }
            }
        }
    }

    private func inspectSelectedPackage(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            if let previousURL = packagePreview?.stagedPackageURL {
                try? FileManager.default.removeItem(at: previousURL)
            }
            isInspectingPackage = true
            packagePreview = nil
            importResult = nil
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

    private func importPackage(_ preview: APKGImportPreview) {
        isImportingPackage = true
        Task {
            do {
                let candidates = try await Task.detached(priority: .userInitiated) {
                    try APKGCardReader().readCards(from: preview)
                }.value
                guard let result = store.importCards(
                    candidates,
                    deckName: preview.deckName,
                    sourcePackage: preview.fileName
                ) else {
                    throw APKGImportError.databaseWriteFailed(store.lastPersistenceError ?? "خطای ناشناخته")
                }
                importResult = result
                try? FileManager.default.removeItem(at: preview.stagedPackageURL)
            } catch {
                packageError = error.localizedDescription
            }
            isImportingPackage = false
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
    let stagedPackageURL: URL
    let collectionEntry: APKGCollectionEntry

    var deckName: String {
        URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
    }
}

struct APKGCollectionEntry: Sendable {
    let name: String
    let compressionMethod: UInt16
    let compressedSize: Int
    let expandedSize: Int
    let localHeaderOffset: UInt64
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
        var collectionEntry: APKGCollectionEntry?
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
            let localHeaderOffset = UInt64(central.uint32LE(at: cursor + 42))
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
                let preferred = preferredCollection(current: collectionName, candidate: name)
                if preferred != collectionName {
                    collectionName = preferred
                    collectionEntry = APKGCollectionEntry(
                        name: name,
                        compressionMethod: method,
                        compressedSize: Int(compressed),
                        expandedSize: Int(expanded),
                        localHeaderOffset: localHeaderOffset
                    )
                }
            } else if name == "media" || name.allSatisfy(\.isNumber) {
                mediaEntries += 1
            }
            cursor = end
        }

        guard cursor == central.count, let collectionName, let collectionEntry else {
            throw APKGInspectionError.missingCollection
        }
        let stagingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LinguaBrain-APKG", isDirectory: true)
        try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        let stagedURL = stagingDirectory.appendingPathComponent("\(UUID().uuidString).apkg")
        try FileManager.default.copyItem(at: url, to: stagedURL)
        return APKGImportPreview(
            fileName: url.lastPathComponent,
            entryCount: Int(entryCount),
            mediaEntryCount: mediaEntries,
            expandedBytes: Int64(expandedBytes),
            collectionName: collectionName,
            stagedPackageURL: stagedURL,
            collectionEntry: collectionEntry
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

enum APKGImportError: LocalizedError {
    case unsupportedModernCollection
    case malformedCollection
    case noCards
    case databaseOpenFailed
    case databaseQueryFailed(String)
    case databaseWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedModernCollection:
            "این بسته از فرمت جدید collection.anki21b استفاده می‌کند که هنوز پشتیبانی نمی‌شود. خروجی سازگار collection.anki21 یا collection.anki2 را وارد کن."
        case .malformedCollection: "دیتابیس داخل بسته معتبر نیست."
        case .noCards: "هیچ کارت قابل ورود در فایل پیدا نشد."
        case .databaseOpenFailed: "دیتابیس Anki به‌صورت امن باز نشد."
        case .databaseQueryFailed(let message): "خواندن کارت‌های Anki انجام نشد: \(message)"
        case .databaseWriteFailed(let message): message
        }
    }
}

struct APKGCardReader: Sendable {
    private let maximumCards = 100_000

    func readCards(from preview: APKGImportPreview) throws -> [PrototypeImportedCard] {
        guard preview.collectionName != "collection.anki21b" else {
            throw APKGImportError.unsupportedModernCollection
        }
        let databaseURL = try extractCollection(from: preview)
        defer { try? FileManager.default.removeItem(at: databaseURL) }
        return try readSQLiteCards(at: databaseURL, packageName: preview.fileName)
    }

    private func extractCollection(from preview: APKGImportPreview) throws -> URL {
        let handle = try FileHandle(forReadingFrom: preview.stagedPackageURL)
        defer { try? handle.close() }
        let entry = preview.collectionEntry
        try handle.seek(toOffset: entry.localHeaderOffset)
        guard let header = try handle.read(upToCount: 30), header.count == 30,
              header.uint32LE(at: 0) == 0x04034B50 else {
            throw APKGImportError.malformedCollection
        }
        let nameLength = Int(header.uint16LE(at: 26))
        let extraLength = Int(header.uint16LE(at: 28))
        try handle.seek(toOffset: entry.localHeaderOffset + UInt64(30 + nameLength + extraLength))
        guard let compressed = try handle.read(upToCount: entry.compressedSize),
              compressed.count == entry.compressedSize else {
            throw APKGImportError.malformedCollection
        }

        let database: Data
        switch entry.compressionMethod {
        case 0: database = compressed
        case 8: database = try inflateRaw(compressed, expandedSize: entry.expandedSize)
        default: throw APKGImportError.malformedCollection
        }
        guard database.count == entry.expandedSize,
              database.starts(with: Data("SQLite format 3\0".utf8)) else {
            throw APKGImportError.malformedCollection
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LinguaBrain-\(UUID().uuidString).sqlite")
        try database.write(to: url, options: .atomic)
        return url
    }

    private func inflateRaw(_ input: Data, expandedSize: Int) throws -> Data {
        var output = Data(count: expandedSize)
        let status: Int32 = input.withUnsafeBytes { inputBuffer in
            output.withUnsafeMutableBytes { outputBuffer in
                var stream = z_stream()
                stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inputBuffer.bindMemory(to: Bytef.self).baseAddress)
                stream.avail_in = uInt(input.count)
                stream.next_out = outputBuffer.bindMemory(to: Bytef.self).baseAddress
                stream.avail_out = uInt(expandedSize)
                let initialized = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
                guard initialized == Z_OK else { return initialized }
                defer { inflateEnd(&stream) }
                let result = inflate(&stream, Z_FINISH)
                guard result == Z_STREAM_END, stream.total_out == expandedSize else { return Z_DATA_ERROR }
                return Z_OK
            }
        }
        guard status == Z_OK else { throw APKGImportError.malformedCollection }
        return output
    }

    private func readSQLiteCards(at url: URL, packageName: String) throws -> [PrototypeImportedCard] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK,
              let database else {
            throw APKGImportError.databaseOpenFailed
        }
        defer { sqlite3_close(database) }

        let modelFields = try readModelFields(from: database)
        let sql = "SELECT c.id, n.mid, n.flds FROM cards c JOIN notes n ON n.id = c.nid ORDER BY c.id LIMIT \(maximumCards)"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw APKGImportError.databaseQueryFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }

        var cards: [PrototypeImportedCard] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let cardID = sqlite3_column_int64(statement, 0)
            let modelID = sqlite3_column_int64(statement, 1)
            guard let fieldsText = sqlite3_column_text(statement, 2) else { continue }
            let fields = String(cString: fieldsText).split(separator: "\u{001F}", omittingEmptySubsequences: false)
            let names = modelFields[String(modelID)] ?? []
            let values = Dictionary(uniqueKeysWithValues: zip(names, fields.map(String.init)))
            guard let word = mapWord(fields: fields.map(String.init), named: values) else { continue }
            cards.append(
                PrototypeImportedCard(
                    sourceIdentifier: "\(packageName.lowercased())::\(cardID)",
                    word: word
                )
            )
        }
        guard sqlite3_errcode(database) == SQLITE_OK || sqlite3_errcode(database) == SQLITE_DONE else {
            throw APKGImportError.databaseQueryFailed(String(cString: sqlite3_errmsg(database)))
        }
        guard !cards.isEmpty else { throw APKGImportError.noCards }
        return cards
    }

    private func readModelFields(from database: OpaquePointer) throws -> [String: [String]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT models FROM col LIMIT 1", -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw APKGImportError.databaseQueryFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let text = sqlite3_column_text(statement, 0),
              let data = String(cString: text).data(using: .utf8),
              let models = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            throw APKGImportError.databaseQueryFailed("تعریف فیلدهای مدل کارت معتبر نیست.")
        }
        return models.mapValues { model in
            guard let fields = model["flds"] as? [[String: Any]] else { return [] }
            return fields.sorted { ($0["ord"] as? Int ?? 0) < ($1["ord"] as? Int ?? 0) }
                .compactMap { $0["name"] as? String }
        }
    }

    private func mapWord(fields: [String], named values: [String: String]) -> PrototypeWord? {
        if let rawJSON = values["LinguaBrainJSON"],
           let data = rawJSON.data(using: .utf8),
           let payload = try? JSONDecoder().decode(LinguaBrainAnkiPayload.self, from: data) {
            let rawWord = sanitize(payload.word)
            let compactWord = sanitize(rawWord.components(separatedBy: "—").first ?? rawWord)
            let german = compactWord.isEmpty ? sanitize(payload.headword) : compactWord
            guard !german.isEmpty else { return nil }
            let firstExample = payload.examples.first
            return PrototypeWord(
                german: german,
                persian: payload.meaningFA.map(sanitize).filter { !$0.isEmpty }.joined(separator: "، "),
                article: germanArticle(in: german),
                level: sanitize(payload.level),
                partOfSpeech: sanitize(payload.partOfSpeechFA),
                example: firstExample.map { sanitize($0.de) } ?? "",
                exampleTranslation: firstExample.map { sanitize($0.fa) } ?? ""
            )
        }

        // Compatibility with APKG files produced by older anki_single builds:
        // Front = Persian meaning + grammar, Back = German headword, Level/Stars.
        if let front = values["Front"], let back = values["Back"] {
            let persian = front.components(separatedBy: "\n\n").first.map(sanitize) ?? ""
            let german = sanitize(back.components(separatedBy: "|").first ?? back)
            guard !german.isEmpty else { return nil }
            return PrototypeWord(
                german: german,
                persian: persian.isEmpty ? "—" : persian.replacingOccurrences(of: "\n", with: "، "),
                article: germanArticle(in: back),
                level: sanitize(values["Level"] ?? "—"),
                partOfSpeech: extractPartOfSpeech(from: back) ?? "Imported",
                example: "",
                exampleTranslation: ""
            )
        }

        guard let first = fields.first else { return nil }
        let front = sanitize(first)
        let back = fields.count > 1 ? sanitize(fields[1]) : ""
        guard !front.isEmpty else { return nil }
        return PrototypeWord(
            german: front,
            persian: back.isEmpty ? "—" : back,
            level: "—",
            partOfSpeech: "Imported",
            example: "",
            exampleTranslation: ""
        )
    }

    private func germanArticle(in value: String) -> String? {
        let normalized = sanitize(value).lowercased()
        return ["der", "die", "das"].first { normalized.contains("\($0) ") }
    }

    private func extractPartOfSpeech(from value: String) -> String? {
        guard let opening = value.lastIndex(of: "("), let closing = value.lastIndex(of: ")"), opening < closing else {
            return nil
        }
        let result = sanitize(String(value[value.index(after: opening)..<closing]))
        return result.isEmpty ? nil : result
    }

    private func sanitize(_ value: String) -> String {
        var result = value
            .replacingOccurrences(of: #"\[sound:[^\]]+\]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        let entities = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\""]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

private struct LinguaBrainAnkiPayload: Decodable {
    struct Example: Decodable {
        let de: String
        let fa: String
        let en: String
    }

    let word: String
    let headword: String
    let partOfSpeechFA: String
    let level: String
    let meaningFA: [String]
    let examples: [Example]

    enum CodingKeys: String, CodingKey {
        case word, headword, level, examples
        case partOfSpeechFA = "part_of_speech_fa"
        case meaningFA = "meaning_fa"
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
