# Implementation plan — Feature 004

Date: 2026-09-06. Status: T001–T010 verified; T011 and later remain open. ADR-017 is accepted for the controlled cutover described below.

## Baseline and architecture

Swift 6.4; native SwiftUI/Observation on iOS/iPadOS/macOS 27. Verified baseline remains macOS `26A5416b`, Xcode `27A5228h`, Swift `6.4.0.27.1`. A future implementer must compare the actual toolchain and follow `AGENTS.md` if it differs. Do not lower the baseline to match package manifests or older examples.

Views send intents to small `@MainActor @Observable` feature models. Application services own exercise creation, submission, reuse, and session selection; Domain owns portable entities and versioned educational policies. Protocol-driven AI/media/persistence adapters are composed in the app. `Today` keeps «مرور پیشنهادی» as a simple Anki due-card route; it must not inject or select four-skill exercises. Those exercises remain an explicit, separate «تمرین مهارت‌ها» route. No new provider or database calls in `ReviewPrototypeView.swift`; no global service locator; no extra god-model in `PrototypeStore`.

## File ownership and destinations

All paths below are repository-relative; new destinations are intentional, not claims that files exist.

| Owner | Scope |
| --- | --- |
| Integrator | `apps/learner/App/ReviewPrototypeView.swift`, `PrototypeModels.swift`, `PrototypeRootView.swift`, `TodayPrototypeView.swift`, `ProgressPrototypeView.swift`, `App/Practice/PracticeComposition.swift`, project file and package manifest |
| Domain/core | `packages/LinguaBrainKit/Sources/LinguaBrainDomain/Practice/`, `Sources/LinguaBrainApplication/Practice/`, existing `AdaptiveLearningPlanner.swift` |
| Persistence | `packages/LinguaBrainKit/Sources/LinguaBrainPersistence/Practice/`, app compatibility import, repository contract tests |
| Text AI | `packages/LinguaBrainKit/Sources/LinguaBrainAI/Practice/`, provider contract tests; reuse existing configuration and credentials via injected ports |
| Media | `packages/LinguaBrainKit/Sources/LinguaBrainMedia/Practice/`, Apple adapters under `apps/learner/App/Practice/Audio/` |
| UI | `apps/learner/App/Practice/Shared/`, `Writing/`, `Grammar/`, `Listening/`, `Speaking/`, `History/` |
| Localization/integration | `apps/learner/Resources/Localization/{fa,en,de}.json`, `Localizable.xcstrings`, navigation and shared build wiring |

Avoid competing edits to shared files. Each story supplies a localization key/value proposal under this feature; one integrator merges catalogs. Package target registration and Xcode membership are owned by the integrator; most story work adds files within existing targets. Do not create a separate package for each mode.

## Foundational contracts (T002–T006)

Extend existing `LearningObjective`, `LearningEvent`, `Sentence`, `SkillMastery`, and pinned scheduler seams rather than duplicating them. Keep generation/export callers source-compatible with explicit mapping/migration tests.

- Sentence identity and revision; original response, correction and natural variant relation; target/source language; learner ownership; validation and provider/model/prompt provenance; rule/word references.
- Stable learner/objective ReviewUnit separate from exercise instance and displayed card. Content wording edits do not silently erase past evidence; a meaning/objective change has explicit identity behavior.
- Attempt with session/exercise/revision IDs, original response, help/reveal/skip/retry events and times, evaluator result/version/confidence, recording reference if allowed, and idempotency identity. Transport failure is not an incorrect observation.
- Normalized evaluation: correct/partial/incorrect/ungradable, spans and typed error tags, expected content, minimal correction, optional natural variant, explanation, confidence and provenance. Listening uses semantic dimensions; grammar separates explanation from demonstration; pronunciation uses audio evidence and an explicitly versioned scale.
- Versioned policy maps eligible observations into mastery and FSRS. Help/reveal and copied retries never count as independent success. Persist first failure and corrective practice without counting one exercise multiple times as independent retrieval. Score upgrades must not reinterpret old history silently.
- Ports: exercise repository, attempt transaction, sentence library, evaluation provider, sentence playback, audio capture and pronunciation assessment. Each async result carries request/attempt/content revision identity.

## Persistence prerequisite and bounded scope

ADR-003 selects GRDB 7. T005 provides the production repository. The current T006 bridge and its application review/mastery/FSRS owner are implemented for migration rehearsal and controlled activation; SwiftData compatibility models remain for read-only recovery. Do not silently adopt SwiftData as production, dual-write, or migrate unrelated accounts/cloud features.

The product owner approved ADR-017 and the controlled cutover rules. The bridge still uses synthetic app fixtures for repeatable verification; no live learner store is opened by the test suite. The exact source URL, backup manifest, and recovery action are implemented at the app composition boundary. The final writer switch is explicitly deferred until `ReviewPrototypeView` writes through the GRDB review route; blocking the existing SwiftData review writer before that route exists is invalid.

### T006 implementation and composition boundary

The prototype inventory is explicit: `PrototypeCardRecord` owns stable card/content and provenance fields; `PrototypeReviewRecord` owns recognition/reverse review identity and full FSRS state; `PrototypeSkillMasteryRecord` and `PrototypeLearningEventRecord` own objective evidence; `PrototypeStore.grades`, `dueDates`, and `memoryStates` are rebuildable in-memory projections. The app bridge is now wired through explicit root injection, with the normal app content gated until cutover is active.

The composition root performs these exact changes in order once the remaining T006 review boundary is complete:

1. Keep the current SwiftData URL and a verified backup/retention marker untouched; create/open the GRDB URL through the injected `GRDBPracticeRepository` and run ordered migrations.
2. On the app compatibility boundary, use the existing SwiftData `ModelContainer`/`ModelContext` to fetch `PrototypeCardRecord`, `PrototypeReviewRecord`, `PrototypeSkillMasteryRecord`, and `PrototypeLearningEventRecord` into `LegacyPracticeSnapshot` batches. The app bridge owns SwiftData imports; Domain/Application remain framework-free.
3. Run `LegacyPracticeMigrationPlanner` and `LegacyPracticeMigrationRunner` into the GRDB legacy staging tables. Persist checkpoints and verify source-scoped counts, digest, card/review IDs, due dates, FSRS versions, state values, timestamps, foreign keys, and representative Unicode content.
4. Keep recognition/reverse rows as retained legacy evidence. Create only unknown seeds for writing, grammar, listening, and speaking; do not derive attempts, mastery, or schedules from legacy data.
5. During an approved maintenance boundary, stop the old writer, complete a final snapshot/reconciliation, make GRDB the one authoritative writer, and retain the untouched SwiftData store through the documented recovery window. Do not dual-write.
6. Only after verification and recovery sign-off remove SwiftData from runtime composition; retain the bridge and fixtures for the supported compatibility window.

The remaining post-cutover decisions are outside this slice: removal of SwiftData compatibility models, deletion/retirement of retained backups, and any migration of non-recognition/reverse evidence. T011 and later stories remain blocked by their declared dependencies.

Legacy direct/reverse schedules retain IDs, due dates, algorithm versions, counts and history. Newly separated skills start with explicit unknown/new state unless verified historical evidence can be mapped safely; retain ambiguous legacy evidence as legacy instead of fabricating certainty.

## Incremental delivery and state

1. Confirm scope/platform/storage evidence and freeze shared contracts.
2. Complete persistent core, ports, deterministic fakes, and reusable UI shell.
3. Deliver writing end-to-end, then sentence reuse/adaptive selection (US2 + US6): this is the smallest dynamic-learning demonstration.
4. Grammar and listening use the same accepted sentence and attempt contracts; each can be tested independently with seeded content.
5. Speaking consumes a separately validated audio-assessment capability. Research may start early; production scores wait for evidence.
6. Integrate navigation/progress, localization, data ownership, and multi-platform regression evidence.

Session state and help provenance must survive rerender/navigation where promised. Stop audio on next/exit; await capture completion through its API, not a fixed sleep. Ignore late callbacks from old exercises. Persist before reporting local success. Missing content is an empty state, not an endless loading indicator. A completed session does not requeue unknown items forever; future repetition belongs to a bounded session policy and scheduler.

## AI and audio selection

Reuse configurable Text/Audio provider settings and credential loading. Define provider-independent normalized contracts first; bind a specific transport in its adapter. Check current official protocol docs when implementing. No chosen model/service is assumed to provide phoneme scores. Provider output is untrusted proposal data: validate IDs, spans, language, bounded fields and score scale; preserve uncertainty. Pronunciation research must define a benchmark and scoring acceptance criteria before enabling a provider, plus cost/latency and supported locales. A negative capability result is a valid research outcome but does not complete the speaking story.

## Verification and delivery gate

Use existing test targets plus explicit manifest/project registration when needed. Foundation tests cover isolated schedules, assistance policies, idempotency, rollback, migration/restart and content identity. T008 uses the existing comprehensive app-level migration suite at `apps/learner/Tests/LegacyPracticeMigrationTests.swift` as the documented replacement for the originally named `PracticeMigrationTests.swift`; no duplicate migration path is introduced. Story tests cover meaning-preserving correction, alternative valid answers, negation/agent mistakes, noisy audio and cancellation. Reuse tests cover acceptance/rejection, revision, duplicate prevention, new-context transfer, ownership deletion and seeded plan replay.

Record repeatable commands, toolchain, destination and results in `verification.md`. Use both app schemes (`LinguaBrain` and `LinguaBrain Mac`), package tests and meaningful UI smoke on iPhone/iPad/Mac. Any missing test action, physical device or provider access is recorded as pending; builds alone do not certify learning behavior or pronunciation. No fabricated pass counts or silently skipped gates.
