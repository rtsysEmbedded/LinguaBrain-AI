import Foundation
import LinguaBrainDomain

public actor ListeningPracticeService {
    private let session: PracticeSessionService
    public init(session: PracticeSessionService) { self.session=session }
    public func prepare(exercise: ExerciseInstance) async throws -> PracticeSessionSnapshot { try await session.prepare(exercise: exercise) }
    public func submit(exercise: ExerciseInstance, response: String) async throws -> Attempt { try await session.submit(exercise: exercise, response: response) }
}
