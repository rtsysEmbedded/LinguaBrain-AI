# Changelog

All notable changes to this documentation repository are recorded in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

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
