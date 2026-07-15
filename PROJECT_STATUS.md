---
title: Project Status and Delivery Checklist
document_id: LB-STATUS
version: 0.1.1
status: Active
last_updated: 2026-07-15
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
| Product scope | German–Persian offline-first MVP |
| Documentation | Documents 01–15 complete as reviewed drafts |
| Architecture baseline | Versions 0.2.0 and 0.2.1 |
| Active Git branch | `main` |
| Latest architecture commit | `4ff4da9` |
| Next primary deliverable | Decision Register and blocking M0 ADRs |

## Completed foundation

### Repository

- [x] Initialize the Git repository.
- [x] Add `README.md`.
- [x] Add `CHANGELOG.md`.
- [x] Add MIT `LICENSE`.
- [x] Create `docs/`, `decisions/`, `diagrams/`, and `assets/`.
- [x] Add an ADR template.
- [x] Add this project-status checklist.
- [x] Harden `.gitignore` for local projects, secrets, Python, SQLite, Flutter, and generated files.
- [ ] Decide whether `vocabulary-mvp/` belongs under `experiments/`, in the production monorepo, or in a separate repository.
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
- [ ] Resolve MVP-blocking decisions and promote the approved specification set from `Draft` to a versioned baseline.

## M0 — Implementation preparation

### Planning and traceability

- [x] Create Document 15 — Implementation Backlog and Requirements Traceability.
- [x] Map every MVP requirement to a milestone, backlog item, acceptance criterion, and test level.
- [ ] Create a Decision Register for all open questions.
- [ ] Classify open questions as `MVP-blocking`, `MVP-later`, or `post-MVP`.
- [x] Define issue labels, priorities, dependencies, and Definition of Done.
- [ ] Approve the M1 implementation backlog.

### Required ADRs before coding

- [ ] ADR — Repository/package/module layout.
- [ ] ADR — Flutter state management and dependency injection.
- [ ] ADR — SQLite library, ORM/query layer, and migration tooling.
- [ ] ADR — FSRS implementation and version.
- [ ] ADR — ReviewUnit retrieval contracts and evidence-to-rating mapping.
- [ ] ADR — Domain events and transactional outbox strategy.
- [ ] ADR — Local database protection, backup, recovery, and key handling.

### Canonical diagrams

- [ ] System Context diagram.
- [ ] Container and Module Architecture diagram.
- [ ] Core Domain ERD.
- [ ] Review transaction sequence diagram.
- [ ] Adaptive Learning Engine decision-flow diagram.
- [ ] AI pipeline sequence diagram.

## Specification readiness gates

- [ ] Document 16 — Application and Domain Contracts, required before M1 implementation.
- [ ] Document 18 — German–Persian Language Package, required before M2 implementation.
- [ ] Document 17 — Review Engine, FSRS, and ReviewUnit, required before M3 implementation.
- [ ] Document 19 — Security, Privacy, and Threat Model, required before M6 hardening; its minimum protection/backup ADR is still an M0 gate.
- [ ] Document 20 — Verification Strategy and Pilot Protocol, required before pilot enrollment.

## M1 — Domain walking skeleton

- [ ] Create the Flutter application shell.
- [ ] Establish domain, application, infrastructure, and presentation boundaries.
- [ ] Add the first SQLite schema and migration runner.
- [ ] Implement `KnowledgeItem` and its repository contract.
- [ ] Implement learner profile and language-pair configuration.
- [ ] Implement editable onboarding with explicit BCP 47 language roles and a versioned CapabilitySnapshot.
- [ ] Store and retrieve one manual German word fully offline.
- [ ] Add unit and integration tests for the first offline transaction.
- [ ] Verify restart durability and error handling.

**M1 exit criterion:** A manually entered German word can be saved, closed, reopened, and retrieved offline through domain/application interfaces rather than direct UI-to-database access.

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

## M3 — Review loop

- [ ] Implement `LearningObjective`, `ReviewUnit`, and independent retrieval contracts.
- [ ] Integrate the selected FSRS implementation behind a scheduler interface.
- [ ] Implement recognition review.
- [ ] Implement Persian-to-German active recall.
- [ ] Record immutable LearningEvents and review history.
- [ ] Update objective-level mastery without AI mutation.
- [ ] Verify that exposure/reveal alone cannot advance mastery and that automatically evaluated exercises do not request self-rating.
- [ ] Provide component/rule-specific feedback and a corrective opportunity.
- [ ] Add deterministic fake-clock and restart test vectors.

**M3 exit criterion:** Recognition and recall for the same item are scheduled independently, survive restart, and produce reproducible FSRS history.

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
- [ADR index](decisions/README.md)
- [Diagram index](diagrams/README.md)

## Revision history

| Version | Date | Description |
| --- | --- | --- |
| 0.1.1 | 2026-07-15 | Completed Document 15 and linked requirements to milestones, backlog work, acceptance evidence, and issue governance. |
| 0.1.0 | 2026-07-15 | Created the central completed/remaining-work checklist for repository, documentation, milestones, and post-MVP work. |
