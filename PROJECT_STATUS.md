---
title: Project Status and Delivery Checklist
document_id: LB-STATUS
version: 0.3.3
status: Active
last_updated: 2026-08-09
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

| Field | Current value |
| --- | --- |
| Current phase | M0 — Specification baseline and implementation preparation |
| Product scope | German–Persian offline-first native Apple MVP (iOS/iPadOS/macOS 27) |
| Documentation | Documents 01–15 complete as reviewed drafts |
| Architecture baseline | Native Swift migration; DOC-10 at 0.4.0, DOC-11/DOC-14 at 0.3.1, and DOC-15 at 0.2.1 |
| Local Apple toolchain | Xcode 27.0 (`27A5228h`) is active with Swift 6.4 and iOS/iPadOS/macOS 27 SDKs; beta-era evidence remains provisional |
| Latest accepted ADRs | Native baseline ADR-009 through ADR-012, plus [ADR-004](decisions/ADR-004-FSRS-Implementation-and-Version.md) for the pinned scheduler |
| Active Git branch | `main` |
| Native platform migration commit | `3c75a70` |
| Visual prototype | Buildable SwiftUI prototype for iPhone, iPad, and Mac; prototype review events/due dates persist through SwiftData, while production repositories and FSRS remain pending |
| Next primary deliverable | ADR-003 — Native Swift persistence/query/migration stack (`LB-DEC-059`, `LB-WI-M0-05`) |
| Current delivery strategy | Anki Core first: secure APKG import and reliable offline review gate before AI and final visual approval |

## Completed foundation

### Repository

- [x] Initialize the Git repository.
- [x] Add `README.md`.
- [x] Add `CHANGELOG.md`.
- [x] Add MIT `LICENSE`.
- [x] Create `docs/`, `decisions/`, `diagrams/`, and `assets/`.
- [x] Add an ADR template.
- [x] Add this project-status checklist.
- [x] Harden `.gitignore` for local projects, secrets, Python, local stores, SwiftPM, Xcode, archives, and generated files.
- [x] Add a buildable static SwiftUI visual prototype for iPhone, iPad, and Mac, with mock data and no production dependencies.
- [x] Define and prototype the ten minimum MVP card surfaces required before final visual-design approval.
- [x] Add a restart-durable SwiftData checkpoint for the 50-word prototype review history and due dates, including save-before-success and recoverable UI error reporting.
- [x] Persist a real local deck and 50 stable card records, seed only an empty installation, and restore card identity/content before review history is loaded.
- [x] Classify and place the vocabulary prototype at `experiments/vocabulary-mvp/` according to [ADR-001](decisions/ADR-001-Repository-Package-and-Module-Layout.md).
- [ ] Configure a Git remote and push `main`.
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

## M0 — Implementation preparation

### Planning and traceability

- [x] Create Document 15 — Implementation Backlog and Requirements Traceability.
- [x] Map every MVP requirement to a milestone, backlog item, acceptance criterion, and test level.
- [x] Create a Decision Register for all 53 source open questions and six supplemental architecture decisions (59 stable IDs).
- [x] Classify decisions as `MVP-blocking`, `MVP-later`, or `post-MVP`, with status, owner, due gate, and required artifact.
- [x] Define issue labels, priorities, dependencies, and Definition of Done.
- [ ] Approve the M1 implementation backlog.

### M0/M1-blocking ADRs

- [x] [ADR-009 — Native Apple client and platform baseline](decisions/ADR-009-Native-Apple-Client-and-Platform-Baseline.md).
- [x] [ADR-010 — Swift package and module layout](decisions/ADR-010-Swift-Package-and-Module-Layout.md).
- [x] ADR-001 and ADR-008 retained as superseded historical decisions.
- [x] [ADR-011 — SwiftUI Observation/state, navigation, and dependency composition](decisions/ADR-011-SwiftUI-State-Observation-Navigation-and-Dependency-Composition.md).
- [x] [ADR-012 — Anki Core first and APKG import boundary](decisions/ADR-012-Anki-Core-First-and-APKG-Import-Boundary.md).
- [ ] ADR-003 — Native Swift persistence/query/migration stack.
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
- [ ] Create the native SwiftUI universal iPhone/iPadOS 27 application and macOS 27 Golden Gate target.
- [ ] Create the local multi-target `LinguaBrainKit` Swift package and composition root.
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

- [ ] Implement sandboxed `.apkg` inspection and import preview.
- [ ] Map supported decks, notes, cards, templates, tags, images, and audio into LinguaBrain-owned records.
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

- [ ] Implement `LearningObjective`, `ReviewUnit`, and independent retrieval contracts.
- [ ] Integrate the selected FSRS implementation behind a scheduler interface.
- [ ] Implement recognition review.
- [ ] Implement Persian-to-German active recall.
- [ ] Record immutable LearningEvents and review history.
- [ ] Update objective-level mastery without AI mutation.
- [ ] Verify that exposure/reveal alone cannot advance mastery and that automatically evaluated exercises do not request self-rating.
- [ ] Provide component/rule-specific feedback and a corrective opportunity.
- [ ] Add deterministic fake-clock and restart test vectors.

**M3 exit criterion:** Building on the accepted Anki Core scheduler, recognition and recall for the same item are scheduled independently, survive restart, and produce reproducible FSRS history.

## M4 — Adaptive intelligence

- [ ] Implement optional daily energy, time, motivation, and mode check-in.
- [ ] Apply named defaults when check-in is skipped or stale.
- [ ] Implement deterministic candidate ranking and stable tie-breaking.
- [ ] Build capability-aware daily sessions.
- [ ] Target weak skills and explain every recommendation.
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

**M6 exit criterion:** All release gates in Document 10 pass and the MVP is ready for a controlled pilot.

## Post-MVP backlog

- [ ] Expanded listening and passive-listening modes.
- [ ] OCR, text, and PDF ingestion with approval workflow.
- [ ] Guided writing and speaking evaluation.
- [ ] Account system and encrypted multi-device sync.
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
