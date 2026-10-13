import Foundation
import LinguaBrainApplication
import LinguaBrainDomain

public struct ListeningEvaluationRequest: Sendable, Equatable { public let sentence: Sentence; public let audioChecksum: String; public let response: String; public init(sentence: Sentence, audioChecksum: String, response: String) { self.sentence=sentence; self.audioChecksum=audioChecksum; self.response=response } }
public protocol ListeningEvaluationTransport: Sendable { func evaluate(_ request: ListeningEvaluationRequest) async throws -> EvaluationResult }
public struct ListeningEvaluationContext: Sendable, Equatable {
    public let sentence: Sentence
    public let audioChecksum: String
    public init(sentence: Sentence, audioChecksum: String) { self.sentence = sentence; self.audioChecksum = audioChecksum }
}
public protocol ListeningEvaluationContextResolving: Sendable {
    func context(for exercise: ExerciseInstance) async throws -> ListeningEvaluationContext
}
public struct ListeningEvaluationProvider: PracticeEvaluator, Sendable {
    private let transport: any ListeningEvaluationTransport
    private let contextResolver: any ListeningEvaluationContextResolving
    public init(transport: any ListeningEvaluationTransport, contextResolver: any ListeningEvaluationContextResolving) {
        self.transport = transport
        self.contextResolver = contextResolver
    }
    public func evaluate(_ attempt: Attempt, exercise: ExerciseInstance) async throws -> EvaluationResult {
        guard !attempt.response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PracticeEvaluationError.malformedOutput }
        do {
            let context = try await contextResolver.context(for: exercise)
            guard let expectedID = exercise.reviewUnit.sentenceID,
                  let expectedRevision = exercise.reviewUnit.sentenceRevision,
                  context.sentence.id == expectedID,
                  context.sentence.revision == expectedRevision,
                  !context.sentence.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !context.audioChecksum.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PracticeEvaluationError.malformedOutput
            }
            let result = try await transport.evaluate(ListeningEvaluationRequest(sentence: context.sentence, audioChecksum: context.audioChecksum, response: attempt.response))
            return result.normalized()
        }
        catch is CancellationError { throw PracticeEvaluationError.cancelled }
        catch let error as PracticeEvaluationError { throw error }
        catch { throw PracticeEvaluationError.transportFailure }
    }
}
