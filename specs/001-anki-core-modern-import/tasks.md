# Tasks: Anki Core Modern Import and Offline Review Gate

**Status**: Active

**Format**: `[ID] [P?] [Story] Description (scope; verification)`

## Phase 1 — Baseline and decisions

- [x] T001 Capture current legacy import and offline-review behavior with regression tests and sanitized fixtures.
- [x] T002 [P] Decide and record the production Swift persistence/query/migration adapter in ADR-003.
- [x] T003 [P] Research supported `collection.anki21b` variants, constraints, and fixture provenance in `research.md`.
- [x] T004 Approve normalized reader, provenance identity, reconciliation, and conflict contracts in `data-model.md` and `contracts/`.

## Phase 2 — Safe modern inspection and reading

- [ ] T005 [P] [US1] Add modern valid/corrupt/hostile golden fixtures without personal learner data.
- [ ] T006 [US1] Implement bounded archive inspection for approved modern entries while preserving legacy checks.
- [ ] T007 [US1] Implement normalized modern reading for decks, models, notes, cards, fields, templates, and tags.
- [ ] T008 [P] [US1] Implement validated media-manifest mapping and resource ownership.
- [ ] T009 [US1] Extend preview/report UI state with compatibility, warnings, counts, and explicit confirmation.

## Phase 3 — Deterministic reconciliation and transaction

- [ ] T010 [US2] Implement stable package/source identities and migrate prototype provenance.
- [ ] T011 [US2] Implement inserted/updated/skipped/conflict reconciliation preserving learner edits and review state.
- [ ] T012 [US1] Commit records, media ownership, and import report in one rollback-safe transaction.
- [ ] T013 [US2] Verify confirmed package removal against the new ownership model without deleting the APKG source.

## Phase 4 — Offline review gate

- [ ] T014 [US3] Route imported cards through stable LexicalSense, ReviewUnit, and independent recognition/reverse contracts.
- [ ] T015 [US3] Verify atomic four-rating FSRS persistence, due timing, session summary, and restart with a fake clock.
- [ ] T016 [US3] Run the import/review journey and builds on iPhone/iPad and Mac without network or AI credentials.

## Phase 5 — Convergence

- [ ] T017 Run Spec Kit consistency analysis and resolve critical discrepancies.
- [ ] T018 Update project status, changelog, affected documents, and decision register with evidence.
- [ ] T019 Perform staged-file security review, full relevant verification, and handoff with commit SHA and risks.

## Dependencies and Parallel Work

- T001–T004 are foundational. T005 may run with decision work if its format is not treated as final.
- T006 precedes T007. T008 may run with T007 only with separate file ownership.
- T010 precedes T011/T013. T007, T008, T010, and T011 precede T012.
- T012 and T014 precede T015; all implementation precedes T016–T019.
- `[P]` means potentially parallel, not automatically safe; exact write scope is required.

## Agent Handoff Evidence

For each completed task record the agent/tool, date, changed files, commands/tests, result, known risks, and commit SHA. Never include credentials, private APKG data, or raw learner content.

### T001 — 2026-08-17

- **Agent/tool**: Codex with Xcode 27.0 and XCTest.
- **Changed scope**: iOS unit-test target, sanitized JSON fixture, runtime SQLite/APKG fixture factory, regression tests, and project/status documentation.
- **Evidence**: Three tests passed on the iPhone 17 iOS 27 simulator: legacy APKG inspection/field mapping, source-identity re-import update plus semantic duplicate skip, and independent direct/reverse review scheduling with due-time enforcement.
- **Compatibility check**: `LinguaBrain Mac` generic macOS build passed with signing disabled.
- **Known boundary**: T001 locks the currently supported legacy path; modern `collection.anki21b`, hostile fixture expansion, restart persistence vectors, and full reconciliation remain assigned to later tasks.
- **Commit**: see the T001 completion commit in Git history; its SHA is included in the handoff response.

### T002 — 2026-08-17

- **Agent/tool**: Codex; local architecture/specification audit plus official Apple SwiftData and GRDB project documentation.
- **Decision**: Accepted ADR-003 selects GRDB 7 over system SQLite, production `DatabasePool`, in-memory `DatabaseQueue` tests, explicit `DatabaseMigrator` migrations, private persistence DTOs, and repository/transaction mapping.
- **Compatibility**: The current SwiftData prototype receives a one-time verified, idempotent compatibility import; production dual-write is prohibited and learner data must never be silently reset.
- **Deferred security boundary**: SQLCipher, Apple Data Protection, backup keys, and lost-key recovery remain explicitly owned by ADR-007.
- **Consistency evidence**: Decision Register, ADR index, Documents 11/12/15, README, project status, and changelog were aligned; register counts were independently recomputed.
- **Commit**: see the T002 completion commit in Git history; its SHA is included in the handoff response.

### T003 — 2026-08-17

- **Agent/tool**: Codex; official Anki source/manual research pinned to upstream commit `967aa0d578fc75181e292e95326f9b58698da25c`.
- **Changed scope**: Added `research.md` with the version-selection contract, ZIP/Zstandard layers, schema-18 implications, protobuf media mapping, compatibility matrix, security requirements, and fixture provenance policy.
- **Key finding**: Latest `collection.anki21b`, its protobuf media manifest, and each numbered media payload are internally Zstandard-compressed; outer ZIP limits alone cannot bound decoded expansion.
- **Compatibility boundary**: Legacy schema 11 remains supported; metadata version 3/schema 18 is the next target; malformed, ambiguous, unknown/future, unsupported-schema, or unbounded variants remain rejected.
- **Known boundary**: Decoder dependencies, numeric resource limits, normalized records, error taxonomy, and atomic partial/failure behavior require approval in T004 before implementation.
- **Verification**: Markdown/reference audit and comparison against the pinned official source; no runtime code changed.
- **Commit**: see the T003 completion commit in Git history; its SHA is included in the handoff response.

### T004 — 2026-08-17

- **Agent/tool**: Codex; domain/import contract design based on T003 and the accepted LexicalSense/ReviewUnit architecture.
- **Changed scope**: Added the approved data model, normalized reader/resource contract, deterministic reconciliation/conflict contract, and pinned Zstandard/SwiftProtobuf implementation choices; strengthened feature requirements for sense and ownership identity.
- **Identity decision**: Re-import matches by namespaced source identity; semantic candidate keys are non-unique suggestions and spelling alone is never identity.
- **Conflict decision**: Source snapshots, learner overrides, and review evidence are separate; concurrent field changes retain the learner value and all review/FSRS state.
- **Polysemy evidence**: Work, medical, and legal meanings of `entlassen` are specified as independent LexicalSense and ReviewUnit identities.
- **Known boundary**: T005–T008 implement fixtures and readers; T010–T013 implement the approved reconciliation/transaction contracts in production code.
- **Verification**: Markdown consistency, contract cross-links, task/status alignment, and staged diff validation; no runtime code changed.
- **Commit**: see the T004 completion commit in Git history; its SHA is included in the handoff response.
