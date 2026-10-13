# Feature 004 — Adaptive skill practice

Date: 2026-09-04. Status: accepted scope with T001/T002/T005 verified; T003/T004/T006–T008 remain open. The controlled cutover is governed by accepted ADR-017, but its application review/mastery/FSRS boundary is not yet complete.

## Source and scope

The owner requests readable writing, listening, grammar, and speaking practice; useful help and answer reveal; sentence-level AI feedback; and reuse of corrected learner sentences in future learning. This extends the original Anki-first delivery scope while implementing existing contextual-learning principles.

Authority: repository `AGENTS.md`, `.specify/memory/constitution.md`, accepted ADR-003/004/009/010/011/012, then this feature. Read baseline DOC-02 sections 7–8, DOC-04 Sentence/GrammarRule/Exercise/ReviewUnit, DOC-07 adaptive sessions, DOC-08 correction contracts, DOC-10 scope/roadmap, and DOC-14 feedback/accessibility. Do not replace those entities with a parallel learning model.

DOC-10 currently excludes automatic pronunciation scoring and defers guided writing/speaking to 1.3. Feature 004 now has an accepted foundation and controlled legacy-data cutover, but this does not certify a pronunciation provider, begin a UI story, or silently change release gates. Optional paid-account/distribution work, unrestricted conversation, new platforms, and a complete knowledge graph are outside this feature.

## Stories and acceptance scenarios

### US1 — Understand and complete a practice session (P1)

All four modes use readable, responsive Persian/German/English presentation, explicit instructions, suitable answer entry, graded help, answer reveal, retry, and next-question controls.

Acceptance: on compact iPhone, iPad, and a narrow Mac window, with large supported text sizes and a keyboard visible, controls remain reachable. A learner can reveal without submitting, read the answer, and continue. Hint/reveal/skip are recorded; revealed or copied answers cannot earn independent-recall credit. Retry retains the first attempt and help history. Skipping is distinct from an incorrect answer. End-of-session counts distinguish answered, assisted, skipped, and unavailable evaluation.

### US2 — Write and improve a sentence (P1)

Show a target-language word and its part of speech, then ask for a simple sentence at the learner's level. Do not initially give a model sentence. After submission, offer a minimal correction preserving intended meaning, a short explanation in the configured learner language, and a more natural everyday version where useful. Correct original sentences need not be rewritten; stylistic suggestions are distinguished from errors. Legitimate inflected/separable forms are accepted.

Acceptance: for a verb-position mistake, identify the relevant span/rule, preserve the learner's intent, and propose a valid correction. A correct alternative sentence passes. A provider outage leaves the answer intact and ungraded, with retry/reveal/continue. A correction approved for reuse becomes learner-private sentence content with traceable origin. Meaning ambiguity prompts clarification or an explicitly uncertain suggestion rather than inventing intent.

### US3 — Explain and apply grammar (P2)

Support (a) a sentence with a targeted grammatical problem: explain the problem and optionally correct it; (b) a conjunction/preposition or grammatical construction: explain how it is used and demonstrate it in a sentence. Meaningful explanations in the learner's language are accepted without requiring technical terminology. AI explains the rule, correction, and an appropriate example. Sentence correction, sentence-building, and contextual cloze are scaffolding options, not replacements for the owner's explanation tasks.

Acceptance: equivalent explanations of verb placement after `weil` pass; a wrong explanation does not pass just because a corrected example was copied. Generated error exercises retain a verified clean original and one intended error; ambiguous/unvalidated prompts are not published. Help can reveal part of the rule before the whole answer.

### US4 — Explain a heard sentence (P2)

Play an exact target-language sentence with replay and a slower option. Hide target text and translation before submission/reveal. Ask the learner to explain what they understood in their configured source language. Evaluate meaning, including actors/actions, negation, quantities, time, and relations when present, rather than exact translation wording. After a completed evaluation, show the exact heard sentence and its corresponding translation.

Acceptance: a faithful paraphrase passes; reversed negation/agent receives specific feedback. Audio and transcript always refer to the same sentence revision. Word-pronunciation audio cannot substitute for sentence audio. Missing sentence/audio capability has an explicit empty/unavailable state. A failed evaluator is ungraded; transcript reveal and continue remain available.

### US5 — Repeat a sentence and improve pronunciation (P2, capability gated)

Show and play a target sentence, record its repetition, assess the recording against that target, and offer a defensible pronunciation score with actionable word/sound-level feedback where the selected capability supports it. Provide replay of both reference and own recording, targeted retry, and whole-sentence retry. Rhythm/fluency subscores are optional and must not be fabricated.

Acceptance: assessment consumes actual audio, not only its transcript. Silence, clipping, background noise, low confidence, unsupported language, and capture failure produce a retry/unavailable result rather than a misleading score. A supported provider's scoring interpretation and calibration evidence are recorded before enabling scores. Failure to validate a provider leaves pronunciation scoring incomplete and gated, not marked done through a transcription-only substitute.

### US6 — Learn from previous sentences and mistakes (P1, delivered after US2)

Keep the original attempt, minimal correction, natural variant, validation/provenance, and error-rule links separate. Reuse an accepted sentence in other supported exercises with independent objectives and evidence. Select future activities deterministically from due state, weak skills, recent error patterns, level, time/energy, and available capabilities. Later include a fresh sentence for the same rule to check transfer beyond memorization.

Acceptance: writing error → accepted correction → restart → scheduled grammar/listening practice referencing that revision → a later novel example for the same rule. No content duplication or replay of a single result multiplies mastery. The user can inspect why a sentence was selected, edit/decline reuse, and delete personal content and associated audio according to the deletion contract. Failed/uncertain corrections never silently enter the practice pool.

## Cross-cutting requirements

- «مرور پیشنهادی» فقط صف سادهٔ کارت‌های موعددارِ Anki و رتبه‌بندی همان مرور است: روی کارت فکر کردن، نمایش پاسخ، سپس انتخاب Again/Hard/Good/Easy توسط کاربر. هیچ پاسخ تایپی یا نمره‌دهی خودکار، و هیچ تمرین نوشتن، گرامر، شنیدن یا گفتار در آن ترکیب یا به‌صورت خودکار جایگزین نمی‌شود. این چهار تمرین در بخش و مسیر مستقل «تمرین مهارت‌ها» و با انتخاب آگاهانهٔ کاربر ارائه می‌شوند.
- Independent, stable learner/objective ReviewUnits; preserve existing recognition/reverse FSRS history through migration. Do not manufacture four histories from two legacy schedules.
- Application-owned transactions atomically persist idempotent attempts/events and eligible mastery/schedule effects. Canonical AI content and grading inputs are validated and versioned; providers never mutate learning state.
- Practice session state is explicit: answering, evaluating, feedback, revealed, unavailable, finished. Hint usage is retained across states. Cancellation, duplicate taps, stale results, retry, and restart have defined behavior.
- A learner response is saved before a cloud call; local success does not depend on cloud success. Consent and selected provider capability control outgoing text/audio. Secrets and private content are excluded from logs.
- Offline core review remains complete. Cached validated exercises are usable; free-response AI evaluation may honestly be unavailable offline.
- Sentence media binds exact content revision, locale, voice/model, and playback purpose; revised text cannot reuse mismatched audio.
- Source/target languages are independent of interface language. Preserve RTL/LTR isolation and accessibility.

## Required verification

Per constitution, scheduling, persistence, identity, migration and provider-result handling require meaningful automated tests. Use fixed clocks, IDs, seeded selection, fake providers, and file-backed restart/fault-injection tests. Live model checks use authorized synthetic/owned data and are separate from offline CI. Apple-sensitive work must inspect local SDK declarations and current official documentation; build both app targets. Physical audio QA is mandatory for scoring release. Revalidate beta-specific behavior after toolchain updates.

## Existing-work mapping

- Feature 001 T025: independent mixed-objective scheduling → 004 foundation and US6; original task stays open until verified coverage.
- Feature 001 T026/T027/T031: sentence bundles, reuse and sentence identity → 004 foundation, US4 and US6; collocation/APKG-specific remainder stays with its original scope.
- Feature 001 T034/T035/T037: transcription evidence is a possible capture/transcription dependency, not pronunciation assessment evidence.
- Existing `SkillPracticeView` is prototype evidence, not the accepted new engine. Known defects include shared schedule modes, lexical rather than semantic scoring, word audio used for listening, incorrect sentence translation display, and untracked reveal/skip.
