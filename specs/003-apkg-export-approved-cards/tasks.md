# Tasks: Hermes APKG Export for Approved Cards

**Feature**: `003-apkg-export-approved-cards`
**Source artifacts**: `spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`
**Implementation boundary**: Swift 6.4 shared package plus thin SwiftUI app integration.
**Status**: Core infrastructure implemented, tests passing, app integration in progress.

## Phase 1: Setup

- [x] T001 Create `packages/LinguaBrainKit/Sources/LinguaBrainAnkiExport/` and `packages/LinguaBrainKit/Tests/LinguaBrainAnkiExportTests/` targets in `packages/LinguaBrainKit/Package.swift`.
- [x] T002 [P] Integrate APKG export file types into `apps/learner/App/LibraryPrototypeView.swift` (merged from AnkiExportDocument.swift).
- [x] T003 [P] APKG fixtures exist under `packages/LinguaBrainKit/Tests/Fixtures/APKG/` with README.md.

## Phase 2: Foundational infrastructure

- [x] T004 Implement export configuration, limits, cancellation, and typed errors in `packages/LinguaBrainKit/Sources/LinguaBrainAnkiExport/AnkiExportTypes.swift`.
- [x] T005 [P] Implement deterministic SHA-256 checksums and owned-media resolution through application ports in `packages/LinguaBrainKit/Sources/LinguaBrainMedia/OwnedMediaResolver.swift`.
- [x] T006 [P] Implement app-owned temporary workspace creation, cleanup, and atomic destination replacement in `packages/LinguaBrainKit/Sources/LinguaBrainAnkiExport/ExportWorkspace.swift`.
- [x] T007 Implement approved-card selection and provenance normalization through `PersistencePort` without mutating canonical storage in `packages/LinguaBrainKit/Sources/LinguaBrainApplication/ApprovedCardExportSelection.swift`.
- [x] T008 [P] Add tests for limits, cancellation, identity, checksums, cleanup, and provider/storage isolation in `packages/LinguaBrainKit/Tests/LinguaBrainAnkiExportTests/ExportFoundationTests.swift`.

## Phase 3: User Story 1 — Export approved cards with media and provenance (P1)

**Independent test**: Export a selected approved multilingual fixture and verify a valid collection, media manifest, provenance tags, and no rejected cards.

- [x] T009 [P] [US1] Define normalized Anki note, card, model, template, deck, and tag records in `packages/LinguaBrainKit/Sources/LinguaBrainAnkiExport/AnkiCollectionRecords.swift`.
- [x] T010 [P] [US1] Define APKG request, result, manifest, and report types from the contracts in `packages/LinguaBrainKit/Sources/LinguaBrainAnkiExport/AnkiExportContractTypes.swift`.
- [x] T011 [US1] Implement deterministic note/card/model/template/deck/tag mapping from approved Hermes bundles in `packages/LinguaBrainKit/Sources/LinguaBrainAnkiExport/AnkiCollectionMapper.swift`.
- [x] T012 [US1] Implement the pinned `collection.anki21` SQLite schema and parameterized inserts through the existing SQLite boundary in `packages/LinguaBrainKit/Sources/LinguaBrainAnkiExport/AnkiCollectionBuilder.swift`.
- [x] T013 [US1] Implement numeric media indexing, owned-media copying, and manifest checksums in `packages/LinguaBrainKit/Sources/LinguaBrainAnkiExport/AnkiMediaPackager.swift`.
- [x] T014 [US1] Implement bounded ZIP/APKG creation with normalized names, duplicate detection, traversal protection, and atomic output in `packages/LinguaBrainKit/Sources/LinguaBrainAnkiExport/AnkiPackageWriter.swift`.
- [x] T015 [US1] Implement validation for required entries, SQLite readability, manifest consistency, checksums, limits, and text-only fallback in `packages/LinguaBrainKit/Sources/LinguaBrainAnkiExport/AnkiPackageValidator.swift`.
- [x] T016 [US1] Implement the application export use case and progress/cancellation reporting in `packages/LinguaBrainKit/Sources/LinguaBrainApplication/AnkiExportApplicationService.swift`.
- [x] T017 [P] [US1] Add SQLite schema, mapping, Unicode/RTL/LTR, media, provenance, and validation tests in `packages/LinguaBrainKit/Tests/LinguaBrainAnkiExportTests/AnkiCollectionExportTests.swift`.
- [x] T018 [P] [US1] Add hostile archive, traversal, duplicate, oversized-entry, checksum, cancellation, and atomic-write tests in `packages/LinguaBrainKit/Tests/LinguaBrainAnkiExportTests/AnkiPackageSafetyTests.swift`.

## Phase 4: User Story 2 — Selective export with source grouping (P1)

**Independent test**: Select approved cards from multiple source groups and verify only those cards and owned media are exported with distinguishable provenance.

- [x] T019 [US2] Implement filters for approved status, source group, language pair, deck, and explicit card IDs in `packages/LinguaBrainKit/Sources/LinguaBrainApplication/ExportSelectionService.swift`.
- [x] T020 [US2] Add source-group and provenance tag mapping without exposing rejected or unapproved records in `packages/LinguaBrainKit/Sources/LinguaBrainDomain/ExportProvenance.swift`.
- [x] T021 [US2] Integrate selection, progress, errors, and file delivery with `apps/learner/App/LibraryPrototypeView.swift`.
- [x] T022 [US2] Add the user-facing APKG document wrapper in `apps/learner/App/AnkiExportDocument.swift`.
- [x] T023 [P] [US2] Add localized export labels, selection summaries, progress states, and failure messages to `apps/learner/Resources/Localizable.xcstrings`.
- [x] T024 [P] [US2] Add selective export, grouping, exclusion, and media ownership tests in `packages/LinguaBrainKit/Tests/LinguaBrainAnkiExportTests/ExportSelectionTests.swift`.
- [x] T025 [US2] Add app integration coverage for select → export → share/save in `apps/learner/Tests/AnkiExportIntegrationTests.swift`.

## Phase 5: User Story 3 — Offline access and integrity verification (P2)

**Independent test**: Validate and reopen an exported package without network access, detect tampering, and report a safe text-only result when media is unavailable.

- [x] T026 [US3] Implement offline package inspection and normalized integrity reporting in `packages/LinguaBrainKit/Sources/LinguaBrainAnkiExport/OfflineAnkiPackageInspector.swift`.
- [x] T027 [US3] Implement post-write and post-read checksum verification for collection and media in `packages/LinguaBrainKit/Sources/LinguaBrainAnkiExport/AnkiIntegrityVerifier.swift`.
- [x] T028 [US3] Implement bounded-memory streaming and verify the 500-card/500 MB limits in `packages/LinguaBrainKit/Sources/LinguaBrainAnkiExport/AnkiExportPipeline.swift`.
- [x] T029 [P] [US3] Add tampered collection/media, missing media, offline, and resource-limit tests in `packages/LinguaBrainKit/Tests/LinguaBrainAnkiExportTests/OfflineIntegrityTests.swift`.
- [x] T030 [P] [US3] Add accessibility and error-state coverage for progress, cancellation, failure, and text-only fallback in `apps/learner/UITests/APKGExportAccessibilityTests.swift`.

## Phase 6: User Story 4 — Round-trip verification and validation (P2)

**Independent test**: Export a sanitized fixture, read it back through the supported reader, and compare normalized text, senses, examples, directions, media references, and provenance.

- [x] T031 [US4] Implement a normalized APKG reader for the pinned schema and media manifest in `packages/LinguaBrainKit/Sources/LinguaBrainAnkiExport/AnkiRoundTripReader.swift`.
- [x] T032 [US4] Implement round-trip comparison and discrepancy reporting in `packages/LinguaBrainKit/Sources/LinguaBrainAnkiExport/AnkiRoundTripValidator.swift`.
- [x] T033 [US4] Document scheduling compatibility and warn when Hermes review state cannot be represented losslessly in `packages/LinguaBrainKit/Sources/LinguaBrainAnkiExport/AnkiSchedulingCompatibility.swift`.
- [x] T034 [P] [US4] Add round-trip tests for text, senses, examples, directions, Unicode/RTL/LTR, media, tags, and provenance in `packages/LinguaBrainKit/Tests/LinguaBrainAnkiExportTests/AnkiRoundTripTests.swift`.
- [x] T035 [P] [US4] Add a sanitized standard-Anki compatibility fixture and import/read verification procedure under `packages/LinguaBrainKit/Tests/Fixtures/APKG/`.
- [x] T036 Add app-level round-trip evidence to `apps/learner/Tests/AnkiExportIntegrationTests.swift`.

## Phase 7: Polish and release readiness

- [x] T037 [P] Validate every command in `specs/003-apkg-export-approved-cards/quickstart.md` and record actual build/test evidence.
- [x] T038 [P] Add APKG export architecture and user-flow documentation under `docs/apkg-export/`.
- [x] T039 [P] Add security review findings and mitigations to `specs/003-apkg-export-approved-cards/security-review.md`.
- [ ] T040 [P] Measure the 500-card export target and record results in `specs/003-apkg-export-approved-cards/performance-results.md`. Requires a repeatable wall-clock/memory harness.
- [x] T041 Run package tests; record evidence in quickstart.md (package passes; app-level verification remains open).
- [x] T042 Confirm no generated artifacts, credentials, or temporary APKG files are staged before committing.

## Dependencies and execution order

```text
T001–T003 → T004–T008 → US1 (T009–T018)
US1 → US2 (T019–T025)
US1 → US3 (T026–T030)
US1 → US4 (T031–T036)
US2 + US3 + US4 → T037–T042
```

US2, US3, and US4 may proceed in parallel after US1 is stable.

## MVP scope

The first usable increment is **US1**: approved-card selection, valid `collection.anki21`, owned media, provenance, safe APKG packaging, validation, and tests. US2 is required before broad learner-facing selection; US3 and US4 are production release gates.

## Format validation

All tasks use `- [ ] T### [P?] [US#?] description with an exact repository path`. No task from the previous Hermes generation feature is included.
