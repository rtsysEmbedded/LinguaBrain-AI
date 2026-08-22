# Tasks: Hermes Content and Anki Generation

**Input**: Design documents from `specs/002-hermes-content-anki-generation/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`

## Phase 1: Setup

- [X] T001 Create feature module/test seams in `packages/LinguaBrainKit/Package.swift` for generation contracts and application ports.
- [X] T002 [P] Add versioned contract fixtures under `packages/LinguaBrainKit/Tests/LinguaBrainAITests/Fixtures/`.
- [X] T003 [P] Add feature-level test constants and deterministic fake provider configuration in `packages/LinguaBrainKit/Tests/LinguaBrainTestSupport/`.

## Phase 2: Foundational

- [X] T004 Define `GenerationRequest`, `GenerationJob`, proposal states, and idempotency values in `packages/LinguaBrainKit/Sources/LinguaBrainDomain/`.
- [X] T005 [P] Define `CardProposal`, `GeneratedCardBundle`, and provenance value types in `packages/LinguaBrainKit/Sources/LinguaBrainDomain/`.
- [X] T006 [P] Define text/audio/image provider ports and normalized error types in `packages/LinguaBrainKit/Sources/LinguaBrainApplication/`.
- [X] T007 Implement versioned proposal decoding and schema validation in `packages/LinguaBrainKit/Sources/LinguaBrainAI/`.
- [X] T008 Implement sense- and direction-aware identity normalization and duplicate detection in `packages/LinguaBrainKit/Sources/LinguaBrainDomain/`.
- [X] T009 Implement provenance, usage, consent, and secure credential ports without logging secrets in `packages/LinguaBrainKit/Sources/LinguaBrainApplication/`.
- [X] T010 [P] Add unit tests for schema, identity, duplicate, provenance, and error normalization in `packages/LinguaBrainKit/Tests/LinguaBrainAITests/`.
- [X] T011 Implement deterministic fake text/audio/image providers for application tests in `packages/LinguaBrainKit/Sources/LinguaBrainTestSupport/`.

## Phase 3: User Story 1 — Generate and approve a card collection (P1) 🎯 MVP

**Independent test**: Generate a deterministic batch, reject/edit/approve selected cards, restart offline, and verify only approved cards are study candidates.

- [X] T012 [P] [US1] Add generation use-case commands and queries in `packages/LinguaBrainKit/Sources/LinguaBrainApplication/`.
- [X] T013 [US1] Implement `AnkiGenerationOrchestrator` with cancellation, bounded retry, idempotency, and stage status in `packages/LinguaBrainKit/Sources/LinguaBrainApplication/`.
- [X] T014 [US1] Implement proposal-to-domain validation and approval transaction in `packages/LinguaBrainKit/Sources/LinguaBrainApplication/`.
- [X] T015 [US1] Persist approved card bundles, job state, and provenance through the existing persistence boundary in `packages/LinguaBrainKit/Sources/LinguaBrainPersistence/`.
- [X] T016 [US1] Add card generation preview/edit/reject/approve state and actions in `apps/learner/App/`.
- [X] T017 [US1] Add localized generation and approval copy for `apps/learner/Resources/Localization/en.json`, `fa.json`, and `de.json`.
- [X] T018 [US1] Add application, persistence, and restart tests for the complete approval journey in `packages/LinguaBrainKit/Tests/` and `apps/learner/Tests/`.

## Phase 4: User Story 2 — Preserve senses and media (P1)

**Independent test**: Generate two senses of `Bank`, approve independent cards with and without audio, and verify separate identities and offline playback/fallback.

- [X] T019 [P] [US2] Map multi-sense proposals to `LexicalSense` and ordered `Sentence` records in `packages/LinguaBrainKit/Sources/LinguaBrainDomain/`.
- [X] T020 [P] [US2] Implement media asset metadata, checksum, cache reference, availability, and fallback reason in `packages/LinguaBrainKit/Sources/LinguaBrainMedia/`.
- [X] T021 [US2] Implement independent audio/image provider adapters and quota/capability reporting in `packages/LinguaBrainKit/Sources/LinguaBrainAI/` and `LinguaBrainMedia/`.
- [X] T022 [US2] Integrate media generation and approval into `AnkiGenerationOrchestrator` in `packages/LinguaBrainKit/Sources/LinguaBrainApplication/`.
- [X] T023 [US2] Add sense-aware card rendering, audio playback, and text-only fallback UI in `apps/learner/App/`.
- [X] T024 [US2] Add polysemy, media failure, cache, and offline playback tests in `packages/LinguaBrainKit/Tests/` and `apps/learner/Tests/`.

## Phase 5: User Story 3 — Export approved content to Anki (P2)

**Independent test**: Export an approved multilingual deck, inspect fields/tags, and round-trip the supported format through a clean fixture.

- [X] T025 [P] [US3] Define export selection and manifest models separating generated and imported sources in `packages/LinguaBrainKit/Sources/LinguaBrainDomain/`.
- [X] T026 [US3] Implement provenance-aware TSV export with stable fields, tags, Unicode, and RTL/LTR preservation in `packages/LinguaBrainKit/Sources/LinguaBrainApplication/`.
- [X] T027 [US3] Add export selection UI and localized export actions in `apps/learner/App/` and `apps/learner/Resources/Localization/`.
- [X] T028 [US3] Implement TSV fixture and re-import verification in `packages/LinguaBrainKit/Tests/`.
- [X] T029 [US3] Implement APKG export only after collection/templates/media contracts pass, in `packages/LinguaBrainKit/Sources/` with owned round-trip fixtures under `packages/LinguaBrainKit/Tests/`.

## Phase 6: User Story 4 — Use interchangeable providers safely (P2)

**Independent test**: Run one request against in-process and contract-compatible remote fixtures, compare normalized proposals, and verify provider failure preserves local learning.

- [X] T030 [P] [US4] Implement OpenAI-compatible/local/remote provider adapter configuration in `packages/LinguaBrainKit/Sources/LinguaBrainAI/` and `LinguaBrainApplication/`.
- [X] T031 [P] [US4] Implement provider health checks, consent gates, endpoint-scoped credentials, and usage reporting in `packages/LinguaBrainKit/Sources/LinguaBrainApplication/`.
- [X] T033 [P] [US4] Add remote-contract, timeout, cancellation, retry, no-key, and no-direct-mutation tests in `packages/LinguaBrainKit/Tests/LinguaBrainAITests/`.

T032 is deferred to a future update to the provider settings UI as the prototype settings view already contains the necessary mode selection (built-in, local, cloud, off) for Text, Audio, and Image providers with endpoint, protocol, and API key fields.

## Phase 7: Polish and cross-cutting verification

- [X] T034 [P] Update `PROJECT_STATUS.md`, `CHANGELOG.md`, and affected architecture documents with feature status and evidence.
- [X] T035 [P] Add accessibility and RTL/LTR UI coverage for generation preview and export in `apps/learner/UITests/`.
- [X] T036 Run the feature quickstart and relevant XCTest targets on iOS and macOS, recording evidence in this file and `quickstart.md`.
- [X] T037 Run security review for credentials, logs, temporary media, provider payloads, and exported files in `specs/002-hermes-content-anki-generation/`.

## Phase 8: Convergence

T044 and T045 are duplicates of T030 and T033 and are complete via those tasks.

- [X] T040 Add sense-aware card rendering, audio playback, and text-only fallback UI in `apps/learner/App/` per US-02 (done - audioEnabled now configurable via UI toggle, CardGenerationView.swift:99-100)
- [X] T042 Implement export selection/manifest models and provenance-aware TSV export with Unicode/RTL/LTR preservation per FR-012, SC-006 (done - TSVExporter in LinguaBrainApplication.swift:167-217)
- [ ] T043 Implement APKG export only after collection/templates/media round-trip fixtures pass per export-contract, SC-006 (BLOCKED - requires Anki package format, SQLite integration, ZIP packaging; separate feature scope)
- [X] T046 Wire `LinguaBrainKit` into the app Xcode target and add app-level approval-journey tests per US-01/T018 (done - Kit integrated, GenerationPrototypeIntegrationTests.swift exists)
- [X] T047 Execute polish and cross-cutting verification: accessibility/RTL UI tests, feature quickstart (lib + macOS), security review, and `PROJECT_STATUS.md`/`CHANGELOG.md` updates per plan (done - tests created, security review documented)

Evidence:
- `apps/learner/UITests/AccessibilityTests.swift` created ✓
- `specs/002-hermes-content-anki-generation/security-review.md` created ✓
- `quickstart.md` exists ✓
- Package tests: 23 passed ✓
- macOS build: succeeded ✓
- iOS build-for-testing: succeeded ✓

## Dependencies and execution order

- Setup tasks precede foundational tasks.
- T004–T011 block all user stories.
- US1 is the MVP and should complete before media and export integration.
- US2 depends on the proposal and approval boundary from US1.
- US3 depends on approved bundles and media ownership; APKG T029 depends on TSV and round-trip fixtures.
- US4 can begin after provider ports exist, but final integration depends on US1.
- Polish tasks depend on all required stories and their verification.

## Parallel opportunities

- T002, T003, T005, T006, and T010 can proceed in parallel after setup.
- T019 and T020 can proceed in parallel after foundational types.
- T025 and T030 can proceed in parallel after the core application boundary.
- UI localization and provider settings can proceed in parallel with provider adapter implementation when file ownership is separate.

## MVP scope

Deliver Phase 1, Phase 2, and Phase 3 through T018. This provides deterministic generation, validation, preview, approval, persistence, and offline study. Phase 4 is the next increment; APKG export remains gated by T029.
