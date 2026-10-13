import AVFAudio
import Foundation
import LinguaBrainApplication

enum ApplePracticeRecorderError: Error, Equatable {
    case permissionDenied
    case alreadyRecording
    case couldNotStart
    case recordingFailed
    case cancelled
}

struct ApplePracticeRecordingMetadata: Sendable, Equatable {
    let sampleRate: Double
    let channelCount: Int
    let maximumDuration: TimeInterval
    let retained: Bool
}

/// File-backed Apple recorder with temporary-by-default ownership. Completion
/// comes from AVAudioRecorderDelegate, never from a guessed sleep interval.
@MainActor
final class ApplePracticeRecorder: NSObject, @preconcurrency PracticeRecording, @preconcurrency AVAudioRecorderDelegate {
    private let maximumDuration: TimeInterval
    private let retainRecording: Bool
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var continuation: CheckedContinuation<Data, Error>?
    private var currentURL: URL?
    private(set) var lastRecording: Data?
    private(set) var metadata: ApplePracticeRecordingMetadata

    init(maximumDuration: TimeInterval = 30, retainRecording: Bool = false) {
        self.maximumDuration = min(max(maximumDuration, 1), 120)
        self.retainRecording = retainRecording
        self.metadata = ApplePracticeRecordingMetadata(sampleRate: 44_100, channelCount: 1, maximumDuration: min(max(maximumDuration, 1), 120), retained: retainRecording)
    }

    func record() async throws -> Data {
        guard continuation == nil else { throw ApplePracticeRecorderError.alreadyRecording }
        guard await requestPermission() else { throw ApplePracticeRecorderError.permissionDenied }
        try Task.checkCancellation()

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)
        #endif

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("practice-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        guard recorder.prepareToRecord(), recorder.record(forDuration: maximumDuration) else {
            try? FileManager.default.removeItem(at: url)
            throw ApplePracticeRecorderError.couldNotStart
        }
        self.recorder = recorder
        currentURL = url

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel() }
        }
    }

    func stop() { recorder?.stop() }

    func cancel() {
        recorder?.delegate = nil
        recorder?.stop()
        recorder = nil
        cleanupCurrentFile()
        continuation?.resume(throwing: ApplePracticeRecorderError.cancelled)
        continuation = nil
    }

    func replayLastRecording() throws {
        guard let lastRecording else { throw ApplePracticeRecorderError.recordingFailed }
        player?.stop()
        player = try AVAudioPlayer(data: lastRecording)
        player?.prepareToPlay()
        guard player?.play() == true else { throw ApplePracticeRecorderError.recordingFailed }
    }

    func stopPlayback() { player?.stop(); player = nil }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        self.recorder = nil
        guard flag, let url = currentURL, let data = try? Data(contentsOf: url), !data.isEmpty else {
            cleanupCurrentFile()
            continuation?.resume(throwing: ApplePracticeRecorderError.recordingFailed)
            continuation = nil
            return
        }
        lastRecording = data
        if !retainRecording { cleanupCurrentFile() }
        continuation?.resume(returning: data)
        continuation = nil
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        self.recorder = nil
        cleanupCurrentFile()
        continuation?.resume(throwing: error ?? ApplePracticeRecorderError.recordingFailed)
        continuation = nil
    }

    private func requestPermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
            }
        @unknown default: return false
        }
    }

    private func cleanupCurrentFile() {
        if let currentURL { try? FileManager.default.removeItem(at: currentURL) }
        currentURL = nil
    }

    deinit {
        if let currentURL { try? FileManager.default.removeItem(at: currentURL) }
    }
}
