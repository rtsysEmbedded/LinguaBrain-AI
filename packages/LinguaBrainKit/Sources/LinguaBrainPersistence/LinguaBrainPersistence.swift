import Foundation
import LinguaBrainDomain
import LinguaBrainApplication

// MARK: - Default PersistenceProvider (T015)

/// A deferred persistence seam that routes through the injected `PersistencePort`.
/// The app wires a concrete GRDB/SQLite backend here in production (ADR-003); the
/// package ships an in-memory implementation for application tests and the MVP slice.
public struct DefaultPersistenceProvider {
    public let port: PersistencePort

    public init(port: PersistencePort) {
        self.port = port
    }
}
