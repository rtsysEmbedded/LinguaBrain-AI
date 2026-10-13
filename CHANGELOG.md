# Changelog

## 2026-08-22 — Role-specific audio provider models

- Split Audio settings into Speech/TTS, Transcript, and Live Stream model selections with independent persistence and model lists.
- Added Transcript and Live Stream modes to Utilities and connected each mode directly to its corresponding Settings model.
- Repaired legacy installations where a transcription model had been stored in the card-pronunciation TTS field.
- Added localized labels and descriptions in English, German, and Persian.

## 2026-08-22 — Realtime transcription manual-turn compatibility

- Removed automatic turn detection from the dedicated OpenAI transcription session after physical testing reported that detection is unsupported for the selected live transcription mode.
- Kept live transcript deltas active and added an explicit `input_audio_buffer.commit` plus a short final-event drain when recording stops.
- Recorded the OpenAI model-contract evidence and kept the OS 27 `HALC`/`AQMEIO` cleanup logs distinct from the server-side configuration error.
- Recorded macOS acceptance of the corrected cloud path, kept Apple on-device/local transcription incomplete because it still produces no text, and added a separate Utilities visual-redesign task.

All notable changes to this documentation repository are recorded in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Audit — 2026-10-13

- Added the verified [2026-10-13 project audit](docs/PROJECT_AUDIT_2026-10-13.md) with file/line evidence for defects, repository hygiene, hardcoded configuration and text, documentation drift, and incomplete work. `LinguaBrainKit` was built with Swift 6.4.1 on Linux using documented Linux-only shims: 194 tests passed; the Apple app targets were not built.
- Stopped tracking the unreferenced 95.7 MiB third-party `assets/German_Top_4000_vocabulary.apkg` deck and added an ignore rule. Git history was not rewritten.
- Synchronized `PROJECT_STATUS.md` (remote, package existence, Feature 004 progress, revision order), the README module/status text, an ADR-013 implementation note on the OpenRouter-to-generic-provider change, and cross-feature export task notes.
- Moved provider endpoints, model identifiers, voices, request parameters, Realtime transcription profiles, AI prompt templates, and topic scopes into `apps/learner/Resources/Configuration/{provider-catalog,ai-prompts}.json`. A Linux harness verified that every rendered prompt is byte-identical to the previous string interpolation.
- Moved hardcoded Persian, English, and German interface copy (about 400 Swift lines, including per-language `switch` blocks and error descriptions) into `fa/en/de.json` with stable dotted keys; added `formatted(_:_:)`, `minutesLong(_:)`, and `PrototypeLocalization.current(_:_:)`; corrected mistranslated English/German values touched by the migration; removed 279 legacy sentence-shaped keys and 296 duplicate String Catalog entries; added `InfoPlist.xcstrings` for the permission prompts.
- Moved the 50 seed words, 30 multilingual sample cards, default language pair and domain, stored deck names, generic domain names, part-of-speech markers, and topic-classification terms into `Resources/Configuration/{seed-cards,content-rules}.json`. A Linux harness compared the previous and new seed data, sample IDs, and classifier results: byte-identical. SwiftData schema defaults stay literal and are documented as mirrors of the JSON defaults.
- Fixed: the sentence-history "reason" row showed a raw key because the interpolation backslash was missing; the review-rating accessibility label always used Persian; four referenced keys (`domain.newTitle`, `domain.placeholder`, `domain.newMessage`, `common.save`) existed in neither the JSON files nor the String Catalog and were shown as raw keys (four more, `export.format.*` and `provider.audio*`, existed only in the String Catalog and now live in JSON); the legacy provider form chose its status color by searching the Persian text for «موفق».

- Moved the remaining hardcoded settings found after the first pass (audit finding C5) into JSON: three batch/passage card-generation prompts (`ai-prompts.json`); CEFR level lists and defaults, the weak-card threshold, skill-practice session limits, Today's daily-plan coefficients, defaults, and energy bounds, the onboarding level and goal lists, and the Add Word prefilled word, default topic, and export name (`content-rules.json`); the passage normalization confidence threshold (`provider-catalog.json`). Structured-output schemas now read their CEFR values from `levels.cefr`. A Linux harness compiled `AppConfiguration.swift` against the JSON files and compared it with the previous inline code: 24,538 checks, 0 differences. Recorded the learner-profile placeholders (fixed level, goal, and mission values; onboarding without persistence) as incomplete work.
- Feature 004 T033, Phase A1 (package layer only; the app is not wired yet): added card-based writing and listening retrieval ordered by `AdaptivePracticePlanner`, a per-skill capability gate with explicit unavailable reasons, a skill-routed evaluator that never grades with another skill's evaluator, and read-only progress from persisted projections (no evidence is `nil`, not 0 %). Fixed `PracticeSessionService.prepare`, which restored state from every attempt of a unit, so a completed unit reopened as finished and could not be practised again; state is now scoped to the exercise occurrence. 10 new tests; the package suite passes on Linux (204 tests).
- Feature 004 T020: added the versioned grammar-practice contract and deterministic curated grammar exercise factory with explicit rule roles, bounded hints, traceable references, and rejection of ambiguous or multi-issue prompts.

### Planned — 2026-09-04

- Added Feature 004 adaptive-skill-practice specification, implementation plan, 36 dependency-ordered tasks and a Persian developer handoff. Planning covers independent objective scheduling, assistance-aware evidence, writing correction and sentence reuse, grammar explanations, semantic listening and audio-based pronunciation assessment. T001–T012 are now verified; T013 remains an explicit gate.
- Changed Today’s «مرور پیشنهادی» to one simple Anki due-card review action. The four skill exercises remain an explicit, separate «تمرین مهارت‌ها» route and are not mixed into suggested review.
- Changed normal card review itself to the Anki flow: think on the front, reveal the answer, then choose Again/Hard/Good/Easy. Typed-answer checking and automatic grading no longer appear in normal recognition or reverse review.
- Fixed compact Anki review layout: long answers scroll safely and use smaller semantic text, while the target-language example and its translation remain visible beneath the answer.
- Fixed the practice-store migration validation gate so repeated reviews of one card/direction are treated as one review unit with multiple history rows, instead of incorrectly failing activation.
- Restored the existing Anki review writer after migration rehearsal. The card-review UI still uses SwiftData, so blocking that writer before an atomic GRDB review-route migration caused ratings to fail with a storage error.

### Feature 004 cutover — 2026-09-04

- Accepted ADR-017 after product-owner approval and completed T001 traceability for the four-skill learning-core scope without opening later UI or skill stories.
- Completed T005 with the production GRDB 7.11.1 adapter, ordered migrations, relational integrity, atomic transactions, and explicit app dependency injection. File-backed and in-memory repositories remain test fakes.
- Implemented the T006 app-only SwiftData compatibility bridge evidence: deterministic exact-store identification, pre-read backup of the store and present `-wal`/`-shm`/`-journal` sidecars, source-scoped idempotent staging, checkpoint/digest/count/foreign-key/content validation, recoverable states, verified restore, and post-activation blocking of the legacy practice writer. The application review/mastery/FSRS owner is recorded in the T006 completion evidence below; `PracticeSessionService.swift` remains the separate session-intent owner.
- Migration copies only recognition/reverse evidence. Writing, grammar, listening, and speaking are seeded as unknown with no inherited attempts, mastery, or schedules. SwiftData models and retained backups remain untouched; no dual-write or live learner-store migration was performed.
- T002 contract audit added explicit state effects, fixed-clock numeric scoring examples, bounded confidence/score semantics, sentence/revision invariants, and a documented retention/recovery policy. The audit corrected the earlier T006 completion claim; the application boundary it identified is now implemented and evidenced in the 2026-09-05 T006 section.

### Feature 004 Domain — 2026-09-05

- Completed T003 with a portable Domain model for deterministic ReviewUnit identity, immutable Sentence revisions, first-attempt and evaluator evidence, all practice outcomes including partial, assistance/skip events, legal session transitions, and unknown-versus-observed mastery. Added fixed-ID/fixed-date tests; persistence, review-service, mastery, and FSRS behavior remain open under later tasks.

### Feature 004 Review Boundary — 2026-09-05

- Completed T006 with the application-owned `PracticeReviewService`, immutable learning-event evidence, atomic attempt/mastery/FSRS projection commits, idempotent replay, rollback safety, independent four-skill projections, and the pinned `FSRS-6.0/default-21` scheduler adapter. Partial remains partial; reveal/copy, skip, unavailable, cancellation, malformed, and low-confidence results never create independent recall credit.
- Added fixed-clock application tests for outcome/assistance mappings, retry and duplicate delivery, scheduler-at-most-once, transaction failure, GRDB reopen, and legacy recognition/reverse preservation. No live learner store was changed; T007/T008 remain open.

### Feature 004 Ports and Policy — 2026-09-05

- Completed T004 with provider-independent exercise, attempt, help-event, evaluation, media, and review/mastery handoff ports plus the deterministic `practice-evidence-v1` policy. Added validation for partial, skipped, unavailable, low-confidence, malformed, and cancelled results; reveal/copy suppression; fixed-clock outcome/assistance tests. Session orchestration remains open under T007.

### Feature 004 Session Orchestration — 2026-09-05

- Completed T007 with application-only session orchestration for prepare/resume, hint/reveal/copied-answer, skip, submit, retry, continue, and finish. Assistance is durably stored before submit; original responses are saved before evaluator work; all proposals pass through `PracticeReviewService`; unavailable/cancelled results remain ungraded; duplicate and stale deliveries are idempotent; retry is bounded and preserves earlier attempts. Added 13 deterministic session tests, including GRDB restart/resume and transaction-failure evidence. No live learner store was changed; T008 remains open.

### Feature 004 Cross-Layer Verification — 2026-09-06

- Completed T008 with reusable fixed-clock/fixed-ID fakes, scripted evaluator cancellation and late-result release, scripted media, deterministic scheduler/repository failure injection, and four cross-layer fake tests. Existing Domain/Application/Persistence/session tests and the comprehensive app-level `LegacyPracticeMigrationTests.swift` replacement cover assistance-aware evidence, rollback, restart, migration interruption/recovery, legacy recognition/reverse preservation, and unknown new skills. Generation/APKG regression suites remain green; T009 remains open. No live learner data was touched.

### Feature 004 Shared Practice Boundary — 2026-09-06

- Completed T009 with explicit app dependency composition and an `@MainActor @Observable` `PracticeSessionModel` that maps the application session to finite loading, empty, answering, evaluating, feedback, revealed, unavailable, finished, and recoverable-failure states.
- Added intent-only session actions, cancellation and generation-based stale-result suppression, answer/feedback retention across redraw and resume, deterministic app-level model tests, and Today-route compatibility wiring. The existing recognition/reverse review and `SkillPracticeView` remain available until T011 verifies every visible surface; provider/story work remains open. No live learner data was touched.

### Feature 004 Shared Practice Scaffold — 2026-09-06

- Completed T010 with responsive `PracticeScaffold` and `PracticeFeedbackView` components covering all session states, prompt/answer/reveal injection, assistance-aware messaging, original-response preservation, typed feedback and rule references, accessibility semantics, Dynamic Type, narrow-layout actions, and fa/en/de localization.
- Added iPhone 17 Simulator model/scaffold smoke coverage and verified iOS/macOS Debug builds. T011 remains open for rendered-surface accessibility/localization QA; mode-specific screens, AI providers, and the legacy `SkillPracticeView` remain unchanged and available. No live learner data was touched.

### Feature 004 Rendered Surface QA — 2026-09-06

- Completed T011 with answer-language direction independent from Persian/German/English interface direction, localized accessibility labels/values/hints, explicit focus ordering, hidden-answer suppression before reveal, and renderer smoke for all shared states at narrow and iPad-width proposals with Accessibility 5 text size.
- Validated 61 `practice.shared.*` keys in fa/en/de and documented repeatable manual VoiceOver/keyboard QA for iPhone 17 Simulator, iPad, and narrow Mac windows. Runtime VoiceOver, physical-device, and live-store evidence are not claimed. T012 remains the next safe task; no mode-specific story or AI provider was started.

### Feature 004 Writing Evaluation Contract — 2026-09-06

- Completed T012 with the provider-neutral `writing-evaluation-v1` rubric and 13 synthetic fixtures covering correct, partial, incorrect, unavailable, grammatical/vocabulary/meaning/style distinctions, valid inflection/separable forms, uncertainty, malformed output, unsupported language, low confidence, cancellation, and provider failure.
- Added six offline AI-target tests that validate accepted/rejected/normalized fixtures, bounded text/feedback/rules/spans, language and numeric constraints, original-response preservation, no unnecessary corrections, human review for meaning-changing corrections, and the prohibition on canonical/mastery/scheduling mutation. `swift test` passes with 169 tests; iOS Simulator and macOS Debug builds pass. T013 remains open for the validated decoder/provider adapter; no provider call or live learner data was used.

### Changed

- Reworked vocabulary-card generation so the selected category supplies an explicit pedagogical scope (including driving, roads, traffic law, offences, safety, vehicles, and licensing for driving categories). Removed UI-layer relevance/script/headword rejection gates that could discard otherwise decodable provider output, while retaining the structured JSON contract and learner review step.
- Added user-defined learning domains with persistent Settings management, Library filtering, and daily-plan scoping.
- Fixed legacy APKG media import for numeric ZIP media entries, `[sound:...]` references, and HTML image references; imported audio and images are now stored with cards and shown in card details.

### Verification

- T016 offline Anki journey verification is partial: 38 package tests pass without credentials or network, and macOS/iOS Simulator builds pass. iPhone/iPad application tests still expose A1 media-plan and localization-key failures; the simulator runner did not return a final result, and the macOS scheme requires a Test action before app tests can run.
- Completed the T017/T018 Spec Kit consistency review and aligned the active project status, task evidence, backup-versus-sync boundary, and unresolved T016 risks. T019 remains open pending clean app-level verification.
- Added the 2026-08-25 codebase reality audit. It records the actual boundaries of the current prototype: Feature 003 isolation, production persistence, objective-level mastery, and adaptive selection remain the next implementation sequence; signed Apple-account and App Store work stays deferred.

### Added

- Feature 004 T005 persistence slice: exact GRDB.swift 7.11.1 dependency, ordered practice schema migration, `DatabasePool` adapter, relational constraints/indexes, atomic transaction batching, restart/rollback/idempotency/integrity tests, and domain-only repository mapping.
- Feature 004 T006 migration bridge: read-only SwiftData snapshot, explicit recognition/reverse mapping, retained GRDB legacy staging tables, source-scoped idempotency, checkpoint/digest verification, four unknown-skill seeds, app-level iOS interruption/restart/malformed/mismatch/backup/restore tests, and controlled writer activation.
- Feature 004 implementation remains outside this completion for T011 and later: their independent rendered-surface/story acceptance criteria are still open. T001–T010 are verified as the scope, contract audit, Domain model, ports/policy, persistence, migration bridge, review/mastery/FSRS boundary, session orchestration, deterministic cross-layer test gate, shared app presentation boundary, and reusable scaffold/feedback UI.

- Recorded T037 physical model evidence: `gpt-4o-transcribe` produces delayed text while other Realtime transcription candidates remain unverified. Corrected `gpt-live-transcribe` to use `languages` plus `delay: low`, reduced PCM batches to 100 ms, shortened server-VAD silence to 400 ms, kept official live/committed model candidates testable even when `/models` omits their aliases, and separated future bidirectional `gpt-realtime` Voice Agent work into T038.

- Added repository-wide `AGENTS.md`, `CLAUDE.md`, and `GEMINI.md` platform rules and amended the Spec Kit constitution to require installed-SDK and official-documentation verification before OS 27 Apple-framework changes. Pinned the current beta baseline to macOS `26A5416b`, Xcode `27A5228h`, Swift `6.4.0.27.1`, and SDK 27.0.

- Reworked live microphone capture for the iOS/macOS 27 beta: Apple and OpenAI transcription now share `AVCaptureSession`; Core Media buffers are converted from their declared hardware format instead of being parsed as assumed Int16 bytes; OpenAI audio is still normalized to buffered 24 kHz mono Int16 PCM. This avoids the route-specific `AVAudioEngine`/`AUIOBase -50` startup failure and supports converter rebuilds after device-format changes. macOS signed/unsigned builds, the iOS 27 Simulator build, and 38 Swift package tests pass; physical-device streaming remains the T035 completion gate.

- Added `docs/TECHNOLOGY_STACK.md` as the maintained technology inventory, version register, quarterly review process, and release-gate checklist. Linked it from `README.md`.
- Implemented T030: OpenAI-compatible provider adapter with configurable endpoint, protocol (OpenAI-compatible, Google native), model ID, timeout, and health check support. Added `ProviderConfiguration`, `ProviderCapabilities`, `ProviderHealthCheck`, and `CredentialLoader` protocols for interchangeable providers.
- Implemented T031: Provider health checks via `/models` endpoint, consent gates, endpoint-scoped credentials through `SecureCredentialStore`, and usage reporting via `UsageEvent`. Added `TestCredentialLoader`, `NoOpCredentialLoader`, and `FailingCredentialLoader` for testing.
- Implemented T033: Comprehensive tests for no-key errors, timeout configuration, cancellation, retry logic, and Constitution III compliance (no direct mutation of canonical learning state). Added 13 new provider configuration and safety tests.
- Provider settings UI (T032): Text, Audio, and Image provider settings already present in prototype with independent mode selection (built-in, local, cloud, off), endpoint URLs, protocol selection, model ID, API keys, and consent toggles. Fully localized in Persian, English, and German.

- Added a localized Mixed Practice Game entry to Today/review, randomly combining direct translation, reverse translation, article checks, and collocation/context prompts with an independent mixed-review FSRS identity.
- Added Spec Kit task T029 for multi-sense card generation, sense-specific examples/collocations, and independent review identities.
- Multi-sense generation foundation: provider responses can contain up to three senses with separate examples and collocations; the preview shows them and approval creates independent prototype cards with backward-compatible single-sense decoding.
- Mixed Practice Game now offers a verb sense-distractor question when enough related senses exist: three related meanings plus one unrelated meaning, with incorrect selections forced back into the current session.
- Added Spec Kit task T031 for preserving multiple sense-specific examples during Anki import, adaptive review selection, and lossless export/re-import.
- T031 implementation slice: review selects from the persisted example collection, multi-line Anki examples are paired and retained, TSV export includes the complete ordered collection, and regression coverage verifies pairing/export. Independent Sentence persistence remains documented as a later migration decision.
- Audio card-generation slice: generated word cards now automatically request pronunciation from the configured Audio provider, persist MP3 bytes and a deterministic filename on approval, and expose playback during review; provider failure keeps an explicit text-only fallback and preview retry.
- Audio provider routing now honors the Audio submenu independently: Google Native uses the configured Google Cloud Text-to-Speech endpoint and provider-scoped API key, while OpenAI-compatible remains an explicit alternative. Text provider protocol/credentials are no longer reused for speech.
- Added Spec Kit tasks T026/T027 for future-proof generated-card bundles: required pronunciation media when available, collocations/fixed combinations such as `eine Entscheidung treffen`, natural everyday-conversation sentences, and independent mixed-review exercises for those content types.
- Documented collocations and daily-conversation sentences as first-class domain content with provenance, variants, context/register metadata, and independent mastery/review evidence.
- Added Spec Kit task T020 for level-aware A1 Anki generation with optional audio/image assets, local caching, provenance, preview/approval, and offline text-only fallback.
- T020 provider decision: use Google Cloud Text-to-Speech Standard voices for audio across all levels, with explicit free-quota and billing-risk disclosure; image generation remains A1-targeted by default.
- T020 foundation implementation: added a credential-free Google Cloud TTS client boundary, MP3 response validation, deterministic local audio caching, safe filenames, and text-only fallback planning.
- Added Spec Kit task T021 to replace the OpenRouter-specific AI integration with a configurable endpoint/protocol/model boundary supporting local OpenAI-compatible providers such as LM Studio and Ollama.
- Added Spec Kit task T022 for independent Text, Audio, and Image provider menus, including local/cloud/off choices and a premium-gated first-party provider path with entitlement-aware asset provenance.
- T021/T022 foundation implementation: Settings now expose independent Text, Audio, and Image provider modes, configurable endpoint/protocol/model, and a local-provider boundary that does not require an API key.
- Connected Anki card generation to the generic configured OpenAI-compatible endpoint; defaults now use OpenAI `gpt-4o-mini`, while OpenRouter remains selectable through its endpoint URL.
- Added OpenAI-compatible audio (`/audio/speech`, `gpt-4o-mini-tts`) and image (`/images/generations`, `gpt-image-1-mini`) clients using the configured endpoint and Keychain credential; defaults are now Cloud/OpenAI.
- Fixed Anki generation messaging and activation checks so OpenAI, OpenRouter, and local providers use the selected generic Text provider configuration instead of OpenRouter-specific errors.
- Localized the provider menus and connection settings in Persian, English, and German, including modes, protocols, endpoint/model labels, and Premium entitlement guidance.
- Split provider settings into separate Text, Audio, and Image submenus with independently persisted mode/model/voice settings and localized navigation labels.

- Documented a separate feature boundary for modern `collection.anki21b`/schema 18 import and deferred T006–T013 until a dedicated dependency, fixture, and reconciliation plan is created.

- T014/T015 review completion: imported cards now have independent recognition/reverse review identities, all four FSRS ratings are regression-tested, and due/session/persistence behavior is documented against the offline review gate.

- Spec Kit change-control rule requiring newly discovered work—including localization regressions—to be added as a tracked task before implementation and checked only after documented verification.

- T005 fixture contract: an owned 10-case APKG compatibility matrix covering legacy baselines, modern schema-18 variants, malformed metadata, unknown versions, mismatched entries, and hostile decompression/SQLite/media cases, with pinned upstream provenance and XCTest validation.

- T004C/T004D localization resources: 306 catalog strings are available in editable Persian, English, and German JSON files; prototype menu/submenu labels use the centralized JSON resolver with English fallback.

- Thirty stable multilingual learning cards covering all six directed pairs among Persian, German, and English, with pair-scoped library, dashboard, progress, and review queues.
- A pre-T005 multilingual smoke gate with persisted English/German/Persian interface selection, dynamic RTL/LTR shell behavior, source/target settings independent from interface language, explicit imported-card BCP 47 tags, and owned runtime-generated `fa→de`, `en→de`, and `de→en` APKG fixtures.
- Approved T004 import contracts separating Anki source identity from meaning/domain-specific `LexicalSense` identity, preserving learner overrides and FSRS evidence, and defining deterministic inserted/updated/skipped/linked/conflicted/rejected outcomes with `entlassen` polysemy coverage.
- A normalized legacy/schema-18 reader contract with metadata-driven selection, bounded inner decompression, immutable output records, temporary-file ownership, validation order, error categories, versioned resource limits, official Zstandard 1.5.7 decoder source, and Apple SwiftProtobuf 1.38.1.
- A pinned modern Anki package research baseline covering metadata-driven variant selection, the inner Zstandard collection/media layers, schema-18 storage implications, protobuf media integrity, supported/rejected variants, security limits, and reproducible fixture provenance.
- ADR-003 selecting GRDB 7 over system SQLite for production persistence, with `DatabasePool`, explicit ordered migrations and constraints, repository mapping, in-memory test stores, and a one-time verified SwiftData prototype compatibility import.
- An iOS XCTest target and sanitized runtime-generated legacy APKG fixture with regression coverage for LinguaBrain field mapping, deterministic source-based re-import behavior, semantic duplicate rejection, due-time enforcement, and independent German-to-Persian/Persian-to-German review state.
- GitHub Spec Kit infrastructure with a LinguaBrain constitution, agent-neutral workflow guide, Codex/Claude/Gemini integrations, and the first Anki Core feature specification, plan, and task backlog.
- A repository/Xcode audit checkpoint confirming successful iOS and macOS builds, tracked signing/workspace configuration, accurate decision counts, and corrected Release 1.0 account/sync status.
- ADR-014 making optional Sign in with Apple/Google, guest-data merge, account deletion, and scoped learner-data synchronization part of Release 1.0 while preserving local-only use.
- Domain-specific lexical-sense identity, allowing forms such as `entlassen` to have separate work and medical cards with independent recognition and reverse-translation review histories.
- A functional OpenRouter prototype integration with Keychain-only API-key storage, explicit cloud consent, model selection, connection testing, privacy-constrained structured card generation, learner preview, duplicate protection, and commit-on-approval.
- ADR-013 selecting OpenRouter as the first post-Anki-Core cloud AI adapter while retaining Apple Foundation Models as a future capability-gated, no-API-key on-device option.
- A functional Persian-to-German reverse-translation review mode with answer reveal, four FSRS ratings, due/relearning behavior, and memory state isolated from German-to-Persian recognition.
- Imported-Anki package management in Library, including destructive confirmation and transactional removal of the package's cards, dependent review history, and empty deck records without deleting the learner's original APKG file.
- A confirm-and-import APKG flow for legacy SQLite Anki collections (`collection.anki2` and `collection.anki21`) with bounded extraction, read-only SQLite mapping, plain-text sanitization, transactional SwiftData writes, provenance, and duplicate reporting.
- Energy- and available-time-aware daily new-card limits, with the computed limit enforced by the review-session queue.
- A 50-word German–Persian functional-test dataset and shared resettable prototype state across Today, Library, Review, and Progress.
- ADR-012 and the Anki Core MVP specification, establishing secure APKG import and durable offline review as the validation gate before AI card generation and final visual approval.
- MVP card inventory and interactive SwiftUI gallery covering word, noun, verb, recognition, reverse translation, cloze, listening, feedback, daily-plan, and skill-mastery surfaces.
- Buildable native SwiftUI visual prototype for iPhone, iPad, and Mac, covering onboarding, daily check-in, dashboard, library, mock word generation, review, progress, and settings.
- Xcode workspace with separate `LinguaBrain` and `LinguaBrain Mac` schemes plus prototype run instructions.
- Initial Git-ready documentation repository structure.
- Central `PROJECT_STATUS.md` checklist for completed work, remaining work, milestone gates, and maintenance rules.
- Document 15 implementation backlog with stable requirement/work-item identifiers, milestone dependencies, acceptance evidence, test catalog, and requirements traceability matrix.
- Decision Register covering all 53 source open questions plus six supplemental architecture decisions (59 stable IDs), with classifications, statuses, owners, due gates, decision clusters, and the planned ADR queue.
- ADR-001 preserving the now-superseded Dart/Flutter monorepo topology and the still-valid vocabulary-prototype boundary.
- ADR-008 preserving the now-superseded Android-phone pilot and golden-layout decision as historical evidence.
- ADR-009 replacing ADR-008 with a native Swift/SwiftUI client baseline for iOS/iPadOS 27 and macOS 27 Golden Gate.
- ADR-010 replacing ADR-001's Dart/Flutter topology with an Xcode and Swift Package Manager module layout.
- ADR-011 defining native Observation state, typed scene-owned navigation, initializer injection, and the SwiftUI application composition root.
- Experiment governance for non-production research spikes.
- Product Vision specification.
- Complete product and technical specifications for documents 02 through 14.
- Domain contracts for LexicalSense, ReviewUnit, revisions, proposals, learning plans, and pipeline jobs.

### Changed

- Removed the remaining executable OpenRouter-specific card-generation boundary: text-card creation now routes through the configured provider endpoint/protocol/model, omits OpenRouter-only request fields, supports keyless local mode, and uses localized provider-neutral labels/errors. JSON catalogs and Spec Kit evidence were updated; macOS Debug build passed.
- Added the missing Cloud data-consent toggle and explanation to Settings → Text provider, localized in Persian, English, and German.
- Added an exact saved-key/endpoint connection test beside Text provider settings, hardened Keychain upsert/read trimming, and localized the card-generation screen with source/target-language-aware generation prompts.
- Added provenance-aware Anki TSV export: internally generated and imported cards are separated and exported through distinct localized actions.
- Added a per-card selection sheet before TSV export, with select/deselect controls and localized actions.
- Recorded the native APKG exporter as T024 with an explicit boundary: valid SQLite collection, ZIP packaging, templates/tags, media ownership, and round-trip fixtures are required before APKG export is exposed.
- Added a unified `AIProviderGateway` for text, speech, and image generation and routed Anki card creation through it.
- Fixed the provider 401 root cause: Text settings and card generation now read the same provider-scoped Keychain account (`api-key.text`), while the old generic account is used only as a migration fallback.
- Added safe DEBUG provider diagnostics showing Keychain account, endpoint, model, key length, and hashed fingerprint without exposing the API key.
- Added runtime migration for the persisted legacy OpenRouter endpoint and a warning when an unusually large value is pasted as an API key.
- Normalized empty persisted provider protocols and aligned the saved-key indicator with the exact lookup used during card generation.
- Synchronized Text provider credentials across scoped and legacy Keychain accounts for compatibility with previously installed builds.
- Isolated provider credential state and deletion for Text, Audio, and Image Keychain accounts.
- Made AI card generation language-direction aware: response fields, examples, preview layout, stored pair metadata, and pronunciation input now follow the selected source and target languages instead of fixed German/Persian semantics.
- Added pronunciation generation/playback to card preview and independent audio endpoint/model/provider-key settings.

- Persist language-pair metadata on every prototype card, include the pair in semantic duplicate identity, correct generic APKG source/target mapping, swap conflicting language selections safely, and render card sides with their own RTL/LTR direction.
- Repaired the incomplete interface-language switch by adding an Apple String Catalog for 265 prototype-screen strings, resolving variable component copy through the selected in-app locale, localizing dynamic minute/review summaries, shortening German tab labels, and visually smoke-testing English/German/Persian LTR/RTL renders.
- Corrected APKG field mapping by reading Anki model field names instead of assuming positional German/Persian fields; `anki_single` payloads now restore level, part of speech, meanings, example, and Persian example translation, and deterministic re-import updates previously incomplete records.
- Added the first APKG import boundary: native file selection and a read-only ZIP central-directory preflight that rejects traversal paths, symlinks, encrypted/unsupported entries, duplicates, excessive expansion, suspicious ratios, ZIP64, and packages without an Anki collection database.
- Persisted the prototype deck and its 50 cards in SwiftData, seeding them only when the local card store is empty and restoring stable card identities on launch.
- Replaced fixed prototype button intervals with deterministic FSRS-6 scheduling using persisted stability, difficulty, phase, elapsed time, algorithm version, and official reference vectors.
- Persisted prototype review history and due dates with SwiftData so ratings, progress, and the review queue survive app restarts; review success is now shown only after the transaction is saved.
- Added prototype due dates and a time-aware review queue: Again and Hard cards return only when their displayed interval becomes due, while the session waits and resumes automatically when no other card is available.
- Review ratings now update word strength, reviewed/weak/due counts, and progress summaries across the running prototype; Progress includes an explicit reset action.
- Made the visual prototype review session interactive: answer reveal now enables rating actions, each rating advances the queue, and session completion shows a rating summary with restart support.
- Redesigned the SwiftUI settings experience as a clear Apple-style control center with a profile summary, learning-path overview, grouped navigation, and focused detail screens.
- Hardened `.gitignore` for excluded local projects, environment secrets, Python artifacts, local databases, generated output, and runtime files.
- Reviewed all specifications for cross-document consistency and implementation readiness.
- Clarified that media and exercises are resources/activities rather than KnowledgeItems.
- Resolved FSRS scheduling at the learner/objective ReviewUnit level.
- Defined authoritative validation versus learner-accepted private content.
- Aligned MVP scope, no-AI fallback, daily check-in defaults, privacy, and pilot metrics.
- Added minimal ClientSurface, CapabilitySnapshot, and consent-gated audio-pipeline extension points for future dedicated hardware while keeping hardware outside the app MVP.
- Aligned architecture-decision timing: M1-blocking ADRs remain M0 gates, while FSRS and ReviewUnit evidence-mapping ADRs are hard-gated before M3.
- Marked `LB-DEC-054` as `DECIDED` and `LB-WI-M0-03` as `DONE`; aligned DOC-11, DOC-15, the project checklist, and repository indexes with ADR-001.
- Relocated the untracked `vocabulary-mvp/` prototype to `experiments/vocabulary-mvp/` and marked it reference-only.
- Excluded experiment-local spreadsheet inputs and generated CSV exports from Git.
- Hardened the reference experiment by binding n8n to loopback, disabling persisted execution payloads, documenting Telegram-token exposure risks, and defining a safe one-way import/retirement contract.
- Marked `LB-DEC-037` and `LB-DEC-053` as `DECIDED`, made `LB-WI-M0-04` ready for ADR-002, and aligned Documents 10, 14, and 15 with the Android-first platform decision.
- Superseded the Android/Flutter platform choice and Dart package topology while preserving ADR-001 and ADR-008 as historical records.
- Reframed the MVP as native Swift 6.4 and SwiftUI on iOS/iPadOS 27 and macOS 27, with iPhone as the primary pilot and local-only iPad/Mac surfaces.
- Added capability-gated Foundation Models, SpeechAnalyzer, Translation, Keychain, Swift concurrency, VoiceOver, Dynamic Type, and Apple release/toolchain boundaries to the active specifications.
- Replaced Flutter work items and decision gates with SwiftUI state/composition and native Swift persistence decisions; Xcode 27 beta work remains provisional until stable OS/toolchain verification.
- Replaced Flutter/Dart generated-file ignores with SwiftPM/Xcode/DerivedData/archive ignores while keeping source projects and resolved dependencies trackable.
- Recorded the local Apple-toolchain audit: macOS 27 on Apple silicon and Swift 6.4 are available, but full Xcode 27 is not yet the active developer directory.
- Activated and verified Xcode 27.0 build `27A5228h` with Swift 6.4 and version 27 iPhoneOS, iPhone Simulator, and macOS SDKs.
- Closed LB-DEC-058 and advanced the active architecture queue to ADR-003 for the native Swift persistence stack.
- Added opt-in private CloudKit card backup and reinstall recovery for learner-generated and Anki-imported cards, with sample exclusion, merge/deduplication, Privacy & Data status UI, shared Apple-platform entitlements, and local regression coverage.
- Added a top-level Utilities area with live on-device speech-to-text, partial transcript rendering, provider selection, microphone/Speech permission handling, and an explicit OpenAI Cloud follow-up boundary.
- Added copy buttons for transcript and translation output plus AI translation to Persian, German, and English using the configured text provider.
- Documented the Personal Development Team limitation: CloudKit entitlements are preserved but detached from current targets so device builds continue to work until a paid Apple Developer Team provisions the container.
- Feature 004: completed verified T013/T014 writing evaluation decoder/provider and application service with provenance validation, bounded feedback, failure-safe ungraded results, and save-before-evaluate response preservation. T015+ remain open pending sentence-library wiring and story QA.
- Feature 004: completed T016/T017 with scoped sentence-learning acceptance, immutable revisions, deterministic adaptive planning, capability/repetition filtering, and fixed-seed tests.
- Feature 004: completed T018 with the localized, injected sentence-learning history surface and explicit unknown-mastery presentation.
- Feature 004: completed T019 with synthetic package and iPhone 17 Simulator coverage for writing acceptance, restart/reuse, decline, revision replay, capability gating, and independent skill selection.

### 2026-09-07 — Feature 004 ownership boundary audit

- Added the provider-independent `PracticeDataOwnershipService` contract for
  learner-owned practice export, explicit private-data deletion, and consent
  gating.
- Added deterministic synthetic tests; no live learner data was accessed.
- Kept T033–T036 open because production ownership integration and final
  cross-device QA remain outstanding.
### 2026-09-08 — Feature 004 writing and pronunciation gates

- Verified and closed T015 with three iPhone 17 Simulator writing-surface tests.
- Closed T028 as a documented negative capability result; pronunciation scoring remains disabled and T030–T032 remain open.
### 2026-09-08 — Feature 004 grammar and listening

- Completed T021–T026 and T023 with canonical grammar evaluation, grammar UI tests, exact-revision listening context, localized replay controls, and an Apple system sentence-playback adapter.
- Added a temporary-by-default Apple recorder implementation and focused configuration tests; T029 remains open pending permission/interruption/device evidence.
- Verified the same audio changes with a successful macOS Debug build, localization JSON/key parity, and a clean diff check. Kept T027/T029 and dependent integration/final-delivery tasks open where real-audio, physical-device, or approved-provider evidence is still absent.
