# Feature 004 data model

`Sentence.id` identifies a learner sentence and `revision` is immutable content identity. A `ReviewUnit` is independently keyed by skill, objective, and sentence revision; writing, grammar, listening, and speaking never share review state. `Attempt` is durable learner evidence and `HelpEvent` records hint, reveal, copying, and retry assistance. `TypedFeedback` and `RuleReference` are evaluator proposals.

Outcomes are `correct`, `incorrect`, `skipped`, `unavailable`, or `pending`; unavailable and pending never count as wrong. Independent recall is only a correct attempt without reveal/copy assistance. The state machine is `answering → evaluating → feedback`, with `revealed → answering` on retry and `feedback/revealed/unavailable → finished` on continue. Help history is append-only across retry, and the first attempt remains in the attempt collection. Legacy recognition/reverse history remains attached to its original objective; ambiguous history is preserved as source evidence and is not copied into four fabricated skills. Persistence uses the ADR-003 GRDB adapter for production and the file-backed/in-memory stores only as test fakes; transactions are atomic and attempt IDs are idempotent.

## T006 migration and controlled cutover mapping

The current prototype source is the SwiftData model set in `apps/learner/App/PrototypeModels.swift`. The app bridge takes a save-disabled snapshot after creating a verified backup; it never edits or deletes that store. The physical destination prepared by `practice_002_legacy_migration_staging` is retained legacy evidence, and GRDB is activated only after reconciliation.

| SwiftData source | Source fields | GRDB destination / rule |
| --- | --- | --- |
| `PrototypeCardRecord` | `id`, `deckID`, `position`, `german`, `persian`, `article`, `level`, `partOfSpeech`, `example`, `exampleTranslation`, `examplesJSON`, `sensesJSON`, `domain`, `createdAt`, `sourceIdentifier`, `sourcePackage`, `sourceLanguageTag`, `targetLanguageTag`, media asset IDs and filenames | `practice_legacy_cards`; `legacy_card_key = card::<sourceStoreID>::<cardID>`. Text, provenance, language tags, timestamps, and media references are copied exactly. External media bytes remain owned by the retained source/media store. |
| `PrototypeReviewRecord` | `id`, `wordKey`, `gradeRawValue`, `reviewedAt`, `dueAt`, `stability`, `difficulty`, `phaseRawValue`, `learningStep`, `scheduledDays`, `elapsedDays`, `algorithmVersion` | `practice_legacy_reviews`; `legacy_review_id` is the original UUID and `legacy_review_key` is source-scoped. `card:<uuid>` maps to recognition; `::reverse` maps to reverse. `::mixed`, malformed keys, ambiguous text keys, invalid grades, and orphan rows are retained in the source and block the plan. |
| `PrototypeFSRSMemoryState` / `PrototypeFSRSSchedule` | stability, difficulty, phase, learning step, last review, due date, scheduled days, elapsed days | No recomputation. The values are preserved in the review row, including the original `algorithmVersion`; the four new skills do not inherit this state. |
| `PrototypeSkillMasteryRecord` | `id`, `cardID`, `skillRawValue`, `score`, `attempts`, `correct`, `lastUpdated` | `practice_legacy_mastery`, only when the skill is `recognition` or `recall`. Other skills are excluded from the new plan but remain in the retained source; no new writing/grammar/listening/speaking history is fabricated. |
| `PrototypeLearningEventRecord` | `id`, `cardID`, `skillRawValue`, `correct`, `occurredAt`, `responseTimeMilliseconds`, `answer`, `expectedAnswersJSON` | `practice_legacy_events`, only for recognition/recall. Original event UUID, answer, expected answers, correctness, and timestamps are retained. Response text is not logged. |
| `PrototypeStore.grades`, `dueDates`, `memoryStates` | in-memory review projections | Not migrated as independent rows; they are rebuilt from the durable review records and must not be counted a second time. |

For every legacy card the plan emits four `LegacyNewSkillSeed` values for writing, grammar, listening, and speaking with `PracticeMasteryState.unknown`. These are future objective seeds, not attempts, mastery, due dates, or FSRS records.

The plan digest and source-scoped primary keys make reruns idempotent. A checkpoint records the last committed row and digest. A failed row or checkpoint can be retried safely; the retained SwiftData source is the recovery authority until an approved cutover and recovery window have completed.

## T002 contract audit: state effects and scoring policy

The normative policy version is `practice-evidence-v1`. Scores and confidence are normalized to `[0, 1]`; `partial` is an evaluator-level result and is not the same as `incorrect`. `ungradable` maps to the persisted `unavailable` outcome. The application review boundary, not an evaluator, owns the single transaction that appends history and—only for eligible independent outcomes—updates mastery and calls the pinned FSRS scheduler.

| State/result | Stored history | Mastery contribution | FSRS effect | Assistance/retry rule |
| --- | --- | --- | --- | --- |
| `answering` | No attempt until submit; hint events are append-only session evidence | None | None | Hint does not create recall credit |
| `evaluating` / `pending` | Save the original response and pending attempt before evaluation | `0` | No schedule change | Provider work may finish, fail, or be cancelled |
| `feedback` + independent `correct` | Append one graded attempt and validated feedback/rules | `+1.00` | One scheduler call using the accepted rating | Duplicate submit and replay are idempotent |
| `feedback` + independent `partial` | Append one graded attempt and typed partial feedback | `+0.50` | One scheduler call using the policy's `hard` rating | Partial is never upgraded by copied feedback |
| `feedback` + independent `incorrect` | Append one incorrect attempt; preserve the first failure | `+0.00` | One scheduler call using the policy's `again` rating | Later retry is a new attempt, not a rewrite |
| `skipped` | Append a skipped attempt or explicit skip event | `+0.00` | Leave due date and FSRS state unchanged | Distinct from incorrect |
| `revealed` | Persist reveal help; no answer is required | `+0.00` | No schedule change | Reveal cannot earn independent recall |
| copied answer | Persist `copiedAnswer` help linked to the attempt | `+0.00` | No schedule change | Copied success is assisted, never independent |
| `unavailable` / `ungradable` | Preserve response as unavailable and retain provider error class without private payload | `+0.00` | No schedule change | Never mark the learner wrong |
| `retry` | Append retry help and preserve the first attempt and all earlier help | No contribution by itself | No schedule change by itself | Only the retry's eligible final result may schedule once |
| `finished` | Close the session; do not append another attempt | None | None | Repeated continue is an idempotent no-op |

The following fixed-clock examples are the contract fixtures for `t = 1,000` seconds. They use a deterministic scheduler fake to make the policy numeric; they do not claim that the current prototype's SwiftData scheduler is the production implementation.

| Example | Normalized score | Mastery contribution | Expected scheduling fixture |
| --- | ---: | ---: | --- |
| Independent correct | `1.00` | `+1.00` | `good`, due at `87,400` (`+24h`) |
| Independent partial | `0.50` | `+0.50` | `hard`, due at `44,200` (`+12h`) |
| Independent incorrect | `0.00` | `+0.00` | `again`, due at `1,600` (`+10m`) |
| Skipped | `0.00` | `+0.00` | no scheduler call; due remains unchanged |
| Revealed answer | `0.00` | `+0.00` | no scheduler call |
| Copied answer | `0.00` | `+0.00` | no scheduler call |
| Provider unavailable | unavailable | `+0.00` | no scheduler call; attempt remains ungraded |
| Retry after reveal, then independent correct | first `0.00`, retry `1.00` | one `+1.00` contribution | one `good` call for the retry only; first attempt remains assisted |

Current code alignment is intentionally explicit: `PracticeEvidencePolicy` already enforces the zero contribution for reveal/copy, skip, unavailable, and pending, while `PracticeSessionService` persists before evaluation and rejects stale results. Partial scoring, durable skip/reveal-before-submit events, retry-event persistence, idempotent `continue`, and the mastery/FSRS application transaction remain implementation work owned by T004/T006/T007; they are not claimed as complete by T002.

## Retention and recovery policy

The exact SwiftData source and any present `-wal`, `-shm`, or `-journal` sidecars are copied before the read-only snapshot. The backup manifest contains file sizes and SHA-256 digests. The source remains untouched and read-only after activation; the backup is retained with no automatic expiry or deletion in this release. The current bridge keeps the receipt in runtime state and discovers no arbitrary store path. A future release must persist a user-visible recovery-window marker and obtain an explicit retention/deletion decision before removing either source or backup.
