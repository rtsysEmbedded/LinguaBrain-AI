@preconcurrency import AVFoundation
import Observation
import Speech
import SwiftUI
#if os(macOS)
import AppKit
import CoreAudio
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

enum PrototypeCloudTranscriptionMode: String, CaseIterable, Identifiable {
    case transcript
    case liveStream

    var id: Self { self }
    var titleKey: String {
        switch self {
        case .transcript: "utilities.mode.transcript"
        case .liveStream: "utilities.mode.stream"
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
    private var cloudCaptureSession: AVCaptureSession?
    private var cloudCaptureHandler: CloudAudioCaptureHandler?
    private var cloudSocket: URLSessionWebSocketTask?
    private var cloudURLSession: URLSession?
    private var cloudSocketDelegate: CloudWebSocketDelegate?
    private var cloudReceiveTask: Task<Void, Never>?
    private var cloudSentAudioBytes = 0

    var visibleText: String {
        [transcript, partialTranscript].filter { !$0.isEmpty }.joined(separator: transcript.isEmpty ? "" : " ")
    }

    var inputDeviceName: String {
        #if os(macOS)
        return AVCaptureDevice.default(for: .audio)?.localizedName ?? PrototypeLocalization.current("utilities.deviceDefault")
        #else
        return PrototypeLocalization.current("utilities.deviceMicrophone")
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

    func start(
        languageTag: String = "de",
        aiSettings: PrototypeAISettings? = nil,
        cloudMode: PrototypeCloudTranscriptionMode = .liveStream
    ) {
        guard !isRecording, !isStarting else { return }
        isStarting = true
        Task {
            if provider == .appleOnDevice {
                await startModernOnDevice(languageTag: languageTag)
            } else if let aiSettings {
                await startCloudRealtime(languageTag: languageTag, settings: aiSettings, mode: cloudMode)
            } else {
                errorMessage = PrototypeLocalization.current("utilities.error.cloudSettingsUnavailable")
                isStarting = false
            }
        }
    }

    func stop() {
        if let captureProvider = modernCaptureProvider {
            captureProvider.captureSession.stopRunning()
            modernCaptureProvider = nil
            let resultsTask = modernResultsTask
            let analyzer = modernAnalyzer
            modernAnalyzer = nil
            modernTranscriber = nil
            isRecording = false
            isStarting = false
            inputLevel = 0
            audioMeter = nil
            Task {
                try? await analyzer?.finalizeAndFinishThroughEndOfInput()
                resultsTask?.cancel()
            }
            modernResultsTask = nil
            return
        }
        if let cloudCaptureSession {
            cloudCaptureSession.stopRunning()
            self.cloudCaptureSession = nil
            cloudCaptureHandler = nil
            let socket = cloudSocket
            let shouldCommit = cloudSentAudioBytes > 0
            cloudSentAudioBytes = 0
            Task {
                if let socket {
                    if shouldCommit {
                        try? await Self.sendCloudMessage(
                            Self.jsonString(["type": "input_audio_buffer.commit"]),
                            via: socket,
                            attempts: 2
                        )
                        // Keep receiving briefly so the final committed event is
                        // not discarded when the learner taps Stop.
                        try? await Task.sleep(for: .seconds(2))
                    }
                    await MainActor.run {
                        self.cloudSocket = nil
                        self.cloudReceiveTask?.cancel()
                        self.cloudReceiveTask = nil
                    }
                    socket.cancel(with: .normalClosure, reason: nil)
                }
                await MainActor.run {
                    self.cloudURLSession?.invalidateAndCancel()
                    self.cloudURLSession = nil
                    self.cloudSocketDelegate = nil
                }
            }
            audioMeter = nil
            isRecording = false
            isStarting = false
            inputLevel = 0
            return
        }
        isRecording = false
        isStarting = false
        partialTranscript = ""
    }

    private func startModernOnDevice(languageTag: String) async {
        errorMessage = nil
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            errorMessage = PrototypeLocalization.current("utilities.error.microphoneDenied")
            isStarting = false
            return
        }
        let requestedLocale = Locale(identifier: languageTag)
        guard SpeechTranscriber.isAvailable,
              let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale) else {
            errorMessage = PrototypeLocalization.current("utilities.error.languageUnsupported")
            isStarting = false
            return
        }
        guard let device = AVCaptureDevice.default(for: .audio) else {
            errorMessage = PrototypeLocalization.current("utilities.error.noMicrophone")
            isStarting = false
            return
        }

        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        do {
            let modules: [any SpeechModule] = [transcriber]
            let status = await AssetInventory.status(forModules: modules)
            if status != .installed {
                guard let request = try await AssetInventory.assetInstallationRequest(supporting: modules) else {
                    errorMessage = PrototypeLocalization.current("utilities.error.speechModelMissing")
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
            captureProvider.captureSession.startRunning()
            isRecording = true
            isStarting = false
            // Start capture before attaching the analyzer input sequence. This
            // ensures the first microphone buffers are available immediately
            // on both the native macOS target and iOS 27.
            try await analyzer.start(inputSequence: captureProvider.analyzerInputs)
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

    private func startCloudRealtime(
        languageTag: String,
        settings: PrototypeAISettings,
        mode: PrototypeCloudTranscriptionMode
    ) async {
        errorMessage = nil
        guard settings.audioMode == .cloud else {
            errorMessage = PrototypeLocalization.current("utilities.error.enableCloudAudio")
            isStarting = false
            return
        }
        guard settings.audioEndpoint.localizedCaseInsensitiveContains(ProviderCatalog.bundled.hostMarkers.openAI) else {
            errorMessage = PrototypeLocalization.current("utilities.error.realtimeEndpoint", ProviderCatalog.bundled.hostMarkers.openAI)
            isStarting = false
            return
        }
        guard let apiKey = try? settings.apiKey(for: "audio"), !apiKey.isEmpty else {
            errorMessage = PrototypeLocalization.current("utilities.error.audioKeyMissing")
            isStarting = false
            return
        }
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            errorMessage = PrototypeLocalization.current("utilities.error.microphoneUnavailable")
            isStarting = false
            return
        }

        do {
            let realtime = ProviderCatalog.bundled.realtimeTranscription
            var request = URLRequest(url: URL(string: ProviderCatalog.bundled.endpoints.realtimeTranscription)!)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            let delegate = CloudWebSocketDelegate { [weak self] code in
                Task { @MainActor in
                    guard self?.cloudSocket != nil else { return }
                    self?.errorMessage = PrototypeLocalization.current("utilities.error.socketClosed", "\(code.rawValue)")
                    self?.isRecording = false
                    self?.isStarting = false
                }
            } onFailure: { [weak self] error in
                Task { @MainActor in
                    guard self?.cloudSocket != nil else { return }
                    self?.errorMessage = PrototypeLocalization.current("utilities.error.transportFailed", error.localizedDescription)
                    self?.isRecording = false
                    self?.isStarting = false
                }
            }
            let urlSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let socket = urlSession.webSocketTask(with: request)
            socket.resume()
            cloudSocket = socket
            cloudURLSession = urlSession
            cloudSocketDelegate = delegate
            startCloudReceiveLoop(socket)

            let connectionDeadline = ContinuousClock.now.advanced(by: .seconds(realtime.connectionTimeoutSeconds))
            while !delegate.isOpen {
                guard ContinuousClock.now < connectionDeadline else {
                    throw TranscriptionError.connectionTimedOut
                }
                try await Task.sleep(for: .milliseconds(50))
            }

            let requestedModel = mode == .liveStream
                ? settings.audioStreamModelID
                : settings.audioTranscriptModelID
            let fallbackModel = mode == .liveStream
                ? ProviderCatalog.bundled.models.stream
                : ProviderCatalog.bundled.models.transcript
            let transcriptionModel = realtime.supportedModels.contains(requestedModel) ? requestedModel : fallbackModel
            // Per-model language hints live in provider-catalog.json: the live
            // model rejects the singular `language` field, while legacy
            // GPT-4o/Whisper models accept only the singular ISO 639-1 hint.
            let transcriptionConfiguration = realtime.configuration(
                model: transcriptionModel,
                languageTag: languageTag
            )
            let sessionUpdate: [String: Any] = [
                "type": "session.update",
                "session": [
                    "type": "transcription",
                    "audio": [
                        "input": [
                            "format": ["type": "audio/pcm", "rate": 24_000],
                            "transcription": transcriptionConfiguration,
                            // Dedicated transcription sessions currently use
                            // explicit client commits. In particular,
                            // Automatic detection was rejected for the tested
                            // live transcription mode, which emits deltas
                            // without it and is finalized by an explicit commit.
                            "turn_detection": NSNull(),
                            "noise_reduction": ["type": realtime.noiseReduction]
                        ]
                    ]
                ]
            ]
            try await Self.sendCloudMessage(Self.jsonString(sessionUpdate), via: socket)

            #if os(macOS)
            guard Self.hasDefaultAudioInputDevice() else {
                throw TranscriptionError.noInputDevice
            }
            #endif
            guard let device = AVCaptureDevice.default(for: .audio) else {
                throw TranscriptionError.noInputDevice
            }

            // Use one capture stack on iOS and macOS. AVAudioEngine currently
            // fails to initialize its AUIO unit for some microphone routes on
            // the macOS/iOS 27 betas (OSStatus -50). AVCaptureSession delivers
            // the microphone's real CMSampleBuffer format without forcing an
            // Audio Unit configuration, and the delegate converts that format
            // explicitly before sending 24 kHz PCM to the Realtime API.
            let captureSession = AVCaptureSession()
            captureSession.beginConfiguration()
            let captureInput = try AVCaptureDeviceInput(device: device)
            guard captureSession.canAddInput(captureInput) else {
                captureSession.commitConfiguration()
                throw TranscriptionError.captureInputUnavailable
            }
            captureSession.addInput(captureInput)

            let captureHandler = CloudAudioCaptureHandler { [weak self, weak socket] processed in
                Task { [weak self, weak socket] in
                    guard let socket else { return }
                    for chunk in processed.chunks {
                        let event: [String: Any] = [
                            "type": "input_audio_buffer.append",
                            "audio": chunk.base64EncodedString()
                        ]
                        try? await Self.sendCloudMessage(Self.jsonString(event), via: socket, attempts: 2)
                        await MainActor.run { self?.cloudSentAudioBytes += chunk.count }
                    }
                    await MainActor.run { self?.inputLevel = processed.level }
                }
            }
            let captureOutput = AVCaptureAudioDataOutput()
            captureOutput.setSampleBufferDelegate(
                captureHandler,
                queue: DispatchQueue(label: "ai.linguabrain.cloud-audio-capture")
            )
            guard captureSession.canAddOutput(captureOutput) else {
                captureSession.commitConfiguration()
                throw TranscriptionError.captureOutputUnavailable
            }
            captureSession.addOutput(captureOutput)
            captureSession.commitConfiguration()

            cloudCaptureSession = captureSession
            cloudCaptureHandler = captureHandler
            cloudSentAudioBytes = 0
            captureSession.startRunning()
            isRecording = true
            isStarting = false
        } catch {
            cloudCaptureSession?.stopRunning()
            cloudCaptureSession = nil
            cloudCaptureHandler = nil
            cloudSentAudioBytes = 0
            cloudSocket?.cancel(with: .abnormalClosure, reason: nil)
            cloudSocket = nil
            cloudURLSession?.invalidateAndCancel()
            cloudURLSession = nil
            cloudSocketDelegate = nil
            errorMessage = error.localizedDescription
            isStarting = false
        }
    }

    private func startCloudReceiveLoop(_ socket: URLSessionWebSocketTask) {
        cloudReceiveTask?.cancel()
        cloudReceiveTask = Task { [weak self, weak socket] in
            guard let socket else { return }
            do {
                while !Task.isCancelled {
                    let message = try await socket.receive()
                    guard case .string(let text) = message,
                          let data = text.data(using: .utf8),
                          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let type = object["type"] as? String else { continue }
                    await MainActor.run {
                        if type == "conversation.item.input_audio_transcription.delta",
                           let delta = object["delta"] as? String {
                            self?.partialTranscript += delta
                        } else if type == "conversation.item.input_audio_transcription.completed",
                                  let completed = object["transcript"] as? String {
                            self?.transcript = [self?.transcript ?? "", completed].filter { !$0.isEmpty }.joined(separator: " ")
                            self?.partialTranscript = ""
                        } else if type == "error",
                                  let details = object["error"] as? [String: Any],
                                  let message = details["message"] as? String {
                            self?.errorMessage = PrototypeLocalization.current("utilities.error.provider", message)
                        }
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.errorMessage = PrototypeLocalization.current("utilities.error.connectionClosed", error.localizedDescription)
                    self?.isRecording = false
                    self?.isStarting = false
                }
            }
        }
    }

    private static func jsonString(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }

    private static func sendCloudMessage(_ json: String, via socket: URLSessionWebSocketTask, attempts: Int = 10) async throws {
        var lastError: Error?
        for attempt in 0..<max(1, attempts) {
            do {
                try await socket.send(.string(json))
                return
            } catch {
                lastError = error
                guard attempt + 1 < attempts else { break }
                try await Task.sleep(for: .milliseconds(250))
            }
        }
        throw lastError ?? URLError(.networkConnectionLost)
    }

    #if os(macOS)
    private static func hasDefaultAudioInputDevice() -> Bool {
        var deviceID = AudioDeviceID(kAudioDeviceUnknown)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        return status == noErr && deviceID != kAudioDeviceUnknown
    }
    #endif

}

private enum TranscriptionError: LocalizedError {
    case captureInputUnavailable
    case captureOutputUnavailable
    case audioFormatUnavailable
    case connectionTimedOut
    case noInputDevice

    var errorDescription: String? {
        switch self {
        case .captureInputUnavailable: PrototypeLocalization.current("utilities.error.captureInputUnavailable")
        case .captureOutputUnavailable: PrototypeLocalization.current("utilities.error.captureOutputUnavailable")
        case .audioFormatUnavailable: PrototypeLocalization.current("utilities.error.audioFormatUnavailable")
        case .connectionTimedOut:
            PrototypeLocalization.current(
                "utilities.error.connectionTimedOut",
                "\(ProviderCatalog.bundled.realtimeTranscription.connectionTimeoutSeconds)"
            )
        case .noInputDevice: PrototypeLocalization.current("utilities.error.noInputDevice")
        }
    }
}

private final class CloudWebSocketDelegate: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private let onClose: @Sendable (URLSessionWebSocketTask.CloseCode) -> Void
    private let onFailure: @Sendable (Error) -> Void
    private let stateLock = NSLock()
    private var opened = false

    var isOpen: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return opened
    }

    init(onClose: @escaping @Sendable (URLSessionWebSocketTask.CloseCode) -> Void, onFailure: @escaping @Sendable (Error) -> Void) {
        self.onClose = onClose
        self.onFailure = onFailure
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        stateLock.lock()
        opened = true
        stateLock.unlock()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        onClose(closeCode)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { onFailure(error) }
    }
}

private final class AudioInputMeter: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let onLevel: @Sendable (Double) -> Void

    init(onLevel: @escaping @Sendable (Double) -> Void) {
        self.onLevel = onLevel
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        sampleBuffer.withPCMBuffer { [onLevel] buffer in
            onLevel(RealtimeAudioProcessor.inputLevel(buffer))
        }
    }
}

/// Receives microphone buffers from AVCaptureSession, preserves their actual
/// hardware format, and lazily rebuilds the converter if a beta OS changes the
/// active microphone route while recording.
private final class CloudAudioCaptureHandler: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let onOutput: @Sendable (RealtimeAudioProcessor.Output) -> Void
    private var processor: RealtimeAudioProcessor?
    private var processorFormat: AVAudioFormat?

    init(onOutput: @escaping @Sendable (RealtimeAudioProcessor.Output) -> Void) {
        self.onOutput = onOutput
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        sampleBuffer.withPCMBuffer { [weak self] buffer in
            guard let self else { return }
            if processor == nil || processorFormat != buffer.format {
                processor = RealtimeAudioProcessor(inputFormat: buffer.format)
                processorFormat = buffer.format
            }
            guard let processor else { return }
            onOutput(processor.process(buffer))
        }
    }
}

private extension CMSampleBuffer {
    /// Exposes Core Media audio through AVAudioPCMBuffer for the duration of
    /// `body`. Unlike byte-level parsing, this respects Float32/Int16,
    /// interleaved/non-interleaved layouts, channel count, and route changes.
    func withPCMBuffer(_ body: (AVAudioPCMBuffer) -> Void) {
        guard let formatDescription = CMSampleBufferGetFormatDescription(self),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return
        }
        var description = streamDescription.pointee
        guard description.mFormatID == kAudioFormatLinearPCM,
              let format = AVAudioFormat(streamDescription: &description) else {
            return
        }

        do {
            try withAudioBufferList(flags: .audioBufferListAssure16ByteAlignment) { audioBuffers, _ in
                guard let buffer = AVAudioPCMBuffer(
                    pcmFormat: format,
                    bufferListNoCopy: UnsafePointer(audioBuffers.unsafeMutablePointer),
                    deallocator: nil
                ) else {
                    return
                }
                buffer.frameLength = min(
                    buffer.frameCapacity,
                    AVAudioFrameCount(CMSampleBufferGetNumSamples(self))
                )
                body(buffer)
            }
        } catch {
            return
        }
    }
}

/// Converts the hardware microphone format to the Realtime API's required
/// 24 kHz, mono, signed 16-bit PCM and emits chunks of at least 100 ms.
private final class RealtimeAudioProcessor: @unchecked Sendable {
    struct Output: Sendable {
        let level: Double
        let chunks: [Data]
    }

    private let lock = NSLock()
    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat
    private let accumulator = AudioPCMAccumulator(minimumBytes: 4_800)

    init?(inputFormat: AVAudioFormat) {
        guard inputFormat.sampleRate > 0,
              inputFormat.channelCount > 0,
              let outputFormat = AVAudioFormat(
                  commonFormat: .pcmFormatInt16,
                  sampleRate: 24_000,
                  channels: 1,
                  interleaved: true
              ),
              let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            return nil
        }
        self.outputFormat = outputFormat
        self.converter = converter
    }

    func process(_ input: AVAudioPCMBuffer) -> Output {
        lock.lock()
        defer { lock.unlock() }

        let level = Self.inputLevel(input)
        let ratio = outputFormat.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(max(1, ceil(Double(input.frameLength) * ratio) + 32))
        guard let converted = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            return Output(level: level, chunks: [])
        }

        var suppliedInput = false
        var conversionError: NSError?
        let status = converter.convert(to: converted, error: &conversionError) { _, inputStatus in
            guard !suppliedInput else {
                inputStatus.pointee = .noDataNow
                return nil
            }
            suppliedInput = true
            inputStatus.pointee = .haveData
            return input
        }
        guard conversionError == nil,
              status != .error,
              converted.frameLength > 0,
              let samples = converted.int16ChannelData?.pointee else {
            return Output(level: level, chunks: [])
        }

        let pcm = Data(bytes: samples, count: Int(converted.frameLength) * MemoryLayout<Int16>.size)
        return Output(level: level, chunks: accumulator.append(pcm))
    }

    fileprivate static func inputLevel(_ buffer: AVAudioPCMBuffer) -> Double {
        guard buffer.frameLength > 0 else { return 0 }
        let frameCount = Int(buffer.frameLength)
        if let channels = buffer.floatChannelData {
            let samples = channels[0]
            var energy = 0.0
            for index in 0..<frameCount {
                let value = Double(samples[index])
                energy += value * value
            }
            return min(1, max(0, sqrt(energy / Double(frameCount)) * 4))
        }
        if let channels = buffer.int16ChannelData {
            let samples = channels[0]
            var energy = 0.0
            for index in 0..<frameCount {
                let value = Double(samples[index]) / Double(Int16.max)
                energy += value * value
            }
            return min(1, max(0, sqrt(energy / Double(frameCount)) * 4))
        }
        return 0
    }
}

/// Buffers microphone PCM until each Realtime append contains at least 100 ms
/// of 24 kHz, mono, 16-bit audio (4,800 bytes), as required by the API.
private final class AudioPCMAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private let minimumBytes: Int
    private var pending = Data()

    init(minimumBytes: Int) {
        self.minimumBytes = minimumBytes
    }

    func append(_ data: Data) -> [Data] {
        lock.lock()
        defer { lock.unlock() }
        pending.append(data)
        var chunks: [Data] = []
        while pending.count >= minimumBytes {
            // Copy the slice before mutating `pending`. Keeping a live
            // Data.SubSequence while removing bytes from its source can
            // trigger an exclusivity trap in Swift's runtime.
            chunks.append(Data(pending.prefix(minimumBytes)))
            pending.removeFirst(minimumBytes)
        }
        return chunks
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
    @State private var cloudMode: PrototypeCloudTranscriptionMode = .liveStream

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
                if transcription.provider == .openAICloud {
                    Picker(localization.localized("utilities.modeLabel"), selection: $cloudMode) {
                        ForEach(PrototypeCloudTranscriptionMode.allCases) { mode in
                            Text(localization.localized(mode.titleKey)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    LabeledContent(
                        localization.localized("utilities.selectedModel"),
                        value: cloudMode == .liveStream
                            ? aiSettings.audioStreamModelID
                            : aiSettings.audioTranscriptModelID
                    )
                    .font(.caption)
                }
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
                        if transcription.isRecording {
                            transcription.stop()
                        } else {
                            transcription.start(
                                languageTag: languageSettings.targetLanguageTag,
                                aiSettings: aiSettings,
                                cloudMode: cloudMode
                            )
                        }
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
