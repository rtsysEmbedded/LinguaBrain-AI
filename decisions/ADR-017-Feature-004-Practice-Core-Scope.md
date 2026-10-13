---
title: "ADR-017: Feature 004 practice-core scope and controlled cutover"
status: accepted
date: 2026-09-04
---

# ADR-017: Feature 004 practice-core scope and controlled cutover

Feature 004 establishes reusable sentence revisions, independent skill ReviewUnits, assistance-aware evidence, and provider-independent ports while preserving the Anki/offline gate. Existing recognition/reverse history remains authoritative and is not duplicated into writing, grammar, listening, or speaking. Production persistence follows ADR-003 through the pinned GRDB adapter. Pronunciation scoring remains capability-gated and incomplete until audio-based calibration evidence exists.

## Approval record

Product-owner approval of the controlled Feature 004 cutover rules was supplied in the implementation authorization on 2026-09-04. The approver's personal name was not supplied in the authorization; this record intentionally records the role and date only. The accepted scope is limited to T001, T005, and T006 and does not authorize T007–T009, UI stories, provider evaluation, or the four new skill stories.

## Accepted cutover rules

1. Identify the exact SwiftData store through the existing `PrototypeStore` configuration URL; never search for or guess a store file.
2. Create a manifest and SHA-256-verified backup of the store and present `-wal`, `-shm`, or `-journal` sidecars before reading the source. Retain the source and backup; this implementation never deletes them.
3. Read SwiftData through an app-only, save-disabled compatibility container. Stage only recognition and reverse-translation card/review/mastery/event evidence, retaining original IDs, card references, timestamps, due dates, FSRS fields, and provenance.
4. Seed writing, grammar, listening, and speaking as explicit `.unknown` objectives with no attempts, mastery, or schedule inferred from legacy records.
5. Use source-scoped uniqueness, foreign keys, deterministic plan digests, durable checkpoints, idempotent upserts, row-level atomicity, final reconciliation, and a final GRDB activation boundary. Any failure remains recoverable and leaves GRDB inactive.
6. Once the boundary is verified, GRDB is the only Feature 004 practice writer. The existing SwiftData practice writer is blocked and the source remains read-only for recovery. The backup is retained until an explicit later release decision; there is no automatic retention expiry in this task.

## Implementation evidence (2026-09-04)

The existing SwiftData prototype has been inventoried without opening or modifying the learner store. `PrototypeCardRecord` supplies card text, language pair, lexical JSON, provenance, timestamps, and media references. `PrototypeReviewRecord` supplies the original review UUID, `wordKey`, recognition/reverse direction suffix, grade, due date, complete FSRS memory/schedule values, and algorithm version. `PrototypeSkillMasteryRecord` supplies recognition/recall mastery counters and timestamps; `PrototypeLearningEventRecord` supplies the original event UUID, skill, correctness, timing, answer, expected answers, and occurrence timestamp. `PrototypeStore.grades`, `dueDates`, and `memoryStates` are projections and are not independent migration inputs.

The package contains the tested mapper and GRDB staging schema (`practice_002_legacy_migration_staging`). The app bridge creates a verified backup, reads the exact SwiftData store without save permission, runs the existing planner/runner, reconciles counts/digests/foreign keys/content, and can activate the injected `GRDBPracticeRepository` only after validation. The retained SwiftData source remains the recovery authority. The app gate prevents the legacy review writer from operating after activation; no dual-write or source mutation is performed. This proves the migration bridge, not the complete T006 review/scheduler boundary.

### Controlled composition boundary

The bridge is injected at the application root through `PracticeCutoverCoordinator`; Domain and Application do not import SwiftData or GRDB. The runtime waits for backup, migration, validation, and activation before exposing the normal app content. Runtime SwiftData models remain for read-only compatibility and recovery in this task. `PracticeSessionService.swift` is the actual session-intent file; no `PracticeReviewService.swift` or application mastery/FSRS owner exists yet, so T006 remains open until that boundary is delivered and verified. Removal of those models, retirement of the backup, and any future migration of non-recognition/reverse history require a separate approved decision.
