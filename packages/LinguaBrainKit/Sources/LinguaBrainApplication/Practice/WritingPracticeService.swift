import Foundation
import LinguaBrainDomain

public struct WritingPracticeSubmission: Codable, Sendable, Equatable {
    public let descriptor: WritingExerciseDescriptor
    public let attempt: Attempt
    public let correctionProposal: EvaluationResult?

    public init(descriptor: WritingExerciseDescriptor, attempt: Attempt, correctionProposal: EvaluationResult?) {
        self.descriptor = descriptor
        self.attempt = attempt
        self.correctionProposal = correctionProposal
    }
}

/// Application orchestration for writing. Exercise retrieval and evaluation
/// are ports; persistence, assistance policy, mastery and scheduling remain
/// owned by the existing session/review services.
public actor WritingPracticeService {
    private let retrieval: any WritingExerciseRetrieval
    private let session: PracticeSessionService
    private var descriptors: [UUID: WritingExerciseDescriptor] = [:]

    public init(retrieval: any WritingExerciseRetrieval, session: PracticeSessionService) {
        self.retrieval = retrieval
        self.session = session
    }

    public func prepare(learnerID: String, cefrLevel: String, seed: Int = 0) async throws -> WritingExerciseDescriptor? {
        guard let descriptor = try await retrieval.nextWritingExercise(learnerID: learnerID, cefrLevel: cefrLevel, seed: seed) else { return nil }
        descriptors[descriptor.exercise.id] = descriptor
        _ = try await session.prepare(exercise: descriptor.exercise)
        return descriptor
    }

    public func submit(exerciseID: UUID, response: String) async throws -> WritingPracticeSubmission {
        guard let descriptor = descriptors[exerciseID] else { throw PracticeSessionError.notPrepared }
        let attempt = try await session.submit(exercise: descriptor.exercise, response: response)
        return WritingPracticeSubmission(descriptor: descriptor, attempt: attempt, correctionProposal: attempt.evaluatorResult.map { result in
            EvaluationResult(
                outcome: result.outcome,
                score: result.score,
                confidence: result.confidence,
                feedback: result.feedback,
                rules: result.rules,
                evaluatorVersion: result.evaluatorVersion,
                provenance: result.provenance,
                unavailableReason: result.unavailableReason,
                attemptID: attempt.id,
                exerciseID: descriptor.exercise.id,
                reviewUnitID: descriptor.exercise.reviewUnit.id,
                sentenceRevision: descriptor.exercise.reviewUnit.sentenceRevision,
                meaningStatus: nil,
                originalLearnerSentence: attempt.response
            )
        })
    }

    public func resume(exerciseID: UUID) async throws -> PracticeSessionSnapshot {
        guard let descriptor = descriptors[exerciseID] else { throw PracticeSessionError.notPrepared }
        return try await session.resume(exercise: descriptor.exercise)
    }
}
