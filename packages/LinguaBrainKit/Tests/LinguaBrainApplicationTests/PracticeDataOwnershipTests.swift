import XCTest
@testable import LinguaBrainApplication
import LinguaBrainDomain

final class PracticeDataOwnershipTests: XCTestCase {
    func testExportContainsPracticeEvidenceButNoProviderSecrets() async throws {
        let store = OwnershipStore(export: PracticeDataExport(learnerID: "learner", attempts: [fixtureAttempt()]))
        let service = PracticeDataOwnershipService(store: store)
        let export = try await service.export(learnerID: "learner")
        XCTAssertEqual(export.attempts.count, 1)
        XCTAssertFalse(String(data: try JSONEncoder().encode(export), encoding: .utf8)!.contains("credential"))
    }

    func testDeletionIsExplicitAndConsentBlocksNewProviderRequests() async throws {
        let store = OwnershipStore(export: PracticeDataExport(learnerID: "learner"), consent: false)
        let service = PracticeDataOwnershipService(store: store)
        await XCTAssertThrowsErrorAsync(try await service.requireProviderConsent(learnerID: "learner")) { error in
            XCTAssertEqual(error as? PracticeDataOwnershipError, .consentRequired)
        }
        try await service.deletePrivateData(learnerID: "learner")
        let deleted = await store.deleted
        XCTAssertTrue(deleted)
    }

    private func fixtureAttempt() -> Attempt {
        let unit = ReviewUnit(learnerID: "learner", skill: .writing, objectiveKey: "objective")
        return Attempt(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, sessionID: nil, exerciseID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, reviewUnitID: unit.id, response: "Ich lerne.", submittedAt: Date(timeIntervalSince1970: 1), attemptIndex: 0, idempotencyKey: nil, outcome: .correct)
    }
}

private actor OwnershipStore: PracticeDataOwnershipStore {
    let exportValue: PracticeDataExport
    let consent: Bool
    private(set) var deleted = false
    init(export: PracticeDataExport, consent: Bool = true) { self.exportValue = export; self.consent = consent }
    func exportPracticeData(learnerID: String) async throws -> PracticeDataExport { exportValue }
    func deletePrivatePracticeData(learnerID: String) async throws { deleted = true }
    func isProviderConsentGranted(learnerID: String) async -> Bool { consent }
}

private func XCTAssertThrowsErrorAsync(_ expression: @autoclosure () async throws -> Void, handler: (Error) -> Void) async {
    do { try await expression(); XCTFail("Expected an error") } catch { handler(error) }
}
