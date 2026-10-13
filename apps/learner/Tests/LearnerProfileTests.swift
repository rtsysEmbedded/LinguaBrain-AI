import XCTest
@testable import LinguaBrain

@MainActor
final class LearnerProfileTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suite = "LearnerProfileTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
        return defaults
    }

    func testNewProfileUsesConfiguredDefaults() {
        let rules = LearningContentRules.bundled
        let profile = PrototypeLearnerProfile(defaults: makeDefaults())
        XCTAssertEqual(profile.currentLevel, rules.onboarding.defaultLevel)
        XCTAssertEqual(profile.dailyGoalMinutes, rules.learnerProfile.defaultDailyGoalMinutes)
        XCTAssertEqual(profile.playbackRate, rules.learnerProfile.playbackRate.defaultValue)
        XCTAssertFalse(profile.onboardingCompleted)
    }

    func testChoicesPersistAcrossInstances() {
        let defaults = makeDefaults()
        let profile = PrototypeLearnerProfile(defaults: defaults)
        profile.currentLevel = "A2"
        profile.dailyGoalMinutes = 30
        profile.playbackRate = 0.8
        profile.onboardingCompleted = true

        let restored = PrototypeLearnerProfile(defaults: defaults)
        XCTAssertEqual(restored.currentLevel, "A2")
        XCTAssertEqual(restored.dailyGoalMinutes, 30)
        XCTAssertEqual(restored.playbackRate, 0.8, accuracy: 0.0001)
        XCTAssertTrue(restored.onboardingCompleted)
        XCTAssertEqual(PrototypeLearnerProfile.storedDailyGoalMinutes(defaults: defaults), 30)
    }

    func testInvalidStoredValuesFallBackOrAreClamped() {
        let defaults = makeDefaults()
        defaults.set("Z9", forKey: "prototype.learner.currentLevel")
        defaults.set(7, forKey: "prototype.learner.dailyGoalMinutes")
        defaults.set(9.0, forKey: "prototype.learner.playbackRate")
        let rules = LearningContentRules.bundled
        let profile = PrototypeLearnerProfile(defaults: defaults)
        XCTAssertEqual(profile.currentLevel, rules.onboarding.defaultLevel)
        XCTAssertEqual(profile.dailyGoalMinutes, rules.learnerProfile.defaultDailyGoalMinutes)
        XCTAssertEqual(profile.playbackRate, rules.learnerProfile.playbackRate.maximum)
    }

    func testDailyGoalMapsToTodayTimeChoice() {
        let plan = LearningContentRules.bundled.dailyPlan
        for goal in LearningContentRules.bundled.learnerProfile.dailyGoalMinuteOptions {
            let minutes = plan.availableMinutes(forDailyGoal: goal)
            XCTAssertTrue(plan.availableMinuteOptions.contains(minutes))
            XCTAssertLessThanOrEqual(minutes, max(goal, plan.availableMinuteOptions.min() ?? goal))
        }
        XCTAssertEqual(plan.availableMinutes(forDailyGoal: plan.defaultAvailableMinutes), plan.defaultAvailableMinutes)
    }

    func testMissionAndTargetLevelAreStoredAsTheActiveMission() {
        let store = PrototypeStore(inMemory: true)
        let rules = LearningContentRules.bundled
        XCTAssertEqual(store.activeMissionKey, rules.onboarding.defaultMissionKey)
        XCTAssertEqual(store.activeTargetLevel, rules.learnerProfile.defaultTargetLevel)

        let mission = rules.onboarding.missionKeys.last!
        store.setActiveMissionKey(mission)
        store.setActiveTargetLevel("C1")
        XCTAssertEqual(store.activeMissionKey, mission)
        XCTAssertEqual(store.activeTargetLevel, "C1")
        XCTAssertEqual(store.activeMission?.targetLevel, "C1")
    }

    func testSpeechRateStaysWithinSynthesizerRange() {
        let profile = PrototypeLearnerProfile(defaults: makeDefaults())
        profile.playbackRate = LearningContentRules.bundled.learnerProfile.playbackRate.maximum
        XCTAssertLessThanOrEqual(profile.speechRate(base: 1), 1)
        profile.playbackRate = 1
        XCTAssertEqual(profile.speechRate(base: 0.45), 0.45, accuracy: 0.0001)
    }
}
