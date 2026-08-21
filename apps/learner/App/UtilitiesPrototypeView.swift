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
        case .persian: "language.persian"
        case .german: "language.german"
        case .english: "language.english"
        }
    }

    func localizedTitle(_ localization: PrototypeLocalization) -> String {
        localization.localized(title)
    }
}

enum PrototypeTranscriptionProvider: String, CaseIterable, Identifiable {
    case appleOnDevice
    case openAICloud

    var id: Self { self }

    var title: String {
        switch self {
        case .appleOnDevice: "utilities.provider.apple"
        case .openAICloud: "utilities.provider.openai"
        }
    }

    func localizedTitle(_ localization: PrototypeLocalization) -> String {
        localization.localized(title)
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
    private var isStarting = false
    private(set) var errorMessage: String?

    private var audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognizer: SFSpeechRecognizer?
    private var tapInstalled = false

    var visibleText: String {
        [transcript, partialTranscript].filter { !$0.isEmpty }.joined(separator: transcript.isEmpty ? "" : " ")
    }

    var inputDeviceName: String {
        #if os(macOS)
        return AVCaptureDevice.default(for: .audio)?.localizedName ?? "System Default"
        #else
        return "Device Microphone"
        #endif
    }

    func toggle(languageTag: String = "de") {
        if isRecording { stop() } else if !isStarting { start(languageTag: languageTag) }
    }

    func clear() {
        transcript = ""
        partialTranscript = ""
        errorMessage = nil
    }

    func start(languageTag: String = "de") {
        guard !isRecording, !isStarting else { return }
        isStarting = true
        guard provider == .appleOnDevice else {
            errorMessage = "OpenAI Realtime streaming is not connected yet."
            isStarting = false
            return
        }
        Task { await startOnDevice(languageTag: languageTag) }
    }

    func stop() {
        audioEngine?.stop()
        if tapInstalled {
            audioEngine?.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        isStarting = false
        partialTranscript = ""
    }

    private func startOnDevice(languageTag: String) async {
        errorMessage = nil
        let speechStatus = await requestSpeechAuthorization()
        guard speechStatus == .authorized else {
            errorMessage = "اجازهٔ تشخیص گفتار داده نشد. از Settings دسترسی Speech و Microphone را فعال کنید."
            isStarting = false
            return
        }
        let microphoneGranted = await requestMicrophoneAuthorization()
        guard microphoneGranted else {
            errorMessage = "اجازهٔ میکروفون داده نشد."
            isStarting = false
            return
        }
        let locale = Locale(identifier: languageTag)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            errorMessage = "تشخیص گفتار برای زبان دستگاه در دسترس نیست."
            isStarting = false
            return
        }
        recognizer.defaultTaskHint = .dictation
        recognizer.supportsOnDeviceRecognition = true
        guard recognizer.isAvailable else {
            errorMessage = "تشخیص گفتار فعلاً در دسترس نیست."
            isStarting = false
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        guard inputNode.inputFormat(forBus: 0).channelCount > 0 else {
            errorMessage = "No audio input device is available. Select a microphone in macOS Sound settings."
            isStarting = false
            return
        }
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session: \(error.localizedDescription)"
            isStarting = false
            return
        }
        #endif
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: nil) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        tapInstalled = true

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
            engine.prepare()
            try engine.start()
            isRecording = true
            isStarting = false
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
    @Environment(PrototypeLocalization.self) private var localization
    @Environment(PrototypeLanguageSettings.self) private var languageSettings
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
        .navigationTitle(localization.localized("utilities.title"))
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
                    Text(localization.localized("utilities.liveTitle")).font(.title3.weight(.bold))
                    Text(localization.localized("utilities.liveSubtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var providerPicker: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(localization.localized("utilities.providerLabel")).font(.headline)
                Picker(localization.localized("utilities.providerLabel"), selection: $transcription.provider) {
                    ForEach(PrototypeTranscriptionProvider.allCases) { provider in
                        Label(provider.localizedTitle(localization), systemImage: provider.symbol).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                Text(localization.localized(transcription.provider == .appleOnDevice
                     ? "utilities.provider.appleDescription"
                     : "utilities.provider.openaiDescription"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Label(localization.localized("utilities.inputSource"), systemImage: "mic")
                    Spacer()
                    Text(transcription.inputDeviceName)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
    }

    private var transcriptCard: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(localization.localized("utilities.transcriptTitle")).font(.headline)
                    Spacer()
                    if transcription.isRecording {
                        Label(localization.localized("utilities.listening"), systemImage: "record.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                Text(transcription.visibleText.isEmpty ? localization.localized("utilities.emptyTranscript") : transcription.visibleText)
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
                        transcription.toggle(languageTag: languageSettings.targetLanguageTag)
                    } label: {
                        Label(localization.localized(transcription.isRecording ? "utilities.stop" : "utilities.start"), systemImage: transcription.isRecording ? "stop.fill" : "mic.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(transcription.isRecording ? .red : PrototypeTheme.accent)
                    Button(localization.localized("utilities.clear")) { transcription.clear() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button {
                        copyToClipboard(transcription.visibleText)
                    } label: {
                        Label(localization.localized("utilities.copyTranscript"), systemImage: "doc.on.doc")
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
                    Text(localization.localized("utilities.translationTitle")).font(.headline)
                    Spacer()
                    Picker(localization.localized("utilities.translationLanguage"), selection: $translationLanguage) {
                        ForEach(PrototypeTranslationLanguage.allCases) { language in
                            Text(language.localizedTitle(localization)).tag(language)
                        }
                    }
                    .labelsHidden()
                }
                Text(translatedText.isEmpty ? localization.localized("utilities.translationEmpty") : translatedText)
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
                        Label(localization.localized(isTranslating ? "utilities.translating" : "utilities.translate"), systemImage: "character.bubble")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isTranslating || transcription.visibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button {
                        copyToClipboard(translatedText)
                    } label: {
                        Label(localization.localized("utilities.copyTranslation"), systemImage: "doc.on.doc")
                    }
                    .disabled(translatedText.isEmpty)
                }
                Text(localization.localized("utilities.translationProviderNote"))
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
                Text(localization.localized("utilities.roadmapTitle")).font(.headline)
                Label(localization.localized("utilities.roadmap.saveNotes"), systemImage: "note.text")
                Label(localization.localized("utilities.roadmap.extractWords"), systemImage: "rectangle.stack.badge.plus")
                Label(localization.localized("utilities.roadmap.summarize"), systemImage: "sparkles")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}
