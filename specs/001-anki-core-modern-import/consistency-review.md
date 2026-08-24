# Spec Kit Consistency Review

**Feature:** Anki Core Modern Import and Offline Review Gate  
**Review date:** 2026-08-24  
**Reviewer:** Codex

## Scope

This review compares the feature specification, plan, task list, project status, README, changelog, decision register, and current repository state. It does not change runtime behavior.

## Findings and resolutions

| Finding | Resolution |
|---|---|
| T016 was previously described as a completed gate in older handoff notes, while the current task acceptance remains open. | Current task list and project status now explicitly record T016 as partial, with the two failing app tests and missing macOS Test Action. |
| Project status still named T004E/T025–T029 as the primary deliverable even though T016 is the active prerequisite. | Primary deliverable updated to finish T016, then close T017–T019 before advancing to later feature work. |
| Modern Anki schema 18/`collection.anki21b` work appears in the repository roadmap but is deferred by this feature. | The feature boundary remains explicit: modern import belongs to the separate Spec Kit feature; this feature owns the legacy APKG and offline-review gate. |
| iCloud backup is present in the product status but is not equivalent to full multi-device sync. | Status and task evidence retain the distinction: card backup/recovery is implemented; review-event sync, tombstones, and concurrent conflict resolution remain future work. |
| The decision register contains 62 stable IDs while an older changelog entry mentions 56. | The register's current count is authoritative; the 56-entry text is historical release history and is not changed. |

## Structural checks

- Feature artifacts `spec.md`, `plan.md`, `tasks.md`, `research.md`, `data-model.md`, and `contracts/` exist.
- T016 remains unchecked because its acceptance evidence is incomplete.
- T017 and T018 are checked only after this review and the evidence updates are committed.
- No credentials, private APKG files, or raw learner content are added by this review.

## Remaining risks

- The iPhone/iPad application test runner can hang after reporting failures; a deterministic CI/test-runner configuration is still needed.
- The macOS scheme has no Test Action, so macOS XCTest evidence is currently build-only.
- The two failing regression tests must be diagnosed before the offline review gate can be accepted.
