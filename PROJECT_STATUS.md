---
title: Project Status and Delivery Checklist
document_id: LB-STATUS
version: 0.4.30
status: Active
last_updated: 2026-10-13
---

# Project Status and Delivery Checklist

This file is the single progress checklist for LinguaBrain AI. It must be updated in the same Git commit whenever a tracked task is completed, deferred, removed, or materially changed.

## Checklist rules

- `[x]` means completed and verified.
- `[ ]` means not completed.
- An item marked **In progress** remains unchecked until its acceptance criteria pass.
- Deferred work stays unchecked and is listed under Post-MVP rather than disappearing.
- Decisions that change scope or architecture require an ADR before this checklist is updated.

## Current snapshot

### Audit remediation — 2026-10-13

- [ ] Resolve the findings in the [2026-10-13 project audit](docs/PROJECT_AUDIT_2026-10-13.md). Its Section 5 records which groups are complete, in progress, or still open.
- [x] Stop tracking the 95.7 MiB third-party `German_Top_4000_vocabulary.apkg` deck and ignore it; Git history is unchanged.

### Planned work — 2026-09-06

- [ ] Feature 004 — Adaptive skill practice: 36 implementation tasks prepared in [tasks.md](specs/004-adaptive-skill-practice/tasks.md), with [specification](specs/004-adaptive-skill-practice/spec.md), [plan](specs/004-adaptive-skill-practice/plan.md), and [Persian handoff](specs/004-adaptive-skill-practice/HANDOFF.fa.md). T001–T012 are verified: accepted scope, audited contracts, portable Domain model, provider-independent ports/policy, production GRDB adapter, migration bridge, application-owned review/mastery/FSRS boundary, bounded session orchestration, deterministic cross-layer verification, injected shared composition/model, reusable scaffold/feedback UI, rendered-surface localization/accessibility QA, and the writing-evaluation rubric/fixture contract. Later progress notes record T013–T026 and T028 as verified, giving 27 of 36 tasks; T027 and T029–T036 remain open, and T033 (four-skill UI integration) is the main functional gap identified by the [2026-10-13 audit](docs/PROJECT_AUDIT_2026-10-13.md).
- [x] Feature 004 / T001 — scope and controlled cutover accepted in ADR-017, with roadmap/status/changelog traceability.
- [x] Feature 004 / T005 — production GRDB 7.11.1 repository, ordered migrations, constraints, transactions, and restart/rollback evidence.
- [x] Feature 004 / T003 — portable practice Domain model with stable ReviewUnit identity, immutable sentence revisions, typed outcomes/evaluator evidence, assistance events, session transitions, and unknown mastery semantics.
- [x] Feature 004 / T004 — provider-independent exercise/attempt/help/evaluation/media/scheduling ports and deterministic assistance-aware evidence policy.
- [x] Feature 004 / T006 — application-owned review/mastery/FSRS service, atomic evidence/projection commit, pinned FSRS adapter, and migration preservation evidence.
- [x] Feature 004 / T007 — bounded application session orchestration with durable assistance, save-before-evaluate, review-service routing, resume, retry, skip, idempotency, and late-result suppression.
- [x] Feature 004 / T008 — deterministic TestSupport fakes and cross-layer Domain/Application/Persistence/app migration verification with regression evidence.
- [x] Feature 004 / T009 — injected shared practice composition and `@MainActor @Observable` session model, explicit presentation states/intents, stale-work cancellation, and compatibility routing with legacy review retained.
- [x] Feature 004 / T010 — reusable responsive practice scaffold and feedback UI with finite state rendering, assistance-aware messaging, accessibility semantics, localization, and injected prompt/answer content.
- [x] Feature 004 / T011 — rendered-surface state/localization/accessibility QA, independent answer-language direction, fa/en/de catalog parity, large-text/narrow-width simulator smoke, and manual VoiceOver/keyboard procedure with explicit limits.
- [x] Feature 004 / T012 — versioned writing-evaluation rubric, 13 synthetic fixtures, and six offline schema/contract validation tests covering accepted, rejected, and unavailable evidence.

| Field | Current value |
| --- | --- |
| Current phase | Feature 004: 27 of 36 tasks verified; T027 and T029–T036 remain open. 2026-10-13 audit remediation is in progress |
| Product scope | German–Persian local-first native Apple Release 1.0 (iOS/iPadOS/macOS 27), with optional Apple/Google account and scoped sync |
| Documentation | Documents 01–15 complete as reviewed drafts |
| Architecture baseline | Native Swift migration; DOC-10 at 0.5.1, DOC-11 at 0.3.1, DOC-14 at 0.3.2, and DOC-15 at 0.2.2 |
| Local Apple toolchain | Xcode 27.0 (`27A5228h`) is active with Swift 6.4 and iOS/iPadOS/macOS 27 SDKs; beta-era evidence remains provisional |
| Latest accepted ADRs | Native baseline ADR-009 through ADR-016, plus [ADR-004](decisions/ADR-004-FSRS-Implementation-and-Version.md) for the pinned scheduler |
| Active Git branch | `main`, tracked on `origin`; agent work uses `claude/*` branches and draft pull requests |
| Native platform migration commit | `3c75a70` |
| Visual prototype | Buildable SwiftUI prototype for iPhone, iPad, and Mac; review state persists, APKG cards can be imported, approved learner cards have opt-in private iCloud backup/recovery, and Utilities includes on-device live transcription |
| Next primary deliverable | Execute the four learning-core workstreams documented in `docs/CODEBASE_REALITY_AUDIT_2026-08-25.md`; Apple Developer-account-dependent release work remains deferred |
| Current delivery strategy | Anki Core first: secure APKG import and reliable offline review gate before AI and final visual approval |
| Latest audit | 2026-10-13: [Project Audit](docs/PROJECT_AUDIT_2026-10-13.md). `LinguaBrainKit` built with Swift 6.4.1 on Linux (scratch copy with documented Linux-only shims): 194 tests, 0 failures (Domain 20, Application 69, Anki Export 64, AI 41). Two package defects block an unmodified Linux build (`OSStatus` in the Application layer; non-`Sendable` `ExportCancellation`). The Apple app targets were not built in that audit. |
| Latest verification | 2026-09-06: 169 Swift package tests pass (Domain 20, Application 56, Anki Export 64, AI 29 including six T012 fixture-validation tests); iOS Simulator Debug and macOS Debug builds pass; 13 synthetic writing fixtures validate with malformed/oversized/language/span/score/confidence/rule rejection coverage. No provider call or live learner store was used. |

## Completed foundation

### Repository

- [x] Initialize the Git repository.
- [x] Add `README.md`.
- [x] Add `CHANGELOG.md`.
- [x] Add MIT `LICENSE`.
- [x] Create `docs/`, `decisions/`, `diagrams/`, and `assets/`.
- [x] Add an ADR template.
- [x] Add this project-status checklist.
- [x] Adopt GitHub Spec Kit with a project constitution and Codex, Claude Code, and Gemini CLI integrations.
- [x] Create the first Spec Kit feature for the Anki Core modern-import and offline-review gate.
- [x] Complete Spec Kit task T001 with a real XCTest target, a sanitized runtime-generated legacy APKG fixture, and regression coverage for field mapping, re-import, and independent review directions.
- [x] Complete Spec Kit task T002 with ADR-003 selecting the GRDB 7 persistence and migration boundary.
- [x] Complete Spec Kit task T003 with a pinned modern Anki package compatibility, security, and fixture-provenance research baseline.
- [x] Complete Spec Kit task T004 with approved normalized-reader, resource-policy, provenance, polysemy, reconciliation, conflict, and ownership contracts.
- [x] Complete pre-T005 task T004A with independent English/German/Persian interface selection, dynamic RTL/LTR behavior, an Apple String Catalog for prototype screens, persisted source/target roles, and three generated language-pair APKG fixtures.
- [x] Complete pre-T005 task T004B with 30 stable multilingual sample cards, persisted language-pair metadata, pair-scoped Today/Library/Review/Progress behavior, generic target/source card rendering, and all six directed pairs.
- [x] Complete localization tasks T004C/T004D with editable `fa.json`, `en.json`, and `de.json` resources, centralized fallback loading, and a 306-key inventory migrated from the prototype String Catalog; remaining content-only card examples are explicitly outside interface-copy scope.
- [x] Complete Spec Kit task T005 with an owned 10-case modern/legacy/hostile fixture catalog, pinned upstream provenance, and XCTest coverage for fixture-matrix integrity; binary schema-18 generation remains gated to T006–T008.
- [x] Complete Spec Kit tasks T014/T015 with stable imported-card review identities, independent recognition/reverse states, all four FSRS ratings, due timing, session accounting, atomic persistence, and regression coverage on iPhone 17 Simulator.
- [~] Defer T006–T013 modern Anki import, schema 18, Zstandard/SwiftProtobuf, modern media, and modern reconciliation to a separate Spec Kit feature; legacy import and offline review remain the current feature boundary.
- [ ] Complete Spec Kit task T004E localization QA across all interface languages, Settings submenus, review labels, duration units, coach suggestions, and source/target titles on iOS and macOS.
- [ ] Define internal Anki generation for all levels with Google Cloud Text-to-Speech audio, A1-targeted images, local caching, preview/approval, provenance, quota visibility, and text-only fallback (T020).
- [~] T020/T026 audio slice: generated word cards automatically request audio from the independent Audio provider, now routing Google Native through the configured Google TTS endpoint and `api-key.audio`, persist MP3 bytes on approval, and play them during review; quota accounting, full MediaAsset provenance/cache lifecycle, collocations, conversation sentences, and packaged APKG media export remain open.
- [ ] Design and implement the generic AI provider connection boundary (endpoint, protocol, model, optional Keychain credential, local/remote scope) with OpenAI-compatible local support for LM Studio/Ollama (T021).
- [ ] Split provider settings into independent Text, Audio, and Image menus with local/cloud/off choices and a premium-gated built-in provider path (T022).
- [x] T030/T032 provider settings: independent Text, Audio, and Image provider modes, endpoint URL, protocol, model ID, and local/no-key boundary are implemented; adapters, Keychain migration, entitlements, quota, and QA remain open.
- [x] T033 configuration and safety: OpenAI-compatible provider adapter with configurable endpoint/protocol, health checks, credential loaders; comprehensive tests for no-key, timeout, cancellation, retry, and Constitution III compliance (no direct mutation).
- [x] Harden `.gitignore` for local projects, secrets, Python, local stores, SwiftPM, Xcode, archives, and generated files.
- [x] Add a buildable static SwiftUI visual prototype for iPhone, iPad, and Mac, with mock data and no production dependencies.
- [x] Define and prototype the ten minimum MVP card surfaces required before final visual-design approval.
- [x] Add a restart-durable SwiftData checkpoint for the 50-word prototype review history and due dates, including save-before-success and recoverable UI error reporting.
- [x] Persist a real local deck and 50 stable card records, seed only an empty installation, and restore card identity/content before review history is loaded.
- [x] Add read-only APKG selection, bounded ZIP preflight, explicit confirmation, and transactional card import for legacy SQLite `collection.anki2`/`collection.anki21` packages; modern `collection.anki21b`, templates, tags, and media remain pending.
- [x] Enforce a prototype daily new-card limit derived from the learner's selected energy and available time.
- [x] Persist the prototype's energy/time/motivation/mode check-in per calendar day in SwiftData, restore it when Today reopens, and fall back to named defaults when the state is missing or stale.
- [x] Add Persian-to-German reverse translation with an independent persisted FSRS memory state.
- [x] Add a functional OpenRouter prototype with Keychain-backed API-key storage, explicit cloud consent, configurable model ID, structured card proposals, preview, and local approval.
- [x] Model generated cards as domain-specific lexical senses so homographs can coexist and retain independent recognition/reverse-review schedules; migrate legacy review keys to stable card identities.
- [x] Accept optional Sign in with Apple/Google and secure learner-data synchronization as Release 1.0 scope while preserving full local-only use.
- [x] Add opt-in private iCloud backup/recovery for learner-generated and Anki-imported cards while excluding built-in samples (ADR-015/T032).
- [ ] Register `iCloud.ai.linguabrain.prototype` on a paid Apple Developer Team and reattach `Resources/LinguaBrain.entitlements` before enabling signed CloudKit builds.
- [~] Add Utilities navigation and on-device streaming speech-to-text with permission-gated microphone/Speech access (ADR-016/T034); physical macOS testing shows the meter reacts but local transcript text is still missing.
- [x] Add copyable transcript/translation output for Persian, German, and English through the configured text Provider (T036).
- [~] Complete physical Mac/iPhone verification of the implemented OpenAI Realtime cloud transcription path (T035/T037); the corrected cloud path is acceptable in the current macOS test, while iPhone verification and the remaining model/latency matrix are still open.
- [x] Separate Audio provider model roles: card pronunciation uses Speech/TTS, completed audio uses Transcript, and low-latency microphone text uses Live Stream; Utilities reads the selected Transcript/Live model directly from Settings.
- [ ] Complete the Utilities transcription visual-design pass after provider behavior is explicit and testable (T039).
- [x] Add user-defined learning domains with Settings management, Library filtering, and Today-plan scoping.
- [x] Classify and place the vocabulary prototype at `experiments/vocabulary-mvp/` according to [ADR-001](decisions/ADR-001-Repository-Package-and-Module-Layout.md).
- [x] Configure a Git remote and push `main` (`origin` is configured and `main` is pushed).
- [ ] Create an annotated MVP specification baseline tag.

### Product and architecture specifications

- [x] Document 01 — Product Vision.
- [x] Document 02 — Learning Philosophy.
- [x] Document 03 — Non-Functional Requirements.
- [x] Document 04 — Core Domain Model.
- [x] Document 05 — Learning Domain Model.
- [x] Document 06 — Knowledge Graph Architecture.
- [x] Document 07 — Adaptive Learning Engine.
- [x] Document 08 — AI Orchestration Layer.
- [x] Document 09 — Language Independence Framework.
- [x] Document 10 — MVP Definition and Roadmap.
- [x] Document 11 — Technical Architecture.
- [x] Document 12 — Database Schema and Persistence.
- [x] Document 13 — AI Agent Pipeline.
- [x] Document 14 — Frontend UX/UI.
- [x] Document 15 — Implementation Backlog and Requirements Traceability.
- [x] Review Documents 01–14 for domain, scheduling, validation, privacy, and MVP consistency.
- [x] Preserve a future dedicated-device path through `ClientSurface` and `CapabilitySnapshot` without adding hardware to MVP scope.
- [x] Replace the Android/Flutter platform decision with the native Apple OS 27 baseline in [ADR-009](decisions/ADR-009-Native-Apple-Client-and-Platform-Baseline.md); preserve ADR-008 as superseded history.
- [x] Replace the Dart/Flutter package topology with the Swift/Xcode/SwiftPM topology in [ADR-010](decisions/ADR-010-Swift-Package-and-Module-Layout.md); preserve ADR-001 as superseded history.
- [ ] Resolve MVP-blocking decisions and promote the approved specification set from `Draft` to a versioned baseline.

Feature 004 T006–T012 verification: T001–T012 are verified. `PracticeReviewService` owns the application review/mastery/FSRS boundary, `PracticeSessionService` owns bounded session orchestration, TestSupport owns deterministic fakes used by cross-layer verification, the app-owned `PracticeComposition`/`PracticeSessionModel` boundary owns explicit UI state and intent delegation, the shared scaffold/feedback views own reusable presentation plus rendered-surface localization/accessibility QA, and the writing contract owns validated synthetic evaluation proposals. «مرور پیشنهادی» در Today فقط صف سادهٔ کارت‌های موعددار Anki است؛ چهار مهارت در مسیر مستقل «تمرین مهارت‌ها» باقی می‌مانند. Legacy recognition/reverse evidence remains retained, while writing/grammar/listening/speaking remain independent and do not inherit legacy history. T013 remains the next safe task; no live learner store was modified and no AI provider or mode-specific story was started.

Migration regression fix: the activation check now counts unique legacy review units rather than every historical review attempt, so valid cards with repeated reviews no longer enter a false recovery state. The regression is covered by the app migration suite; no retained source or backup is deleted.

Cutover correction: the existing Anki review route continues to write through `PrototypeStore`; its writer remains enabled until that route is migrated atomically to GRDB. This avoids the post-update storage error when a learner rates a card. No source or backup is removed.

### Feature 004 progress notes

#### Writing contract adapter

T013 and T014 are verified complete. The writing decoder/provider boundary is validated and ungraded failure-safe, and the application service preserves local responses before evaluation. T015 and the later writing-reuse, grammar, listening, speaking, integration, ownership, and final-QA tasks remain open; no live learner data was accessed.

#### Sentence reuse and planning

T016 and T017 are verified complete. Sentence acceptance is scoped, transactional, revision-safe, and original-response preserving. Adaptive planning is deterministic and does not mutate mastery or schedules. T018 onward remains open.

#### Sentence history

T018 is verified complete. Sentence history is an injected UI boundary with localized original/correction/natural/reason/next-exercise/mastery presentation and no direct progress or persistence mutation. T019 remains the next task.

#### Dynamic reuse loop

T019 is verified complete. Writing acceptance survives restart, feeds deterministic future planning, preserves revisions, and does not fabricate evidence for unavailable or unrelated skills. T020 is the next task.

#### Grammar contract

Feature 004 T020 is complete. The versioned grammar contract and deterministic, curated exercise factory are implemented and verified offline; T021 is the next safe task.

#### Integration status — 2026-09-07

Feature 004 integration status (2026-09-07): T033–T036 are still open. The
application ownership boundary now has synthetic export/delete/consent tests,
but the production GRDB ownership adapter, all four-skill navigation/progress
integration, and final device/accessibility QA are not yet complete. Do not
claim final Feature 004 completion or physical-device/provider coverage.

#### Updates — 2026-09-08

- Feature 004 update (2026-09-08): T015 and T028 are verified complete. Writing UI tests pass on iPhone 17 Simulator. Pronunciation research reached a valid negative capability decision, so no numeric speaking score is enabled and T030–T032 remain open pending an approved audio-based provider and physical-device benchmark.
- Feature 004 update (2026-09-08): T021–T026 and T023 are now verified. Grammar uses a canonical-rule evaluator boundary; listening requires exact sentence revision plus audio checksum and hides transcript/translation until feedback or reveal. Apple sentence playback builds on iOS Simulator. T027 and T029 remain open for complete audio QA; T030–T032 remain blocked by the unapproved pronunciation provider/device benchmark.
- Feature 004 gate audit (2026-09-08): macOS Debug, localization parity, and diff checks pass after the Apple playback/recorder work. T027 and T029 remain evidence-gated by real licensed audio and physical-device recording QA. T030–T032 remain capability-gated by the approved negative pronunciation-provider decision; consequently T033–T036 cannot yet be truthfully closed.

#### Updates — 2026-10-13

- Feature 004 T033 remains open. Phase A1 (package layer) of the [T033 integration design](specs/004-adaptive-skill-practice/T033-integration-design.md) is implemented: card-based writing and listening retrieval, per-skill capability gate, skill-routed evaluator, and read-only progress from persisted projections, with 10 new tests. A session-scope defect that prevented a completed review unit from being practised again was fixed. The package suite passes on the Linux Swift 6.4.1 harness (204 tests); no Xcode 27 run has been made for these changes. Phase A2 (app wiring) has not started; design decision 5 and the listening-material question (design Section 7.3) are open.
- Audit item 1 (A1, A3–A6, B1–B4) fixed: valid `.specify/extensions.yml`; stored OpenRouter endpoints are kept; no Darwin type in the Application layer; lock-based export cancellation; real MP3/JPEG fixtures; orphaned tests moved into compiled targets; `.gitignore` no longer hides Xcode project files; package platforms iOS/macOS 27. Reopened Feature 003 T025 and Feature 002 T035, whose only deliverables were placeholder or uncompiled tests. The package suite passes on the Linux harness (236 tests).
- Audit finding C5: remaining prompts, level lists, thresholds, and daily-plan coefficients moved to `Resources/Configuration`.
- Feature 004 T033 Phase C: grammar rules and 10 drafted German exercises are in `grammar-content.json`, pending Product Owner review; grammar stays unavailable until entries are reviewed. Listening evaluation scores semantic slots. T033 stays open (grammar review, Xcode 27 build, device QA).
- Feature 004 T033 Phase B: writing, grammar, and listening answers are graded by the configured Text provider when Settings and consent allow; otherwise they are saved as ungraded. Not verified against a live provider.
- Feature 004 T033 Phase A2: Today's skill rows open the Feature 004 writing and listening views built from the learner's own cards; grammar and speaking show explicit unavailable reasons; Today recommends the weakest evidenced skill; Progress reads GRDB evidence per language pair. The legacy `SkillPracticeView` was removed. T033 stays open (grammar content review, Xcode 27 build, device QA).
- Learner profile implemented (level, goal, target level, daily goal, playback speed, onboarding). Remaining Settings placeholders are listed in the audit (Section 3). Cards now record whether their content was reviewed; listening practice will use only reviewed examples.

## M0 — Implementation preparation

### Planning and traceability

- [x] Create Document 15 — Implementation Backlog and Requirements Traceability.
- [x] Map every MVP requirement to a milestone, backlog item, acceptance criterion, and test level.
- [x] Create and maintain the Decision Register; it currently contains 62 stable decision IDs, including later supplemental architecture decisions.
- [x] Classify decisions as `MVP-blocking`, `MVP-later`, or `post-MVP`, with status, owner, due gate, and required artifact.
- [x] Define issue labels, priorities, dependencies, and Definition of Done.
- [ ] Approve the M1 implementation backlog.

### M0/M1-blocking ADRs

- [x] [ADR-009 — Native Apple client and platform baseline](decisions/ADR-009-Native-Apple-Client-and-Platform-Baseline.md).
- [x] [ADR-010 — Swift package and module layout](decisions/ADR-010-Swift-Package-and-Module-Layout.md).
- [x] ADR-001 and ADR-008 retained as superseded historical decisions.
- [x] [ADR-011 — SwiftUI Observation/state, navigation, and dependency composition](decisions/ADR-011-SwiftUI-State-Observation-Navigation-and-Dependency-Composition.md).
- [x] [ADR-012 — Anki Core first and APKG import boundary](decisions/ADR-012-Anki-Core-First-and-APKG-Import-Boundary.md).
- [x] [ADR-013 — OpenRouter-first cloud AI and future Apple Foundation Models adapter](decisions/ADR-013-Initial-AI-Provider-Strategy.md).
- [x] [ADR-014 — Optional accounts and Release 1.0 synchronization](decisions/ADR-014-Optional-Accounts-and-Release-Sync.md).
- [x] [ADR-003 — GRDB 7/system SQLite persistence and migration stack](decisions/ADR-003-Swift-Persistence-and-Migration-Stack.md).
- [ ] ADR — Domain events and transactional outbox strategy.
- [ ] ADR — Apple local-store protection, Keychain, backup, recovery, and key handling.

### ADRs required before M3

- [x] [ADR-004 — FSRS implementation and version](decisions/ADR-004-FSRS-Implementation-and-Version.md).
- [ ] ADR — ReviewUnit retrieval contracts and evidence-to-rating mapping.

### Canonical diagrams

- [ ] System Context diagram.
- [ ] Container and Module Architecture diagram.
- [ ] Core Domain ERD.
- [ ] Review transaction sequence diagram.
- [ ] Adaptive Learning Engine decision-flow diagram.
- [ ] AI pipeline sequence diagram.

## Specification readiness gates

- [x] Anki Core MVP supporting specification and acceptance gate.

- [ ] Document 16 — Application and Domain Contracts, required before M1 implementation.
- [ ] Document 18 — German–Persian Language Package, required before M2 implementation.
- [ ] Document 17 — Review Engine, FSRS, and ReviewUnit, required before M3 implementation.
- [ ] Document 19 — Security, Privacy, and Threat Model, required before M6 hardening; its minimum protection/backup ADR is still an M0 gate.
- [ ] Document 20 — Verification Strategy and Pilot Protocol, required before pilot enrollment.

## M1 — Domain walking skeleton

- [x] Install and verify Xcode 27.0 build `27A5228h`, Swift 6.4, and version 27 Apple SDKs; beta builds remain provisional until stable Xcode and final OS 27 verification.
- [x] Create and verify the native SwiftUI universal iPhone/iPadOS 27 application and macOS 27 Golden Gate target.
- [~] Create the local multi-target `LinguaBrainKit` Swift package and composition root; the package exists with Domain, Application, AI, Media, Persistence, Anki Export, and TestSupport targets, while an app-wide composition root is not yet complete.
- [ ] Establish domain, application, infrastructure, and presentation boundaries.
- [ ] Add the first native local-store schema and migration runner using the adapter selected by ADR-003.
- [ ] Implement `KnowledgeItem` and its repository contract.
- [ ] Implement learner profile and language-pair configuration.
- [ ] Implement editable onboarding with explicit BCP 47 language roles and a versioned CapabilitySnapshot.
- [ ] Store and retrieve one manual German word fully offline.
- [ ] Add unit and integration tests for the first offline transaction.
- [ ] Verify restart durability and error handling.

**M1 exit criterion:** A manually entered German word can be saved, closed, reopened, and retrieved offline through domain/application interfaces rather than direct UI-to-database access.

## Anki Core validation release — Current product priority

- [x] Implement sandboxed `.apkg` inspection and import preview.
- [~] Map supported decks, notes, cards, templates, tags, images, and audio into LinguaBrain-owned records; legacy APKG image/audio extraction and card-detail display are implemented, while modern `collection.anki21b` media remains deferred.
- [ ] Preserve import provenance and deterministic re-import identity.
- [ ] Implement deck library, due queue, question/answer reveal, and session summary.
- [ ] Connect Again, Hard, Good, and Easy to the pinned FSRS scheduler.
- [ ] Persist review history and due state atomically across restart.
- [ ] Add corrupt, traversal, archive-bomb, unsupported-template, duplicate, and large-deck fixtures.
- [ ] Verify the same semantic flow on iPhone, iPad, and Mac without an AI provider.

**Anki Core exit criterion:** A representative APKG imports safely, reviews offline with all four ratings, survives restart without lost progress, and re-imports without uncontrolled duplication. AI and final graphic approval remain gated until this passes.

## M2 — Card and language foundation

- [ ] Implement minimum German and Persian Language Package capabilities.
- [ ] Add normalization and duplicate detection.
- [ ] Add manual minimal-card creation with no AI provider.
- [ ] Add provider-independent AI enrichment and structured-output validation.
- [ ] Add proposal preview, approval, provenance, and private/canonical validation states.
- [ ] Implement smart-card presentation and basic automatic collections.
- [ ] Complete the smart-card contract for meaning/sense, POS, CEFR, example, noun/verb forms, pronunciation availability, provenance, and validation state.
- [ ] Add cache keys with prompt, package, model, validator, and safety versions.
- [ ] Add secure AI provider settings, configurable usage budgets, and a provider/request/token/cost view.
- [ ] Add baseline cached pronunciation audio with accessible offline playback where media is available.
- [ ] Select and document validated lexical datasets and licenses.

**M2 exit criterion:** A learner can create or enrich a German item, inspect and approve the result, avoid duplicates, and use the accepted content offline.

## M3 — Objective-level review expansion

- [x] Implement `LearningObjective`, `ReviewUnit`, and independent retrieval contracts.
- [x] Integrate the selected FSRS implementation behind a scheduler interface.
- [x] Implement recognition review.
- [x] Implement Persian-to-German active recall.
- [x] Record immutable LearningEvents and review history.
- [x] Update objective-level mastery without AI mutation.
- [x] Verify that exposure/reveal alone cannot advance mastery and that automatically evaluated exercises do not request self-rating.
- [x] Provide component/rule-specific feedback and a corrective opportunity.
- [x] Add deterministic fake-clock and restart test vectors.

**M3 exit criterion:** Building on the accepted Anki Core scheduler, recognition and recall for the same item are scheduled independently, survive restart, and produce reproducible FSRS history.

## M4 — Adaptive intelligence

- [x] Implement optional daily energy, time, motivation, and mode check-in persistence in the prototype.
- [x] Apply named defaults when check-in is skipped or stale.
- [x] Implement deterministic candidate ranking and stable tie-breaking.
- [~] Build capability-aware daily sessions; current prototype supports adaptive capacity and maps candidate objectives to the weakest attempted skill.
- [~] Target weak skills and explain every recommendation; per-plan explanation is implemented, while full localized per-recommendation rationale remains open.
- [ ] Add basic Digital Twin summaries from auditable LearningEvents.
- [ ] Let the learner inspect, correct, and delete Digital Twin profile/inference data.
- [ ] Implement the actionable progress summary for objectives, skills, weak patterns, mission coverage, retention, time, and recent activity.

**M4 exit criterion:** Given the same versioned inputs, clock, and capabilities, the engine produces the same explainable daily plan.

## M5 — Connected learning

- [ ] Implement validated one-hop Knowledge Graph relations.
- [ ] Add word-family and related-item views.
- [ ] Add cloze, article, and word-form exercises.
- [ ] Apply mission and domain relevance during plan selection.
- [ ] Enforce controlled novelty using the documented lemma-based measurement.

**M5 exit criterion:** Learning plans can use validated relations and mission relevance without allowing AI to modify canonical knowledge or scheduling directly.

## M6 — MVP hardening and pilot

- [ ] Complete mixed Persian/German RTL/LTR accessibility QA.
- [ ] Complete export and verified deletion flows.
- [ ] Protect API keys with platform secure storage.
- [ ] Verify database migration, backup, restore, and crash recovery.
- [ ] Complete performance and offline failure testing.
- [ ] Finalize privacy disclosures, telemetry consent, and retention defaults.
- [ ] Pre-register the 7-day and 14-day delayed-recall pilot protocol.
- [ ] Run the pilot and evaluate stop/go thresholds.
- [ ] Implement optional Sign in with Apple and Google behind a canonical learner-account identity.
- [ ] Implement transactional guest-to-account merge and event-based multi-device synchronization.
- [ ] Implement in-app account deletion, provider-token revocation, export, sign-out, and recovery tests.

**M6 exit criterion:** All release gates in Document 10 pass and the MVP is ready for a controlled pilot.

## Post-MVP backlog

- [ ] Expanded listening and passive-listening modes.
- [ ] OCR, text, and PDF ingestion with approval workflow.
- [ ] Guided writing and speaking evaluation.
- [ ] Additional language packages and exam missions.
- [ ] Conversation coach and richer professional-domain packages.
- [ ] Dedicated-device product specification.
- [ ] Dedicated-device hardware and power architecture.
- [ ] Consent-gated meeting transcription and personal translation pipeline.
- [ ] Focused device UX, industrial design, and manufacturing plan.
- [ ] Android or web client re-entry decision and cross-runtime interoperability plan.

## Maintenance checklist

Complete these actions with every milestone or architectural change:

- [ ] Update this checklist in the same commit.
- [ ] Update `CHANGELOG.md`.
- [ ] Update affected document versions and revision histories.
- [ ] Add or supersede ADRs when a significant decision changes.
- [ ] Update canonical diagrams when boundaries or flows change.
- [ ] Run Markdown/link checks and relevant automated tests.
- [ ] Confirm that secrets, local databases, generated files, and excluded projects are not staged.

## Related files

- [README](README.md)
- [Changelog](CHANGELOG.md)
- [MVP Definition and Roadmap](docs/10_MVP_Definition_and_Roadmap.md)
- [Technical Architecture](docs/11_Technical_Architecture.md)
- [Implementation Backlog and Requirements Traceability](docs/15_Implementation_Backlog_and_Traceability.md)
- [Decision Register](decisions/DECISION_REGISTER.md)
- [ADR index](decisions/README.md)
- [Diagram index](diagrams/README.md)

## Revision history

| Version | Date | Description |
| --- | --- | --- |
| 0.4.30 | 2026-10-13 | Recorded Feature 004 T033 Phase C (grammar content pending review, slot-based listening evaluation). |
| 0.4.29 | 2026-10-13 | Recorded Feature 004 T033 Phase B (provider-backed, consent-gated evaluation). |
| 0.4.28 | 2026-10-13 | Recorded Feature 004 T033 Phase A2 (app wiring); T033 stays open. |
| 0.4.27 | 2026-10-13 | Recorded the reviewed-content marker for cards and the persisted learner profile. |
| 0.4.26 | 2026-10-13 | Recorded the audit item 1 fixes and reopened Feature 003 T025 and Feature 002 T035 (placeholder or uncompiled test deliverables). |
| 0.4.25 | 2026-10-13 | Recorded Feature 004 T033 Phase A1 (package layer) and the session-scope fix; recorded audit finding C5 and the learner-profile gap. T033 stays open. |
| 0.4.24 | 2026-10-13 | Recorded the 2026-10-13 project audit, stopped tracking the unreferenced 95.7 MiB third-party deck, corrected stale remote/package facts, moved Feature 004 progress notes into the snapshot section, and ordered this table by date. |
| 0.4.23 | 2026-09-06 | Completed Feature 004 T012 with the versioned writing-evaluation rubric, 13 synthetic fixtures, six offline validation tests, malformed/uncertain safety checks, and iOS/macOS Debug build evidence; T013 remains open. |
| 0.4.22 | 2026-09-06 | Completed Feature 004 T011 with rendered-surface state smoke, independent answer-language direction, localized accessibility labels/hints/values, fa/en/de catalog validation, large-text/narrow-width simulator evidence, and documented VoiceOver/device limits; T012 remained open. |
| 0.4.21 | 2026-09-06 | Completed Feature 004 T010 with responsive shared scaffold/feedback views, finite state rendering, assistance-aware messaging, accessibility semantics, fa/en/de localization, injected content, and iPhone 17 Simulator tests; T011 remained open. |
| 0.4.20 | 2026-09-06 | Completed Feature 004 T009 with explicit app composition, an `@MainActor @Observable` session model, finite presentation states, intent-only delegation, cancellation/stale-result suppression, compatibility routing, and deterministic app-level model tests; T010 remains open. |
| 0.4.19 | 2026-09-06 | Completed Feature 004 T008 with deterministic fixed-ID/fixed-clock fakes, scripted cancellation/late results, repository failure injection, cross-layer practice-core tests, app migration evidence, and generation/APKG regression coverage; T009 remains open. |
| 0.4.18 | 2026-09-05 | Completed Feature 004 T007 session orchestration with durable pre-submit assistance, review-service routing, skip/retry/finish/resume, idempotency, bounded retries, cancellation, and stale-result suppression; T008 remains open. |
| 0.4.17 | 2026-09-05 | Completed Feature 004 T006 application-owned review/mastery/FSRS boundary with atomic learning-event/projection persistence, pinned FSRS-6 scheduling, idempotency, rollback, and reopen evidence; T007–T008 remain open. |
| 0.4.16 | 2026-09-05 | Completed Feature 004 T004 provider-independent practice ports and deterministic assistance-aware evidence policy; T006–T008 remain open. |
| 0.4.15 | 2026-09-05 | Completed Feature 004 T003 Domain evidence: stable practice identity, immutable sentence revisions, typed outcomes/evaluator evidence, assistance events, legal session transitions, unknown mastery semantics, and fixed-ID/fixed-date tests. T004/T006–T008 remain open. |
| 0.4.14 | 2026-09-04 | Audited Feature 004 T002 contracts, added state/mastery/FSRS effects and fixed-clock scoring examples, corrected the T006 service-path mismatch, and reopened T006 pending an application review/mastery/FSRS owner. |
| 0.5.1 | 2026-08-26 | Completed APKG export feature (spec 003): 61 package tests pass, fixed ID computation bug for ARM64e, integrated export types into LibraryPrototypeView.swift. Documentation and quickstart evidence updated. |
| 0.5.0 | 2026-08-20 | Completed Spec Kit tasks T030-T033: OpenAI-compatible provider adapter with health checks, credential loaders, comprehensive safety tests, and fully-localized provider settings UI. |
| 0.4.4 | 2026-08-17 | Accepted ADR-003 for GRDB 7/system SQLite, explicit migrations/transactions, and the one-time SwiftData compatibility import; completed Spec Kit task T002. |
| 0.4.1 | 2026-08-16 | Audited the real repository and Xcode state, verified iOS/macOS builds, corrected Release 1.0 account/sync scope, decision counts, and the completed native target checkpoint. |
| 0.4.0 | 2026-08-10 | Accepted optional Apple/Google accounts and secure learner-data synchronization as Release 1.0 scope while retaining complete local-only operation. |
| 0.3.9 | 2026-08-10 | Replaced word-only duplicate and review identity with domain-aware lexical-sense deduplication and stable per-card review identity, including legacy review-key migration. |
| 0.3.8 | 2026-08-10 | Added the functional OpenRouter card-generation checkpoint with Keychain storage, explicit cloud consent, structured output validation, proposal preview, and approved local persistence. |
| 0.3.7 | 2026-08-10 | Recorded OpenRouter as the first future cloud AI adapter and Apple Foundation Models as an optional no-API-key on-device provider requiring capability, locale, and quality gates. |
| 0.3.6 | 2026-08-10 | Activated reverse translation with independent scheduling and realigned the current snapshot with the Anki Core validation path toward the original adaptive-learning product. |
| 0.3.5 | 2026-08-10 | Added confirmed transactional import for legacy SQLite APKG cards and energy/time-aware daily new-card limits; modern collections and full-fidelity resources remain open. |
| 0.3.4 | 2026-08-10 | Added the read-only APKG selection and archive-security preflight boundary before extraction or database writes. |
| 0.3.3 | 2026-08-10 | Added persistent prototype Deck/Card records and first-launch-only seeding as the storage boundary required before APKG import. |
| 0.3.2 | 2026-08-09 | Accepted ADR-004 and replaced fixed prototype intervals with persistent, reference-checked FSRS-6 memory state and scheduling. |
| 0.3.1 | 2026-08-09 | Added the verified-build SwiftData persistence checkpoint for prototype ratings, progress, and due dates; production persistence ADR/repositories and FSRS remain open. |
| 0.2.2 | 2026-08-01 | Verified the active Xcode 27 toolchain, accepted ADR-011, and advanced the next decision gate to ADR-003. |
| 0.2.1 | 2026-08-01 | Recorded the local Swift 6.4/macOS 27 toolchain audit and the remaining full-Xcode activation blocker. |
| 0.2.0 | 2026-07-21 | Replaced the Flutter/Android implementation path with native Swift/SwiftUI on iOS, iPadOS, and macOS 27; accepted ADR-009/010 and advanced the next gate to ADR-011. |
| 0.1.4 | 2026-07-20 | Accepted ADR-008, selected the Android-only pilot and golden baseline, and advanced the next gate to ADR-002. |
| 0.1.3 | 2026-07-19 | Accepted ADR-001, established the modular monorepo boundary, relocated the vocabulary prototype under experiments, and advanced the next gate to the initial client platform decision. |
| 0.1.2 | 2026-07-15 | Completed the 56-entry Decision Register, classified every source question, aligned ADRs with their milestone gates, and advanced the next task to ADR-001. |
| 0.1.1 | 2026-07-15 | Completed Document 15 and linked requirements to milestones, backlog work, acceptance evidence, and issue governance. |
| 0.1.0 | 2026-07-15 | Created the central completed/remaining-work checklist for repository, documentation, milestones, and post-MVP work. |
