import AVFoundation
import Observation
import Speech
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum PrototypeTranslationLanguage: String, CaseIterable, Identifiable {
    case persian = "fa"
    case german = "de"
    case english = "en"

    var id: Self { self }
    var title: String {
        switch self {
        case .persian: "فارسی"
        case .german: "Deutsch"
        case .english: "English"
        }
    }
}

enum PrototypeTranscriptionProvider: String, CaseIterable, Identifiable {
    case appleOnDevice
    case openAICloud

    var id: Self { self }

    var title: String {
        switch self {
        case .appleOnDevice: "روی دستگاه اپل"
        case .openAICloud: "OpenAI Cloud"
        }
    }

    var symbol: String {
        switch self {
        case .appleOnDevice: "iphone.gen3"
        case .openAICloud: "cloud.fill"
        }
    }
}

@MainActor
@Observable
final class LiveTranscriptionController {
    var provider: PrototypeTranscriptionProvider = .appleOnDevice
    private(set) var transcript = ""
    private(set) var partialTranscript = ""
    private(set) var isRecording = false
    private(set) var errorMessage: String?

    private var audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognizer: SFSpeechRecognizer?

    var visibleText: String {
        [transcript, partialTranscript].filter { !$0.isEmpty }.joined(separator: transcript.isEmpty ? "" : " ")
    }

    func toggle() {
        if isRecording { stop() } else { start() }
    }

    func clear() {
        transcript = ""
        partialTranscript = ""
        errorMessage = nil
    }

    func start() {
        guard !isRecording else { return }
        guard provider == .appleOnDevice else {
            errorMessage = "اتصال OpenAI Realtime در مرحلهٔ بعدی همین ابزار فعال می‌شود."
            return
        }
        Task { await startOnDevice() }
    }

    func stop() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        partialTranscript = ""
    }

    private func startOnDevice() async {
        errorMessage = nil
        let speechStatus = await requestSpeechAuthorization()
        guard speechStatus == .authorized else {
            errorMessage = "اجازهٔ تشخیص گفتار داده نشد. از Settings دسترسی Speech و Microphone را فعال کنید."
            return
        }
        let microphoneGranted = await requestMicrophoneAuthorization()
        guard microphoneGranted else {
            errorMessage = "اجازهٔ میکروفون داده نشد."
            return
        }
        guard let recognizer = SFSpeechRecognizer() else {
            errorMessage = "تشخیص گفتار برای زبان دستگاه در دسترس نیست."
            return
        }
        recognizer.defaultTaskHint = .dictation
        recognizer.supportsOnDeviceRecognition = true
        guard recognizer.isAvailable else {
            errorMessage = "تشخیص گفتار فعلاً در دسترس نیست."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        self.recognizer = recognizer
        recognitionRequest = request
        audioEngine = engine
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    if result.isFinal {
                        self.transcript = [self.transcript, result.bestTranscription.formattedString]
                            .filter { !$0.isEmpty }.joined(separator: " ")
                        self.partialTranscript = ""
                    } else {
                        self.partialTranscript = result.bestTranscription.formattedString
                    }
                }
                if let error, self.isRecording {
                    self.errorMessage = error.localizedDescription
                    self.stop()
                }
            }
        }

        do {
            try engine.start()
            isRecording = true
        } catch {
            errorMessage = error.localizedDescription
            stop()
        }
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
    }
}

struct UtilitiesPrototypeView: View {
    @Environment(PrototypeAISettings.self) private var aiSettings
    @State private var transcription = LiveTranscriptionController()
    @State private var translationLanguage: PrototypeTranslationLanguage = .persian
    @State private var translatedText = ""
    @State private var translationError: String?
    @State private var isTranslating = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                providerPicker
                transcriptCard
                translationCard
                utilityRoadmap
            }
            .padding()
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .background(PrototypeBackground())
        .navigationTitle("ابزارها")
    }

    private var header: some View {
        PrototypeCard {
            HStack(spacing: 14) {
                Image(systemName: "waveform.and.mic")
                    .font(.title)
                    .foregroundStyle(PrototypeTheme.accent)
                    .frame(width: 54, height: 54)
                    .background(PrototypeTheme.accent.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("تبدیل صوت به متن زنده").font(.title3.weight(.bold))
                    Text("برای جلسه، یادداشت‌برداری و استخراج واژه‌های جدید")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var providerPicker: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("منبع تشخیص گفتار").font(.headline)
                Picker("منبع تشخیص گفتار", selection: $transcription.provider) {
                    ForEach(PrototypeTranscriptionProvider.allCases) { provider in
                        Label(provider.title, systemImage: provider.symbol).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                Text(transcription.provider == .appleOnDevice
                     ? "پردازش روی دستگاه انجام می‌شود و متن جلسه به سرویس ابری ارسال نمی‌شود."
                     : "OpenAI Realtime برای استریم ابری در گام بعدی به Providerهای پروژه متصل می‌شود.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var transcriptCard: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("متن زنده").font(.headline)
                    Spacer()
                    if transcription.isRecording {
                        Label("در حال شنیدن", systemImage: "record.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                Text(transcription.visibleText.isEmpty ? "برای شروع، دکمهٔ میکروفون را بزنید…" : transcription.visibleText)
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
                    .padding()
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
                    .textSelection(.enabled)
                if let errorMessage = transcription.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                HStack {
                    Button {
                        transcription.toggle()
                    } label: {
                        Label(transcription.isRecording ? "توقف" : "شروع ضبط", systemImage: transcription.isRecording ? "stop.fill" : "mic.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(transcription.isRecording ? .red : PrototypeTheme.accent)
                    Button("پاک کردن") { transcription.clear() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button {
                        copyToClipboard(transcription.visibleText)
                    } label: {
                        Label("کپی متن", systemImage: "doc.on.doc")
                    }
                    .disabled(transcription.visibleText.isEmpty)
                }
            }
        }
    }

    private var translationCard: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("ترجمهٔ متن").font(.headline)
                    Spacer()
                    Picker("زبان ترجمه", selection: $translationLanguage) {
                        ForEach(PrototypeTranslationLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .labelsHidden()
                }
                Text(translatedText.isEmpty ? "زبان مقصد را انتخاب کنید و ترجمه را بزنید." : translatedText)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                    .padding()
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
                    .textSelection(.enabled)
                if let translationError {
                    Label(translationError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                HStack {
                    Button {
                        translateTranscript()
                    } label: {
                        Label(isTranslating ? "در حال ترجمه…" : "ترجمه با AI", systemImage: "character.bubble")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isTranslating || transcription.visibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button {
                        copyToClipboard(translatedText)
                    } label: {
                        Label("کپی ترجمه", systemImage: "doc.on.doc")
                    }
                    .disabled(translatedText.isEmpty)
                }
                Text("ترجمه از Provider متنی تنظیم‌شده در بخش هوش مصنوعی استفاده می‌کند.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func translateTranscript() {
        let text = transcription.visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isTranslating = true
        translationError = nil
        Task {
            do {
                let key = try aiSettings.apiKey()
                let client = ConfiguredProviderClient(baseURL: aiSettings.endpoint, protocolName: aiSettings.protocolName)
                translatedText = try await client.translate(
                    text: text,
                    targetLanguageTag: translationLanguage.rawValue,
                    model: aiSettings.modelID,
                    apiKey: key
                )
            } catch {
                translationError = error.localizedDescription
            }
            isTranslating = false
        }
    }

    private func copyToClipboard(_ text: String) {
        guard !text.isEmpty else { return }
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }

    private var utilityRoadmap: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("ادامهٔ مسیر ابزار").font(.headline)
                Label("ذخیرهٔ متن جلسه و یادداشت‌ها", systemImage: "note.text")
                Label("استخراج واژه‌های جدید و ساخت کارت", systemImage: "rectangle.stack.badge.plus")
                Label("ترجمه و خلاصه‌سازی جلسه با AI", systemImage: "sparkles")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}
