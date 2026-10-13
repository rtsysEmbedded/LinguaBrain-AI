import AVFAudio
import Foundation
import Observation
import LinguaBrainDomain

/// Learner choices that shape the daily plan and playback. The current
/// level, daily goal, playback rate, and onboarding state are stored in
/// `UserDefaults`; the active mission and its target level are stored by
/// `PrototypeStore` as the domain `LearningMission`.
@MainActor
@Observable
final class PrototypeLearnerProfile {
    private enum Key {
        static let currentLevel = "prototype.learner.currentLevel"
        static let dailyGoalMinutes = "prototype.learner.dailyGoalMinutes"
        static let playbackRate = "prototype.learner.playbackRate"
        static let onboardingCompleted = "prototype.learner.onboardingCompleted"
    }

    private let defaults: UserDefaults

    /// One of `onboarding.levels` in `content-rules.json`.
    var currentLevel: String {
        didSet { defaults.set(currentLevel, forKey: Key.currentLevel) }
    }

    /// One of `learnerProfile.dailyGoalMinuteOptions`.
    var dailyGoalMinutes: Int {
        didSet { defaults.set(dailyGoalMinutes, forKey: Key.dailyGoalMinutes) }
    }

    /// Multiplier within `learnerProfile.playbackRate`.
    var playbackRate: Double {
        didSet { defaults.set(playbackRate, forKey: Key.playbackRate) }
    }

    var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: Key.onboardingCompleted) }
    }

    init(defaults: UserDefaults = .standard) {
        let rules = LearningContentRules.bundled
        self.defaults = defaults
        currentLevel = defaults.string(forKey: Key.currentLevel)
            .flatMap { rules.onboarding.levels.contains($0) ? $0 : nil } ?? rules.onboarding.defaultLevel
        dailyGoalMinutes = Self.storedDailyGoalMinutes(defaults: defaults)
        let rate = rules.learnerProfile.playbackRate
        playbackRate = (defaults.object(forKey: Key.playbackRate) as? Double)
            .map { min(max($0, rate.minimum), rate.maximum) } ?? rate.defaultValue
        onboardingCompleted = defaults.bool(forKey: Key.onboardingCompleted)
    }

    /// The stored daily goal, readable before the environment is available
    /// (for example, to initialize view state).
    nonisolated static func storedDailyGoalMinutes(defaults: UserDefaults = .standard) -> Int {
        let rules = LearningContentRules.bundled.learnerProfile
        return (defaults.object(forKey: Key.dailyGoalMinutes) as? Int)
            .flatMap { rules.dailyGoalMinuteOptions.contains($0) ? $0 : nil } ?? rules.defaultDailyGoalMinutes
    }

    /// A player for card audio at the learner's playback rate.
    func makeAudioPlayer(data: Data) -> AVAudioPlayer? {
        guard let player = try? AVAudioPlayer(data: data) else { return nil }
        player.enableRate = true
        player.rate = Float(playbackRate)
        return player
    }

    /// A speech-synthesis rate scaled by the learner's playback rate and kept
    /// within the synthesizer's supported range.
    func speechRate(base: Float) -> Float {
        min(max(base * Float(playbackRate), AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
    }
}

extension PrototypeStore {
    /// Localization key of the active learning goal (`onboarding.missionKeys`).
    var activeMissionKey: String {
        activeMission?.id ?? LearningContentRules.bundled.onboarding.defaultMissionKey
    }

    var activeTargetLevel: String {
        activeMission?.targetLevel ?? LearningContentRules.bundled.learnerProfile.defaultTargetLevel
    }

    func setActiveMissionKey(_ key: String) {
        setActiveMission(LearningMission(id: key, title: key, domain: activeMission?.domain, targetLevel: activeTargetLevel))
    }

    func setActiveTargetLevel(_ level: String) {
        setActiveMission(LearningMission(id: activeMissionKey, title: activeMissionKey, domain: activeMission?.domain, targetLevel: level))
    }
}
