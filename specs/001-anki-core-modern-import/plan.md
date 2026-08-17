# Implementation Plan: Anki Core Modern Import and Offline Review Gate

**Feature**: `001-anki-core-modern-import`

**Status**: Active — foundational reader and reconciliation contracts approved

**Specification**: [spec.md](spec.md)

## Summary

Extend the native APKG boundary to modern collections and complete a deterministic import/re-import path feeding the existing offline FSRS review flow. Preserve current security preflight and legacy behavior while moving format parsing, reconciliation, persistence, and UI orchestration behind testable boundaries.

## Technical Context

- Swift 6.4 and SwiftUI on iOS/iPadOS 27 and macOS 27.
- Current app: `apps/learner/LinguaBrain.xcodeproj`.
- Existing SwiftData prototype with a production transition to GRDB 7/system SQLite accepted by ADR-003.
- Pinned FSRS-6 contract from ADR-004.
- No network or AI dependency.
- Unit fixtures, persistence integration tests, fake-clock vectors, and cross-target builds.

## Constitution Check

| Gate | Result | Evidence / action |
| --- | --- | --- |
| Specification and ADR traceability | Pass | Links ADR-012 and Anki Core MVP spec. |
| Anki Core before expansion | Pass | This is the active product gate. |
| Deterministic/no-AI core | Pass | Import/review require no AI. |
| Local-first privacy | Pass | Source inspection is local and read-only. |
| Stable identity/auditability | Planned | Finalize provenance and reconciliation contracts. |
| Native boundaries/portable semantics | Planned | Move parsing/reconciliation outside SwiftUI. |
| Evidence before completion | Planned | Fixtures, restart tests, builds, security review. |

## Proposed Boundaries

1. Archive inspection validates entries and selects a supported collection candidate without mutation.
2. Collection reader exposes normalized Anki deck/model/note/card/media records independent of database details.
3. Mapping service converts normalized records to LinguaBrain proposals and lexical senses.
4. Reconciliation service compares provenance identities and learner-owned changes.
5. Import transaction atomically commits accepted operations and an import report.
6. Review application service uses the same ReviewUnit/FSRS contracts as manual cards.
7. SwiftUI feature model coordinates preview, confirmation, progress, recovery, and reporting only.

## Project Structure

The production destination is the `LinguaBrainKit` package in ADR-010:

```text
packages/LinguaBrainKit/Sources/
├── LinguaBrainDomain/
├── LinguaBrainApplication/
├── LinguaBrainPersistence/
├── LinguaBrainReviewFSRS/
└── LinguaBrainTestSupport/
```

Until this package exists, implementation MUST avoid deepening view-owned business logic and SHOULD extract seams that migrate directly into it. ADR-003 fixes the persistence topology; ADR-007 still gates production data protection/recovery, while format research and fixture work may proceed independently.

## Verification Strategy

- Archive-limit, schema-normalization, field-mapping, sanitization, identity, and reconciliation unit tests.
- Legacy and modern golden fixtures plus hostile/corrupt fixtures.
- Rollback, idempotent re-import, learner-edit preservation, and restart integration tests.
- Fake-clock Again/Hard/Good/Easy tests with independent recognition/reverse states.
- iOS Simulator and macOS `xcodebuild`, followed by semantic smoke verification.

## Risks and Mitigations

- **Modern schema/compression variance**: isolate readers, pin fixtures, reject unsupported variants explicitly.
- **Prototype persistence coupling**: follow ADR-003's one-time SwiftData compatibility-import and module boundaries; dual-write is prohibited.
- **Identity collision**: combine provenance with stable source identifiers; never key senses by spelling alone.
- **Media abuse**: validate name, type, size, count, and ownership before materialization.
- **Review regression**: capture current behavior in tests before refactoring.

## Required Decisions

- Implement the accepted ADR-003 production persistence boundary and compatibility-import contract.
- Implement the approved normalized reader, provenance identity, reconciliation, and conflict contracts in [data-model.md](data-model.md) and [contracts](contracts/).
- Implement the modern package baseline pinned in [research.md](research.md): metadata version 3, `collection.anki21b`, schema 18, bounded inner Zstandard decoding, protobuf media mapping, and owned reproducible fixtures.

## Complexity Tracking

No constitution exception is requested. Any new decoder/database dependency requires documented selection, license, security implications, and fallback behavior.
