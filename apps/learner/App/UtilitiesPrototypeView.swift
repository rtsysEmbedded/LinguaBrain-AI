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
    private(set) var inputLevel: Double = 0

    private var modernAnalyzer: SpeechAnalyzer?
    private var modernTranscriber: SpeechTranscriber?
    private var modernCaptureProvider: CaptureInputSequenceProvider?
    private var modernResultsTask: Task<Void, Never>?
    private var audioMeter: AudioInputMeter?

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
            inputLevel = 0
            audioMeter = nil
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

            // Build the capture session explicitly. On the current iOS/macOS
            // 27 SDK, the convenience providerWithSession(from:) can crash
            // inside Speech.framework before returning an error for some
            // microphone routes. The explicit initializer keeps ownership of
            // the AVCaptureSession in this controller and avoids that path.
            let captureSession = AVCaptureSession()
            captureSession.beginConfiguration()
            let captureInput = try AVCaptureDeviceInput(device: device)
            guard captureSession.canAddInput(captureInput) else {
                captureSession.commitConfiguration()
                throw TranscriptionError.captureInputUnavailable
            }
            captureSession.addInput(captureInput)
            let meter = AudioInputMeter { [weak self] level in
                Task { @MainActor in self?.inputLevel = level }
            }
            let meterOutput = AVCaptureAudioDataOutput()
            meterOutput.setSampleBufferDelegate(meter, queue: DispatchQueue(label: "ai.linguabrain.audio-meter"))
            guard captureSession.canAddOutput(meterOutput) else {
                captureSession.commitConfiguration()
                throw TranscriptionError.captureOutputUnavailable
            }
            captureSession.addOutput(meterOutput)
            guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules) else {
                captureSession.commitConfiguration()
                throw TranscriptionError.audioFormatUnavailable
            }
            let captureProvider = try CaptureInputSequenceProvider(
                session: captureSession,
                analyzerFormat: analyzerFormat,
                priority: nil
            )
            captureSession.commitConfiguration()
            let analyzer = SpeechAnalyzer(modules: modules)
            modernTranscriber = transcriber
            modernAnalyzer = analyzer
            modernCaptureProvider = captureProvider
            audioMeter = meter
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

private enum TranscriptionError: LocalizedError {
    case captureInputUnavailable
    case captureOutputUnavailable
    case audioFormatUnavailable

    var errorDescription: String? {
        switch self {
        case .captureInputUnavailable: "The selected microphone cannot be attached to the capture session."
        case .captureOutputUnavailable: "The microphone capture output could not be created."
        case .audioFormatUnavailable: "No compatible audio format is available for live transcription."
        }
    }
}

private final class AudioInputMeter: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let onLevel: @Sendable (Double) -> Void

    init(onLevel: @escaping @Sendable (Double) -> Void) {
        self.onLevel = onLevel
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        var length = 0
        var pointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer) == kCMBlockBufferNoErr,
              let pointer, length >= 2 else { return }
        let sampleCount = length / 2
        var energy = 0.0
        for index in 0..<sampleCount {
            let low = UInt16(UInt8(bitPattern: pointer[index * 2]))
            let high = UInt16(UInt8(bitPattern: pointer[index * 2 + 1])) << 8
            let sample = Int16(bitPattern: high | low)
            let normalized = Double(sample) / Double(Int16.max)
            energy += normalized * normalized
        }
        let rms = sqrt(energy / Double(sampleCount))
        onLevel(min(1, max(0, rms * 4)))
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
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.16))
                            Capsule()
                                .fill(transcription.inputLevel > 0.04 ? PrototypeTheme.accent : .secondary)
                                .frame(width: proxy.size.width * max(0.03, transcription.inputLevel))
                                .animation(.easeOut(duration: 0.08), value: transcription.inputLevel)
                        }
                    }
                    .frame(height: 8)
                    Text(transcription.inputLevel > 0.04
                         ? localization.localized("utilities.inputActive")
                         : localization.localized("utilities.inputWaiting"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 18)
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
