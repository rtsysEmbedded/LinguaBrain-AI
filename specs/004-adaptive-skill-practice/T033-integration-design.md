# T033 Integration Design — Skill Practice Routes

**Status:** Phase A1 (package layer) implemented and tested; Phase A2 (app wiring) not started. Decisions 1–4 are recorded in Section 6; decision 5 is open.
**Date:** 2026-10-13
**Task:** [T033](tasks.md) — integrate app routes and languages.
**Related:** [spec.md](spec.md), [plan.md](plan.md), [2026-10-13 project audit](../../docs/PROJECT_AUDIT_2026-10-13.md) finding A2.

## 1. Acceptance criteria (from tasks.md)

1. Navigation from Today and from weak-skill recommendations reaches the correct practice mode.
2. «مرور پیشنهادی» remains only the queue of due Anki cards; no four-skill practice is mixed into it or substituted for it.
3. Progress reads real evidence.
4. An unavailable mode is explicitly gated.
5. Story localization keys are merged once.
6. Files are members of both app targets.

Staged integration is allowed; the checkbox closes only after all stories are integrated.

## 2. Verified current state

| Area | State | Evidence |
| --- | --- | --- |
| Today → skill practice | Every row calls `PracticeSessionBoundaryView(exercise: nil)`, which always renders the legacy `SkillPracticeView`. | `TodayPrototypeView.swift`, `PracticeComposition.swift` |
| Feature views | `WritingPracticeView`, `GrammarPracticeView`, `ListeningPracticeView`, and `SentenceLearningHistoryView` are referenced only by tests. | Repository search |
| Composition | `PracticeComposition` uses the GRDB repository, the FSRS-6 scheduler, and `UnavailablePracticeEvaluator`, so every attempt is ungraded. | `PrototypeRootView.swift` |
| Writing content | `WritingExerciseRetrieval` has no production implementation. | `PracticePorts.swift` |
| Grammar content | `GrammarExerciseFactory` defines 5 rule codes but no exercise templates; it accepts only `curated` or `reviewed_fixture` sources. | `GrammarExerciseFactory.swift` |
| Listening content/audio | `AppleSentencePlayback` speaks with `AVSpeechSynthesizer`; the contract requires an exact sentence revision and an audio checksum. T027 is open. | `AppleSentencePlayback.swift`, `contracts/listening.md` |
| Evaluators | `WritingEvaluationProvider` has a URLSession transport. Grammar and listening evaluators have only protocol transports (test fakes). None is constructed by the app. | `LinguaBrainAI/Practice/*` |
| Speaking | Capability-gated by the negative pronunciation-provider decision (T028). | `research-pronunciation.md` |
| Progress | Skill rows read `PrototypeStore` (SwiftData); GRDB mastery projections are not shown. | `ProgressPrototypeView.swift` |
| Legacy practice | `SkillPracticeView` (card-based typed/spoken answers) writes skill mastery to SwiftData `PrototypeSkillMasteryRecord`, while the cutover made GRDB the authority for writing, grammar, listening, and speaking. Evidence is therefore split across two stores. | `ReviewPrototypeView.swift`, ADR-017 |

## 3. Proposed architecture

```text
Today ──► SkillPracticeEntry(skill) ──► PracticeCapabilityGate
                                          │ available               │ unavailable(reason)
                                          ▼                         ▼
                          PracticeExerciseCatalog.next(skill)   PracticeUnavailableView(reason)
                                          │
                     ┌────────────────────┼─────────────────────┐
                     ▼                    ▼                     ▼
             WritingPracticeView   GrammarPracticeView   ListeningPracticeView
                     │                    │                     │
                     └──────── PracticeSessionModel ────────────┘
                                          │
                     PracticeSessionService (GRDB, FSRS-6, PracticeEvaluatorRouter)
```

### 3.1 `PracticeExerciseCatalog` (app composition)

The catalog is a single injected value that answers "next exercise for skill S in the active language pair". It uses `AdaptivePracticePlanner` for deterministic ordering (due state, weak mastery, linked errors, fresh context).

| Skill | Source | Port |
| --- | --- | --- |
| Writing | The learner's own cards in the active pair: target word, part of speech, and level, as US2 requires. | `CardBackedWritingRetrieval: WritingExerciseRetrieval` |
| Grammar | A curated, human-reviewed template bank in `Resources/Configuration/grammar-templates.<target>.json`, validated by `GrammarExerciseFactory`. The 5 rule codes move from Swift into the same file. | `CuratedGrammarRetrieval` (Phase C) |
| Listening | Reviewed example sentences of the learner's cards, as exact `Sentence` revisions (Section 7.3). Accepted learner sentences (US6) are a later extension. | `CardSentenceListeningRetrieval` |
| Speaking | None while T030–T032 are gated. | — |

### 3.2 `PracticeCapabilityGate`

A pure function of the active language pair, card and sentence availability, the provider settings, cloud consent, and audio capability. It returns `.available` or `.unavailable(reason)` per skill. Reasons map to localized keys, for example: no cards in this pair, no reviewed grammar templates for this language, AI evaluation not configured, cloud consent missing, sentence audio unavailable, pronunciation scoring not validated. This satisfies criterion 4 without silently falling back.

### 3.3 `PracticeEvaluatorRouter`

A `PracticeEvaluator` that dispatches on `exercise.reviewUnit.skill`:

| Skill | Evaluator | Requirement |
| --- | --- | --- |
| Writing | `WritingEvaluationProvider` with the configured Text provider | Endpoint and model from Settings; Keychain credential; cloud consent for cloud mode |
| Grammar | `GrammarEvaluationProvider` with a new OpenAI-compatible transport and a versioned prompt in `ai-prompts.json` | Same as writing |
| Listening | `ListeningEvaluationProvider` with a new transport and a context resolver bound to sentence revision and audio checksum | Same, plus a sentence audio asset |
| Otherwise | `UnavailablePracticeEvaluator` | — |

The learner's answer is saved before any provider call, as the specification requires. Provider failure yields an ungraded result with retry, reveal, and continue.

### 3.4 Today

- «مرور پیشنهادی» is unchanged.
- The «تمرین مهارت‌ها» rows navigate to `SkillPracticeEntry(skill)`.
- A weak-skill recommendation row uses the lowest GRDB mastery projection among available skills and links to the same entry.

### 3.5 Progress

- Writing, grammar, listening, and speaking rows read GRDB `PracticeMasteryProjection`s.
- The `unknown` state is shown as "no evidence yet", not as 0 %.
- Recognition and recall continue to read `PrototypeStore` until the Anki review route is migrated to GRDB atomically, as the cutover correction in `PROJECT_STATUS.md` requires.

## 4. Phasing

| Phase | Scope | Outcome without AI |
| --- | --- | --- |
| A | Catalog (writing from cards, listening from sentences), capability gate, Today routing, Progress from GRDB, localization keys, both targets | Attempts are saved and shown as honestly ungraded; navigation and gating are complete. |
| B | Evaluator router: writing (existing transport), then grammar and listening transports | Graded feedback and mastery evidence, consent-gated. |
| C | Curated grammar bank after human review; listening audio decision; speaking remains gated | Grammar becomes available; listening audio meets the contract. |

Each phase ends with package tests (Linux harness where possible), deterministic composition and routing tests, and an Xcode 27 build of both app targets.

## 5. Risks

- Grammar content must be human-reviewed (`cleanSource == "curated"`). Machine-drafted templates may be prepared but must not ship as `curated` without review.
- On-device TTS for listening changes the audio source; the asset key must bind sentence revision, locale, voice, and model, or a revised sentence could replay mismatched audio.
- Enabling cloud evaluation sends learner text to the configured provider; consent and the provider's privacy terms apply.
- The app targets cannot be built in the Linux environment; every phase needs a local Xcode 27 build.
- Keeping `SkillPracticeView` as an active route keeps writing skill evidence into SwiftData that Progress (Phase A) no longer reads.

## 6. Decisions

| # | Question | Decision (2026-10-13) |
| --- | --- | --- |
| 1 | Writing source | **The learner's own cards** in the active language pair (matches US2). |
| 2 | Grammar templates | **Drafted by the assistant, reviewed by the Product Owner.** Drafts are stored with a pending-review marker and are never accepted as `curated` until a human reviews them. |
| 3 | AI evaluation | **Enabled through the configured Text provider, with cloud consent.** Without a provider or consent, attempts are saved and shown as ungraded. |
| 4 | Listening audio | **On-device Apple speech synthesis**, with the audio asset key bound to sentence revision, locale, and voice. |
| 5 | Legacy `SkillPracticeView` | **Open.** Recommendation: remove it from the skill-practice route in Phase A2 so that skill evidence is written only to GRDB. |

## 7. Implementation record

### 7.1 Phase A1 — package layer

New types in `LinguaBrainApplication/Practice/`:

| File | Types | Purpose |
| --- | --- | --- |
| `PracticeCatalog.swift` | `PracticeCardCandidate`, `PracticeCardSource`, `CardBackedWritingRetrieval`, `CardSentenceListeningRetrieval`, `ListeningExerciseDescriptor`, `PracticeOccurrence` | Card-based writing and listening exercises, ordered by `AdaptivePracticePlanner` with persisted projections. |
| `PracticeCapabilityGate.swift` | `PracticeCapabilityGate`, `PracticeCapabilityFacts`, `PracticeAvailability`, `PracticeAvailabilityReason`, `PracticeGrading` | Pure per-skill availability decision; every unavailable mode has an explicit reason. |
| `PracticeEvaluatorRouter.swift` | `PracticeEvaluatorRouter` | Dispatches evaluation by skill; an unrouted skill gets an explicit `providerUnavailable` result instead of another skill's evaluator. |
| `PracticeProgress.swift` | `PracticeProgressReading`, `PracticeUnitProgress`, `PracticeSkillProgress`, `PracticeProgressCalculator` | Read-only progress from persisted projections; no evidence is `nil`, not 0 %. |

`GRDBPracticeRepository`, `InMemoryPracticeRepository`, and `FileBackedPracticeRepository` conform to `PracticeProgressReading`. Tests: `PracticeIntegrationCatalogTests` (10 tests). The full package suite passes on the Linux Swift 6.4.1 harness (204 tests, 0 failures); an Xcode 27 run is still required.

### 7.2 Session scope correction

`PracticeSessionService.prepare` previously restored session state from **all** attempts of a review unit. A unit that had been completed once therefore reopened in its finished state and could not be practised again. Session state is now restored only from attempts whose `exerciseID` matches the prepared exercise; each exercise is one occurrence of the unit. `PracticeOccurrence.exerciseID(for:attempts:)` resumes an occurrence whose last attempt is still `pending` and otherwise derives a new deterministic ID from the unit's stable key and the number of earlier occurrences. Mastery projections and attempt history are unaffected and remain per unit.

### 7.3 Listening material: open question

The listening contract requires a reviewed translation. The package accepts only candidates marked `.reviewed` (`PracticeCardCandidate.ExampleReview`); the app adapter (Phase A2) decides that mark.

The app store does not record per-card review. `PrototypeStore.provenance(of:)` distinguishes only:

| Provenance | Rule | Contents |
| --- | --- | --- |
| `imported` | The card record has a `sourcePackage`. | Cards from imported Anki packages. |
| `generated` | No `sourcePackage`. | Built-in seed cards; single cards saved with «تأیید و افزودن» after a preview; and cards from the batch and passage flows in `AddWordPrototypeView`, which are saved without a per-card preview. |

Mapping `generated` to `.reviewed` would therefore admit unreviewed AI output from the batch flow. The options are:

1. Persist a review marker on cards (seed and preview-approved cards are reviewed; batch and imported cards are not). This is a SwiftData schema addition with a default value.
2. Treat only seed cards as reviewed until a marker exists.
3. Accept `generated` as reviewed and document the exception.

Option 1 meets the contract; it is a decision for the Product Owner before Phase A2.
