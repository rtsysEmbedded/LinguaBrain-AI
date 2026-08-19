import XCTest
@testable import LinguaBrain

@MainActor
final class GenerationPrototypeIntegrationTests: XCTestCase {

    // T018: an app-level generation + approval journey drives the orchestrator and
    // persists the approved bundle through the application/persistence boundary, then
    // reads it back (restart proof).
    func testGenerateApproveAndReloadThroughBoundary() async throws {
        let model = GenerationPrototypeModel()
        model.topic = "Bank"
        model.sourceLanguage = "de"
        model.targetLanguage = "fa"

        model.generate()
        // Wait for the asynchronous generation used by the UI.
        await waitUntil(timeout: 5) { !model.isGenerating && model.currentProposal != nil }
        let proposal = try XCTUnwrap(model.currentProposal)
        XCTAssertEqual(proposal.sourceLanguage, "de")
        XCTAssertEqual(proposal.targetLanguage, "fa")
        XCTAssertEqual(model.cards.count, proposal.senses.count * directionCount)

        // Approve each reviewable card.
        let ids = model.cards.map(\.id)
        for id in ids { model.approve(id) }
        await waitUntil(timeout: 5) {
            model.cards.allSatisfy { $0.state == .approved }
        }
        XCTAssertEqual(model.approvedCount, model.cards.count)

        // Reload approved bundles back through the boundary.
        let persisted = await model.reloadPersisted()
        XCTAssertGreaterThanOrEqual(persisted, 1)
    }

    func testRejectedCardIsNotApproved() async throws {
        let model = GenerationPrototypeModel()
        model.topic = "Bank"
        model.generate()
        await waitUntil(timeout: 5) { model.currentProposal != nil }

        if let first = model.cards.first {
            model.reject(first.id)
            await waitUntil(timeout: 5) {
                model.cards.contains { $0.id == first.id && $0.state == .rejected }
            }
        }
        // No approved bundle should exist yet.
        let persisted = await model.reloadPersisted()
        XCTAssertEqual(persisted, 0)
    }

    // MARK: Helpers

    var directionCount: Int { 2 } // recognition + recall

    func waitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}
