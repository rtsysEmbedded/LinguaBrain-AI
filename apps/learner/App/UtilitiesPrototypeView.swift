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

    private var modernAnalyzer: SpeechAnalyzer?
    private var modernTranscriber: SpeechTranscriber?
    private var modernCaptureProvider: CaptureInputSequenceProvider?
    private var modernResultsTask: Task<Void, Never>?

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
            errorMessage = "Cloud live transcription requires a configured realtime transcription provider."
            isStarting = false
            return
        }
        Task { await startModernOnDevice(languageTag: languageTag) }
    }

    func stop() {
        if let captureProvider = modernCaptureProvider {
            captureProvider.captureSession.stopRunning()
            modernCaptureProvider = nil
            modernResultsTask?.cancel()
            modernResultsTask = nil
            let analyzer = modernAnalyzer
            modernAnalyzer = nil
            modernTranscriber = nil
            isRecording = false
            isStarting = false
            Task { try? await analyzer?.finalizeAndFinishThroughEndOfInput() }
            return
        }
        isRecording = false
        isStarting = false
        partialTranscript = ""
    }

    private func startModernOnDevice(languageTag: String) async {
        errorMessage = nil
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            errorMessage = "Microphone permission was denied."
            isStarting = false
            return
        }
        let requestedLocale = Locale(identifier: languageTag)
        guard SpeechTranscriber.isAvailable,
              let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale) else {
            errorMessage = "The selected language is not supported by Apple's on-device transcription model."
            isStarting = false
            return
        }
        guard let device = AVCaptureDevice.default(for: .audio) else {
            errorMessage = "No microphone is available."
            isStarting = false
            return
        }

        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        do {
            let modules: [any SpeechModule] = [transcriber]
            let status = await AssetInventory.status(forModules: modules)
            if status != .installed {
                guard let request = try await AssetInventory.assetInstallationRequest(supporting: modules) else {
                    errorMessage = "The speech model for this language is not installed."
                    isStarting = false
                    return
                }
                try await request.downloadAndInstall()
            }

            let captureProvider = try await CaptureInputSequenceProvider.providerWithSession(
                from: device,
                compatibleWith: modules
            )
            let analyzer = SpeechAnalyzer(modules: modules)
            modernTranscriber = transcriber
            modernAnalyzer = analyzer
            modernCaptureProvider = captureProvider
            modernResultsTask = Task { [weak self] in
                do {
                    for try await result in transcriber.results {
                        guard let self else { return }
                        let text = String(result.text.characters)
                        if result.isFinal {
                            self.transcript = [self.transcript, text].filter { !$0.isEmpty }.joined(separator: " ")
                            self.partialTranscript = ""
                        } else {
                            self.partialTranscript = text
                        }
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    self?.errorMessage = error.localizedDescription
                }
            }
            try await analyzer.start(inputSequence: captureProvider.analyzerInputs)
            captureProvider.captureSession.startRunning()
            isRecording = true
            isStarting = false
        } catch {
            modernResultsTask?.cancel()
            modernResultsTask = nil
            modernCaptureProvider = nil
            modernAnalyzer = nil
            modernTranscriber = nil
            errorMessage = error.localizedDescription
            isStarting = false
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
    @State private var liveTranslationTask: Task<Void, Never>?

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
        .onDisappear { liveTranslationTask?.cancel() }
        .onChange(of: transcription.visibleText) { _, value in
            scheduleLiveTranslation(value)
        }
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

    private func scheduleLiveTranslation(_ value: String) {
        liveTranslationTask?.cancel()
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 8, aiSettings.textMode == .cloud else { return }
        liveTranslationTask = Task {
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            do {
                let key = try aiSettings.apiKey()
                let client = ConfiguredProviderClient(baseURL: aiSettings.endpoint, protocolName: aiSettings.protocolName)
                await MainActor.run { translatedText = ""; translationError = nil }
                try await client.streamTranslate(text: text, targetLanguageTag: translationLanguage.rawValue, model: aiSettings.modelID, apiKey: key) { delta in
                    await MainActor.run { translatedText += delta }
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { translationError = error.localizedDescription }
            }
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
