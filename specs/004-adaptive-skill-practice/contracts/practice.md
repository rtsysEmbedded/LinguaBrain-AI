# Practice contract

The application saves the response before invoking an evaluator. Evaluator failures return the saved attempt as `pending`; they do not create an incorrect result. A stale evaluator result is discarded by request generation. Reveal/copy assistance suppresses independent-recall credit, skip is distinct from wrong, and retry appends help history without replacing the original attempt.

Ports are provider-independent: text evaluation, sentence audio, recording, and pronunciation assessment expose typed asynchronous errors and cancellation. Providers can propose feedback only; repository/application code owns mastery, history, and scheduling. `ReviewUnit.stableKey` is learner/objective/skill/sentence-revision scoped and deterministically maps to its ID; an explicit ID is accepted only for verified migration.

## T006 migration contract (accepted bridge; review boundary open)

`LegacyPracticeSnapshot` is a read-only, Sendable transfer object populated by an app-owned SwiftData compatibility bridge. It contains the complete relevant card, review, mastery, and learning-event fields from the prototype. `LegacyPracticeMigrationPlanner` validates keys, supported recognition/reverse directions, card references, grades, numeric FSRS values, and mastery counts before emitting rows.

The migration sink contract is deliberately narrow:

- `apply(LegacyMigrationRow)` must be idempotent by its source-scoped row key and must preserve the original legacy UUID/ID and all timestamps.
- `save(LegacyMigrationCheckpoint)` records the last committed row, expected row count, and plan digest. Replaying a row after an interruption is allowed and must not duplicate it.
- A final count and digest verification is required before any future production writer switch.

Only `recognition` and `recall` legacy mastery/events are mapped to the retained legacy evidence tables. Writing, grammar, listening, and speaking receive explicit `.unknown` seeds with no inherited history. The app bridge opens the exact SwiftData store read-only, backs it up before reading, validates staging, and injects the GRDB repository only after activation. The existing legacy review writer is blocked after activation; source and backup retention remain available for recovery.

## T002 normative evaluation and state contract

The contract version is `practice-evidence-v1`. Evaluators return a normalized proposal with `outcome` (`correct`, `partial`, `incorrect`, or `ungradable`), a score in `[0, 1]`, optional confidence in `[0, 1]`, typed feedback, rule/span references, content/revision identity, and provider/model/prompt provenance. `ungradable` is persisted as `unavailable`; it is never converted to `incorrect`. The current `EvaluationResult` type is a deliberately smaller pre-T004 transport seam, so it does not yet expose every field in this normative schema.

The review application boundary owns the commit. It saves the original response and a `pending` attempt first, then atomically persists the validated result and applies the policy once. It is the only boundary allowed to update mastery or invoke FSRS. Providers can propose scores and feedback but cannot write attempts, mastery, history, or schedules.

| State | Attempt/history effect | Mastery effect | FSRS effect | Required behavior |
| --- | --- | --- | --- | --- |
| `answering` | No attempt before submit; append help evidence | None | None | Hint is assistance, not success |
| `evaluating` | Persist original response as `pending` before provider call | None | None | Duplicate submit returns the same pending attempt |
| `feedback` | Persist one validated final result and feedback | Apply policy once only if independent | Schedule once only for eligible final result | Preserve first attempt and first failure |
| `revealed` | Persist reveal help even without submit | None | None | Reveal/copy cannot earn recall credit |
| `unavailable` | Preserve response and unavailable result | None | None | Provider failure/cancellation is not wrong |
| `finished` | No new attempt; close session | None | None | Repeated continue is an idempotent no-op |
| `skipped` result | Persist a distinct skipped attempt/event | None | Leave schedule unchanged | Never classify skip as incorrect |
| `retry` action | Append retry help; retain earlier attempts/help | No direct effect | No direct effect | Only the retry's independent final result may schedule |

For fixed clock `t = 1,000`, the deterministic contract fixture uses these values: independent correct = score `1.00`, mastery contribution `+1.00`, one `good` schedule to due `87,400`; independent partial = `0.50`, `+0.50`, one `hard` schedule to due `44,200`; independent incorrect = `0.00`, `+0.00`, one `again` schedule to due `1,600`; skipped/revealed/copied = `0.00`, `+0.00`, no scheduler call; unavailable = no score, `+0.00`, no scheduler call; retry after reveal followed by independent correct = first attempt contributes `0`, retry contributes `+1.00`, with exactly one schedule call for the retry. These due dates are scheduler-fake fixtures for contract tests, not claims about current prototype output.

The current implementation audit found that `PracticeSessionService.swift` is the actual application file for session intents; `PracticeReviewService.swift` does not exist. `PracticeSessionService` correctly saves before evaluation, retains attempts, handles provider failure/cancellation as unavailable, and rejects stale generations. It does not yet persist reveal-before-submit or retry help, expose `skip`, make repeated `continue` a no-op, represent `partial`, or apply mastery/FSRS. Those gaps remain open under T004/T006/T007 and are not silently reclassified as completed work.

## Sentence and identity invariants

`Sentence` is immutable by `(id, revision)`. `originalLearnerResponse`, `minimalCorrection`, and `naturalVariant` are separate values; accepting or editing a correction creates a new revision and never overwrites the original response. Validation status, provider/model/prompt provenance, rule references, and lexical references travel with the revision. A `ReviewUnit` identity is deterministic over learner, objective, skill, and sentence revision. An `ExerciseInstance` is a session presentation and cannot own mastery or scheduling state.

Attempt idempotency is keyed by the stable request identity; replays do not create another attempt or another mastery/FSRS application. Late results must match both the attempt and request generation. File-backed and in-memory repositories are test fakes; only the GRDB adapter is production persistence. Migration is source-scoped and maps only legacy recognition/reverse evidence. New writing, grammar, listening, and speaking objectives start unknown with no inherited due date, score, history, or FSRS state.
