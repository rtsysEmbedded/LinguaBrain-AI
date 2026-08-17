---
title: Swift Persistence and Migration Stack
adr_id: ADR-003
status: accepted
date: 2026-08-17
decision_owners: Persistence Lead and Architecture
---

# ADR-003 — Swift Persistence and Migration Stack

## Context

LinguaBrain needs a local source of truth that can support more than simple object persistence. The accepted schema and delivery plan require:

- atomic multi-table review, mastery, event, projection, import, and outbox updates;
- explicit ordered migrations, rollback evidence, backup/restore, and schema inspection;
- stable uniqueness and foreign-key constraints;
- deterministic APKG re-import and high-volume batch writes;
- indexed German/Persian search and SQLite FTS where appropriate;
- append-only learning history and rebuildable projections;
- background reads/writes without putting database objects on the main actor;
- in-memory and file-backed integration tests using the same SQL semantics;
- future event-based synchronization without making CloudKit or an account mandatory;
- domain/application targets that do not import a persistence framework.

The current visual prototype uses SwiftData directly inside `PrototypeStore`. That checkpoint proved restart persistence and the review interaction, but it is not the accepted production repository boundary. The production choice must preserve the prototype learner's data during transition and must not let SwiftUI, `ModelContext`, SQL rows, or persistence annotations leak into domain contracts.

## Decision

LinguaBrain will use **SQLite through GRDB 7** as the native local persistence/query/migration stack.

- Swift Package Manager consumes the `GRDB` product from `https://github.com/groue/GRDB.swift.git` with an explicit compatible 7.x requirement; `Package.resolved` pins the exact reviewed release for reproducible builds.
- Production app stores use `DatabasePool` and WAL to allow concurrent reads with serialized writes.
- Unit/integration tests may use an in-memory `DatabaseQueue`; file-backed migration, restart, WAL, backup, and recovery tests remain mandatory.
- The operating-system SQLite library is used initially. A custom SQLite build, SQLCipher, or another codec is not implied by this ADR.
- `DatabaseMigrator` owns monotonically named, ordered schema migrations. Migrations run before repositories become available; a failed migration prevents normal store use and enters a recoverable repair/restore flow.
- Foreign keys are enabled and checked. Required uniqueness, checks, indexes, and normalized fields are physical database constraints in addition to domain validation.
- GRDB record/row types are private implementation DTOs inside `LinguaBrainPersistence`. Repository adapters explicitly map them to domain entities and value objects.
- SQL and GRDB query interfaces remain inside the persistence target. SwiftUI views and presentation models do not import GRDB or GRDBQuery.
- Application use cases define transaction boundaries. The persistence adapter exposes one database-writer gateway and executes each command's writes in one transaction; UI success is emitted only after commit.
- Search uses ordinary indexes first and an FTS5 external-content/contentless design when approved by measured query requirements. Search indexes are derived and rebuildable.
- Backup uses a transactionally consistent SQLite backup plus the referenced-media manifest. Destructive/transformative migrations require a verified pre-migration backup under the future protection/recovery policy.

## Concurrency model

The database pool is created once by the application composition root and injected through repository/application ports. Database access uses GRDB's synchronous or asynchronous reader/writer APIs from non-UI services; database handles, rows, cursors, and transaction closures never escape their access scope.

Repository protocols remain `Sendable` where their contracts permit. Long APKG imports and projection rebuilds execute away from `@MainActor`; only resulting immutable DTOs or feature state updates cross back to the UI actor. Cancellation is observed at safe boundaries and never exposes a half-committed transaction.

## Migration and compatibility policy

Every persistent schema change includes:

1. a new immutable migration identifier;
2. forward migration from every supported prior schema;
3. fixture-based migration tests and referential-integrity checks;
4. rollback/restore behavior for failure;
5. updates to export, deletion, backup, and sync projections when affected.

Released migration bodies are not edited after publication. Corrective work adds a new migration. Migrations are forward-only in normal operation; restoring an older app requires restoring a compatible backup, not reverse-running SQL.

The existing SwiftData prototype store receives a **one-time compatibility import**, not a live dual-write architecture:

- before cutover, create/verify the new GRDB store and preserve the legacy store;
- copy stable cards, lexical-sense fields, source provenance, review history, and independent recognition/reverse FSRS state in one controlled operation;
- validate counts, identities, algorithm versions, due dates, and representative content before marking cutover complete;
- retain the legacy store until successful verification and a documented recovery window;
- retry idempotently after interruption and never seed/reset over recoverable learner data.

No production feature writes to both SwiftData and GRDB. After verified cutover, SwiftData models are removed from the runtime composition and retained only in migration/test support for the documented compatibility window.

## Schema ownership and versioning

- Document 12 remains the logical schema contract.
- SQL migrations and persistence records are the physical adapter.
- Domain identifiers, event versions, FSRS algorithm versions, content revisions, tombstones, and import provenance remain explicit columns/contracts rather than opaque encoded blobs where queried or constrained.
- Flexible language/provider metadata may remain versioned JSON only when Document 12/DOC-16 permits it and validation plus size/depth limits exist.
- The local database has its own schema/application metadata in addition to GRDB's migration tracking so backup/export diagnostics can identify compatibility before opening user data.

## Security boundary

This ADR selects storage mechanics, not the final at-rest protection design. ADR-007 must still decide Apple Data Protection/file attributes, macOS sandbox behavior, Keychain-held secrets or keys, SQLCipher justification, backup protection, recovery, and lost-key behavior before private production learner data is accepted.

Regardless of ADR-007:

- secrets and API keys never enter this database;
- all dynamic SQL values are bound parameters or GRDB query-interface values;
- logs exclude raw private response content and credentials;
- database, WAL, SHM, backups, and media receive a consistent protection policy;
- corruption and failed migration are surfaced as recoverable states, never handled by silent deletion/reseeding.

## Alternatives considered

### SwiftData as the production store

Rejected for the production adapter. SwiftData provides Apple-native model containers, model actors, and schema migration plans and remains suitable for the visual prototype. For LinguaBrain, however, direct persisted models would add unnecessary coupling while explicit SQL constraints, FTS, import/reconciliation queries, outbox/event operations, migration fixtures, and cross-runtime schema visibility are central requirements.

### Core Data directly

Rejected. It is mature and supports migration/concurrency, but its managed-object model and tooling do not provide enough advantage over an explicit relational contract for this SQL- and import-heavy product. It also increases the risk that managed objects become application/domain types.

### Direct SQLite C API

Rejected as the primary adapter. It offers maximum control and is already appropriate for read-only Anki source inspection, but production use would require the project to build and maintain connection serialization, Swift concurrency safety, migrations, row decoding, observation, cancellation, backup wrappers, and error mapping already provided by GRDB.

### SQLite.swift or another query wrapper

Not selected. The evaluated project requirements favor GRDB's migration, transaction, concurrency, observation, FTS, backup, and testing surface plus active Swift 6 support. A future replacement remains possible behind repository contracts but requires a new ADR and migration plan.

### CloudKit/SwiftData automatic sync as persistence

Rejected. Optional accounts and domain-specific event merging under ADR-014 cannot be made an implicit side effect of the local object store. Synchronization remains an application/service adapter over stable events, versions, tombstones, and idempotency keys.

## Consequences

### Positive

- The logical relational schema maps directly to explicit, inspectable SQLite structures.
- Atomic review/import/outbox transactions and deterministic re-import are straightforward to test.
- Migrations, foreign keys, FTS, backup, observation, and concurrency have established APIs.
- Domain and application code remain storage-independent and testable without Apple UI frameworks.
- A future dedicated device or service can share versioned schema/event semantics without adopting SwiftData.

### Costs and risks

- GRDB is a third-party dependency whose exact version and license must be tracked and upgraded deliberately.
- The team owns SQL schema quality and migration correctness.
- SwiftData prototype data needs a tested one-time compatibility importer.
- `DatabasePool` and WAL require coordinated backup/protection of database, `-wal`, and `-shm` files.
- SQLCipher or stronger at-rest encryption remains unresolved until ADR-007.

## Acceptance evidence

Before the production persistence gate closes:

- `LinguaBrainPersistence` builds as a SwiftPM target using the pinned GRDB 7 release.
- Domain/application tests run without GRDB, SwiftData, SwiftUI, simulator, or network.
- File-backed and in-memory repository contract suites pass.
- A migration fixture from the previous supported schema upgrades with expected rows, constraints, and indexes.
- An injected migration/import/review failure leaves no partial committed state.
- A completed review transaction and APKG import survive process restart.
- The SwiftData compatibility import preserves cards, provenance, review directions, FSRS state, and due dates without uncontrolled duplication.
- iPhone, iPad, and Mac open the same schema version and pass the semantic persistence suite.
- Dependency/license inventory records the exact GRDB release; vulnerability and upgrade checks are part of release maintenance.

## References

- [GRDB repository and documentation](https://github.com/groue/GRDB.swift)
- [GRDB 7 migration guide](https://github.com/groue/GRDB.swift/blob/master/Documentation/GRDB7MigrationGuide.md)
- [Apple SwiftData ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer)
- [Apple SwiftData ModelActor](https://developer.apple.com/documentation/swiftdata/modelactor)
- [ADR-010 — Swift Package and Module Layout](ADR-010-Swift-Package-and-Module-Layout.md)
- [ADR-012 — Anki Core First and APKG Import Boundary](ADR-012-Anki-Core-First-and-APKG-Import-Boundary.md)
- [Document 12 — Database Schema and Persistence](../docs/12_Database_Schema_and_Persistence.md)
