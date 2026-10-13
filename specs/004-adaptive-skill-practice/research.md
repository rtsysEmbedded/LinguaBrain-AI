# Feature 004 research record

The local toolchain is Xcode 27.0 build 27A5228h with the macOS 27.0 SDK, matching the repository baseline. T005 deliberately does not add SwiftData or a second production store. The current slice defines storage and migration contracts while the GRDB-backed adapter remains the integration dependency governed by ADR-003.

## T002 contract-and-cutover audit — 2026-09-04

The written contract now uses `practice-evidence-v1`: scores and confidence are bounded to `[0, 1]`, `partial` is distinct from `incorrect`, and `ungradable` is persisted as `unavailable`. The fixed-clock examples in `data-model.md` and `contracts/practice.md` are deterministic scheduler-fixture values, not unverified claims about the prototype scheduler.

The implementation boundary is split deliberately. `PracticeSessionService.swift` exists and owns preparation, submission, request generations, first-attempt retention, stale-result rejection, and provider failure/cancellation handling. There is no `PracticeReviewService.swift`; the session service does not own mastery or FSRS. The current `PracticeEvidencePolicy` only returns a binary eligible contribution (`1` for independent correct and `0` otherwise). Therefore partial scoring, skip persistence, reveal-before-submit persistence, retry-event persistence, idempotent repeated continue, and the atomic mastery/FSRS application transaction remain open implementation gaps under T004/T006/T007. T002 documents these gaps rather than claiming them complete.

### Legacy cutover audit

The bridge reads the deterministic `PrototypeStore.persistentStoreURL` with `allowsSave: false`, after copying the main store and present `-wal`, `-shm`, or `-journal` sidecars into a hashed backup manifest. It stages the complete relevant card fields and only recognition/reverse review, mastery, and learning-event evidence. In-memory `grades`, `dueDates`, and `memoryStates` are projections and are not migrated as independent history. New writing, grammar, listening, and speaking units are unknown with no inherited mastery, due date, attempt, or FSRS state.

The source and backup have no automatic expiry or deletion. The current receipt is runtime state and the retained files are the recovery authority; a durable retention-window marker and a later explicit deletion decision are still required before removal. No live store was opened or changed during verification; app tests use synthetic SwiftData stores.

### Completion correction

T001 remains verified. T005 remains verified independently by its GRDB adapter and transaction tests. T006 is reopened: its migration bridge evidence is valid, but the task's named `PracticeReviewService.swift` path and its pinned scheduling/application boundary are not present. The task path now points to the actual `PracticeSessionService.swift` for session behavior and records that this is not a substitute for the missing review/scheduler owner. T002 is complete as a contract task because the acceptance matrix, numeric policy, mapping, recovery policy, and implementation gaps are explicit and traceable.
