import Foundation
import LinguaBrainDomain

public actor GrammarPracticeService {
    private let session: PracticeSessionService
    private let evaluator: any PracticeEvaluator
    private var descriptors: [UUID: GrammarExerciseDescriptor] = [:]
    public init(session: PracticeSessionService, evaluator: any PracticeEvaluator) { self.session=session; self.evaluator=evaluator }
    public func prepare(_ descriptor: GrammarExerciseDescriptor) async throws -> PracticeSessionSnapshot { descriptors[descriptor.exercise.id] = descriptor; return try await session.prepare(exercise: descriptor.exercise) }
    public func submit(exerciseID: UUID, explanation: String) async throws -> Attempt {
        guard let descriptor = descriptors[exerciseID] else { throw PracticeSessionError.notPrepared }
        return try await session.submit(exercise: descriptor.exercise, response: explanation, using: evaluator)
    }
}
