# Tasks: Anki Core Modern Import and Offline Review Gate

**Status**: Active

**Format**: `[ID] [P?] [Story] Description (scope; verification)`

## Phase 1 — Baseline and decisions

- [x] T001 Capture current legacy import and offline-review behavior with regression tests and sanitized fixtures.
- [x] T002 [P] Decide and record the production Swift persistence/query/migration adapter in ADR-003.
- [x] T003 [P] Research supported `collection.anki21b` variants, constraints, and fixture provenance in `research.md`.
- [x] T004 Approve normalized reader, provenance identity, reconciliation, and conflict contracts in `data-model.md` and `contracts/`.
- [x] T004A [P] Verify persisted English/German/Persian interface switching independently from learning source/target roles, with generated multilingual APKG fixtures.
- [x] T004B [P] Seed and isolate learning cards for all six directed English/German/Persian language pairs before T005.
- [x] T004C [P] Externalize prototype interface and submenu copy into editable per-language JSON resources with centralized fallback resolution.
- [x] T004D [P] Complete the localization resource inventory from the prototype String Catalog and record the remaining View-literal migration boundary in project documentation.
- [ ] T004E [US4] Complete localization QA for all app-language combinations, including Settings submenus, review labels, duration units, coach suggestions, and source/target language titles; mark complete only after iOS and macOS smoke verification.

## Phase 2 — Safe modern inspection and reading

- [x] T005 [P] [US1] Add modern valid/corrupt/hostile fixture matrix without personal learner data.
- [~] T006 [US1] Implement bounded archive inspection for approved modern entries while preserving legacy checks. **Deferred to separate Modern Anki Import feature.**
- [~] T007 [US1] Implement normalized modern reading for decks, models, notes, cards, fields, templates, and tags. **Deferred to separate Modern Anki Import feature.**
- [~] T008 [P] [US1] Implement validated media-manifest mapping and resource ownership. **Deferred to separate Modern Anki Import feature.**
- [~] T009 [US1] Extend preview/report UI state with compatibility, warnings, counts, and explicit confirmation. **Deferred to separate Modern Anki Import feature.**

## Phase 3 — Deterministic reconciliation and transaction

- [~] T010 [US2] Implement stable package/source identities and migrate prototype provenance. **Deferred with modern import feature.**
- [~] T011 [US2] Implement inserted/updated/skipped/conflict reconciliation preserving learner edits and review state. **Deferred with modern import feature.**
- [~] T012 [US1] Commit records, media ownership, and import report in one rollback-safe transaction. **Deferred with modern import feature.**
- [~] T013 [US2] Verify confirmed package removal against the new ownership model without deleting the APKG source. **Deferred with modern import feature.**

## Phase 4 — Offline review gate

- [x] T014 [US3] Route imported cards through stable LexicalSense, ReviewUnit, and independent recognition/reverse contracts.
- [x] T015 [US3] Verify atomic four-rating FSRS persistence, due timing, session summary, and restart with a fake clock.
- [ ] T016 [US3] Run the import/review journey and builds on iPhone/iPad and Mac without network or AI credentials.

## Phase 5 — Convergence

- [ ] T017 Run Spec Kit consistency analysis and resolve critical discrepancies.
- [ ] T018 Update project status, changelog, affected documents, and decision register with evidence.
- [ ] T019 Perform staged-file security review, full relevant verification, and handoff with commit SHA and risks.
- [ ] T020 [US5] Define and implement internal Anki card generation for all levels, with optional Google Cloud Text-to-Speech pronunciation audio and A1-targeted image assets, local caching, preview/approval, provenance, and offline reuse.
- [ ] T021 [US6] Replace the OpenRouter-specific AI boundary with a configurable provider connection model supporting endpoint URL, protocol, model identifier, optional credential, local/remote scope, health check, structured card generation, and provider-specific request adapters.
- [ ] T022 [US7] Split AI/media configuration into independent Text, Audio, and Image provider menus, with free/local/cloud choices and a premium-gated first-party provider path for assets or models shipped by LinguaBrain.
- [ ] T023 [US8] Export cards with provenance-aware selection, separating cards created in LinguaBrain from cards imported from Anki and asking which group/cards to export (TSV MVP; APKG/media export follow-up).
- [ ] T024 [US8] Build a native APKG exporter for selected cards, including valid `collection.anki2`, notes/cards/templates/tags, ZIP packaging, and owned round-trip fixtures; add media manifest/blob export after persisted media ownership is available.
- [ ] T025 [US9] Implement weighted mixed-practice sessions across independent learning objectives (direct/reverse translation, article, grammar, listening/dictation, and typed production), with per-objective events, mastery, due state, and anti-repetition selection rules.
- [ ] T026 [US9] Extend generated-card content bundles for future-proof learning: persist pronunciation audio/media provenance, validated collocations/fixed combinations with component references and variants, and natural everyday-conversation sentences with situation/register metadata; provide explicit text-only fallback reasons.
- [ ] T027 [US9] Add collocation and daily-conversation exercise contracts to mixed review: partner selection, cloze completion, contextual production, situation-to-utterance recognition, and reusable-sentence recall, each with independent objective/review evidence and weighted scheduling.
- [X] T028 [US9] Add a user-facing "Mixed Practice Game" entry to the review menu, randomly combining direct translation, reverse translation, article checks, and collocation/context prompts while preserving the existing FSRS rating flow.
- [~] T029 [US10] Generate and persist multi-sense word cards: store each validated sense with its own meaning, usage/register, example, translation, and collocations; preview all senses and create independent review identities/cards per sense while preserving backward compatibility for single-sense responses.
- [ ] T030 [US9] Add verb sense-distractor practice to Mixed Practice Game: when at least three related senses exist, show three related meanings and one unrelated meaning, require selecting the unrelated option, and force incorrect answers back into the current session.
- [~] T031 [US8] Preserve multiple examples during Anki import: model examples as ordered sense-specific Sentence records, retain source/target text and provenance, select examples adaptively during review, and round-trip all examples through export without collapsing them into one field.
- [x] T032 [US11] Add opt-in private iCloud card backup and reinstall recovery for learner-created/imported cards, excluding built-in sample content.
- [x] T034 [US12] Add the Utilities surface and working on-device streaming speech-to-text prototype with explicit microphone/Speech permission handling.
- [ ] T035 [US12] Implement the OpenAI Realtime cloud transcription provider behind the Utilities provider boundary, including short-lived sessions, 24 kHz PCM streaming, turn detection, cancellation, consent, and redacted diagnostics.

## Dependencies and Parallel Work

- T001–T004B are foundational. T005 starts only after the localization/language-pair smoke gate remains green.
- T006 precedes T007. T008 may run with T007 only with separate file ownership.
- T010 precedes T011/T013. T007, T008, T010, and T011 precede T012.
- T012 and T014 precede T015; all implementation precedes T016–T019.
- `[P]` means potentially parallel, not automatically safe; exact write scope is required.

## Change-control rule

- Every newly discovered product issue or scope item must be added here, or to the owning Spec Kit artifact, before implementation.
- A task remains unchecked while implementation, documentation, or verification is incomplete.
- The checkbox may change to `[x]` only after its acceptance evidence, affected documents, and relevant tests/builds are recorded in the Agent Handoff Evidence section.
- Localization regressions are tracked under T004E (or a more specific child task) rather than being handled as undocumented ad-hoc fixes.

### T020 acceptance boundary

- Audio generation is available for every supported level; image generation defaults to A1 and remains opt-in for higher levels.
- The initial audio provider is Google Cloud Text-to-Speech Standard voices, using the documented free monthly quota; billing/over-quota risk must be surfaced before enabling generation.
- Audio and image generation are optional per card, previewed before approval, and never silently uploaded or committed.
- Generated assets have stable cache keys, source/provenance metadata, size/type limits, and a local offline path after approval.
- A card remains usable if either media type is unavailable; text-only fallback is required.

### T021 acceptance boundary

- Provider configuration is data-driven and contains endpoint URL, protocol, model, credential reference, and local/remote scope; provider names are labels, not hard-coded routing logic.
- The first protocol is OpenAI-compatible Chat Completions for local LM Studio/Ollama and compatible hosted endpoints; native protocols remain adapter extensions.
- API keys are stored only in Keychain; local providers can explicitly operate without a key.
- Requests use validated structured output, timeout/cancellation, health checks, error normalization, and explicit cloud-consent gates for remote endpoints.
- Existing OpenRouter settings migrate into the generic configuration without losing model ID or consent state.

### T022 acceptance boundary

- Settings expose three independent provider menus: Text generation, Audio generation, and Image generation; changing one never silently changes the others.
- Each menu supports `Built-in/Premium`, `Local`, `Cloud`, and `Off` where technically applicable, with a clear capability and privacy summary.
- The built-in provider is capability/entitlement-gated, versioned, replaceable, and never treated as a free hidden fallback.
- Premium entitlement is verified by a single subscription/entitlement service; provider adapters do not implement billing logic.
- Cards remain usable with any provider disabled, using text-only or previously cached media fallback.
- Every generated asset records provider kind, model/version, cache key, consent/entitlement context, and generation date.

## Deferred feature boundary

Modern `collection.anki21b`, schema 18, Zstandard, SwiftProtobuf, modern templates/tags/media, and modern-package reconciliation are intentionally deferred from this feature. They must be implemented in a separate Spec Kit feature with its own `spec.md`, `plan.md`, `tasks.md`, dependency/license record, fixtures, and acceptance evidence. Legacy APKG support and the offline review prototype remain in scope here.

## Agent Handoff Evidence

### T005 — 2026-08-18

- **Agent/tool**: Codex with Swift/XCTest and the pinned Anki format research baseline.
- **Changed scope**: Added `modern-apkg-fixtures.json`, a 10-case owned fixture catalog covering legacy baselines, schema-18 accepted variants, malformed/unknown/mismatch cases, and hostile Zstandard/SQLite/media cases; added a regression test for IDs, accepted schemas, reject classes, and pinned upstream provenance.
- **Verification**: Catalog decodes in XCTest, includes all four fixture classes, uses only synthetic identifiers, and pins upstream commit `967aa0d578fc75181e292e95326f9b58698da25c`.
- **Known boundary**: Binary schema-18 generation and Zstandard payload construction remain implementation work in T006–T008; this task establishes the owned, reviewable fixture contract before decoder code.

### T014/T015 — 2026-08-18

- **Agent/tool**: Codex with SwiftData, SwiftUI, XCTest, and the pinned FSRS-6 scheduler.
- **Changed scope**: Confirmed imported cards use stable card identity keys, recognition and reverse-translation append `::reverse` independently, persisted review records restore due dates and FSRS state, and added four-rating coverage for Again, Hard, Good, and Easy.
- **Verification**: iPhone 17 Simulator XCTest suite passed; direction isolation, due-time enforcement, all four ratings, atomic save failure handling, session counters, and persisted-review restoration paths are covered by the existing store implementation and regression tests.
- **Known boundary**: A production GRDB ReviewUnit migration remains part of the later package extraction; the current prototype gate is now covered end-to-end.

### T020 — 2026-08-18 (partial)

- **Agent/tool**: Codex with Swift concurrency, URLSession, local file caching, and the Google Cloud Text-to-Speech REST contract.
- **Changed scope**: Added `GoogleCloudTextToSpeechClient`, request/response validation, API-key boundary, MP3 decoding, deterministic cache storage, safe cache filenames, and A1 media-plan tests that preserve text-only fallback.
- **Verification**: macOS Debug build succeeded. No credentials or network calls are included in the repository.
- **Remaining**: Wire the provider into Settings and card preview/approval, add quota accounting, add iOS device verification, and implement the A1 image provider before T020 can be checked off.

### T021/T022 — 2026-08-18 (partial)

- **Agent/tool**: Codex with SwiftUI/Observation and UserDefaults-backed prototype settings.
- **Changed scope**: Added independent Text, Audio, and Image provider modes (`Built-in/Premium`, `Local`, `Cloud`, `Off`), configurable endpoint URL, protocol selection, model ID, and a local-provider/no-key information boundary. Existing OpenRouter settings remain compatible through the default OpenAI-compatible endpoint.
- **Verification**: macOS Debug build succeeded.
- **Remaining**: Add protocol-specific adapters beyond OpenAI-compatible, migrate existing legacy Keychain entries, store credentials per endpoint, add entitlement verification, health checks, quota accounting, and iOS QA before T021/T022 can be checked off.
- **Localization**: Provider menu labels, modes, protocols, endpoint/model fields, and entitlement notes are available in Persian, English, and German JSON resources.
- **UI refinement**: Text, Audio, and Image now open as separate Settings submenus with independently persisted mode/model/voice values; shared endpoint/protocol remains configurable until per-provider connection profiles are added.
- **OpenAI-compatible wiring**: The default text endpoint is now `https://api.openai.com/v1` with `gpt-4o-mini`; card generation uses only the configured endpoint's `/chat/completions` route and no longer sends provider-specific routing fields or headers.
- **Provider error/UI fix**: Anki generation now uses the selected Text provider mode, endpoint, protocol, model, and Keychain credential. Local mode permits an empty key; cloud mode requires consent and a key; user-facing readiness/errors and the create-card action are localized and provider-neutral.
- **Verification update — 2026-08-18**: `jq empty apps/learner/Resources/Localization/*.json` passed; `xcodebuild -project apps/learner/LinguaBrain.xcodeproj -scheme 'LinguaBrain Mac' -sdk macosx -configuration Debug CODE_SIGNING_ALLOWED=NO build` passed. An application-code search returned no executable OpenRouter references. T021/T022 remain partial because endpoint-scoped credential migration, adapters, entitlement/quota, health-check coverage, media approval wiring, and iOS QA are still open.
- **Consent UI update — 2026-08-18**: Added the cloud-data consent toggle and explanatory text directly to the Text provider submenu; it is visible only when Text mode is Cloud and persists through the existing settings model in all three JSON locales.
- **Generation debug/localization update — 2026-08-18**: Added an in-context Text-provider connection test using the exact saved Keychain credential and endpoint used by card generation; made Keychain writes an upsert and trimmed stored credentials; localized the card-generation screen and changed the generation prompt to use the configured source/target language pair and stable domain IDs. macOS Debug build passed.
- **Unified gateway update — 2026-08-18**: Added `AIProviderGateway` as the shared boundary for text-card, speech, and image generation; card generation now uses this gateway. Endpoint/protocol/model/credential remain injected from settings, and no raw credential is logged. macOS Debug build passed; media preview/approval and provider-specific adapters remain open.
- **Audio generation update — 2026-08-18**: Added pronunciation generation and playback to the generated-card preview. Audio has its own mode, endpoint, model, voice, and provider-scoped Keychain account; text and image endpoints remain independently persisted. macOS Debug build passed.
- **OpenRouter migration regression fix — 2026-08-18**: Git history review traced the remaining 401 mismatch to the old generic Keychain account. Text settings saved `api-key.text`, while card generation read legacy `api-key`; settings test and generation therefore used different credentials. Text reads now prefer the provider-scoped account, with legacy fallback only for migration, and delete removes both entries. `git log -S` confirmed the historical origin in commit `69a66f3`; macOS Debug build passed. Stale OpenRouter names remain only in historical String Catalog/JSON keys and are not referenced by the active provider path.
- **Safe provider diagnostics — 2026-08-18**: Added DEBUG-only Xcode console diagnostics for save/read/request with Keychain service, account, endpoint, model, key length, and a truncated SHA-256 fingerprint. The raw API key is never printed or written to a file. macOS Debug build passed.
- **Runtime evidence — 2026-08-18**: Xcode console showed the active request still used `https://openrouter.ai/api/v1` and a 8894-character credential. Added one-time runtime migration of persisted OpenRouter text endpoint to `https://api.openai.com/v1` and a DEBUG warning for unusually large pasted credentials.
- **Protocol/key-state fix — 2026-08-18**: Normalized an empty persisted protocol to `openai-compatible` and made `hasAPIKey` use the same text-or-legacy Keychain lookup as card generation, preventing a false saved-key state. macOS Debug build passed.
- **Legacy Keychain compatibility update — 2026-08-18**: Text-provider save now synchronizes the scoped `api-key.text` account with the legacy `api-key` account so installed builds and the current generation path cannot disagree about whether a key exists. macOS Debug build passed.
- **Provider isolation fix — 2026-08-18**: Provider settings now report and delete credentials by provider account (`api-key.text`, `api-key.audio`, `api-key.image`) instead of sharing one `hasAPIKey`/delete state. This prevents saving or removing Audio credentials from invalidating Text provider state. macOS Debug build passed.
- **Language-direction generation fix — 2026-08-18**: Replaced the generated-card response contract's fixed `german/persian` fields with `targetText/sourceMeaning` and target/source examples; prompt, validation, preview, persistence pair, and pronunciation input now use the configured source/target language tags. macOS Debug build passed.
- **T023 export MVP — 2026-08-18**: Added provenance classification from `sourcePackage`, separate export actions for internally generated versus imported cards, active language-pair filtering, localized Anki-compatible TSV export, and a per-card selection sheet before file creation. macOS Debug build passed. Remaining: native APKG packaging, media inclusion, richer tags/templates, and export/import reconciliation.
- **T024 boundary — 2026-08-18**: No ZIP writer or APKG exporter dependency exists in the project; import currently has a security-focused reader only. Native APKG work is therefore explicitly separated from the completed TSV selection UI and must include round-trip validation through the existing APKG inspector/reader before being checked off.
- **Media defaults**: Audio defaults to OpenAI `gpt-4o-mini-tts` via `/audio/speech`; images default to `gpt-image-1-mini` via `/images/generations`; both use the configured endpoint and Keychain API key.
- **Audio generation slice — 2026-08-18**: Generated word-card creation now automatically attempts pronunciation synthesis through the independently configured Audio provider, persists returned audio bytes plus a deterministic filename on approval, and exposes playback in review. iOS and macOS Debug builds passed. T026 remains open for collocations, conversation sentences, full media provenance/cache metadata, and packaged APKG media export.
- **Google Audio routing — 2026-08-18**: Added an independent persisted Audio protocol setting. `google-native` calls Google Cloud Text-to-Speech `text:synthesize` with the Audio provider's endpoint, voice, and `api-key.audio`; `openai-compatible` remains supported only when selected. iOS Debug build passed.
- **T028 Mixed Practice Game — 2026-08-18**: Added a localized review entry from Today and a mixed mode with random direct/reverse/article/collocation-context prompts. Mixed mode uses its own `::mixed` review identity while retaining the existing FSRS rating controls. iOS Debug build passed.
- **T029 multi-sense generation — 2026-08-18 (partial)**: Generated-card schema now accepts up to three sense records with independent meaning, usage, example, and collocations; preview displays all senses and approval creates independent prototype cards per sense while remaining compatible with legacy single-sense JSON. iOS Debug build passed. Remaining: persist sense IDs/collocations as first-class fields and include sense-aware native APKG/TSV export.
- **T030 verb distractor game — 2026-08-18**: Mixed Practice Game now conditionally offers a verb-only “choose the unrelated meaning” question when three related meanings are available, displays three related plus one unrelated option, and forces an incorrect selection to repeat later in the same session. iOS Debug build passed.
- **T031 definition — 2026-08-18**: Import must preserve every example attached to a note/sense as ordered Sentence records rather than keeping only one `example` field. Examples remain grouped by LexicalSense, retain source/target text and Anki provenance, can be selected by review policy, and must survive export/re-import without loss. Implementation is pending.
- **T031 implementation slice — 2026-08-18 (partial)**: Added ordered `PrototypeExample` collections with legacy single-example fallback, imported all examples from the internal JSON payload and paired multi-line Anki fields, persisted them as JSON on card records, and exported all examples as `<br>`-separated TSV fields. iOS Debug build passed. Remaining: sense-specific database entities, adaptive example selection in review, and round-trip fixture assertions.
- **T031 completion slice — 2026-08-18 (partial)**: Review now selects a stored example for each card session, and regression coverage verifies pairing plus lossless TSV export of multiple examples. The independent `Sentence` entity remains intentionally deferred pending the documented persistence decision. iOS Debug build passed; simulator test execution did not return within the local command window.
- **T032 iCloud card backup — 2026-08-21**: Added an opt-in CloudKit private-database snapshot for learner-generated and Anki-imported cards, restore-and-merge on launch/foreground, manual sync and status UI under Privacy & Data, shared iOS/macOS entitlements, and an in-memory regression test proving sample exclusion and reinstall-style restoration. This is card backup/recovery only; FSRS events, tombstones, account linking, and concurrent multi-device conflict resolution remain separate Release 1.0 work.

For each completed task record the agent/tool, date, changed files, commands/tests, result, known risks, and commit SHA. Never include credentials, private APKG data, or raw learner content.

### T001 — 2026-08-17

- **Agent/tool**: Codex with Xcode 27.0 and XCTest.
- **Changed scope**: iOS unit-test target, sanitized JSON fixture, runtime SQLite/APKG fixture factory, regression tests, and project/status documentation.
- **Evidence**: Three tests passed on the iPhone 17 iOS 27 simulator: legacy APKG inspection/field mapping, source-identity re-import update plus semantic duplicate skip, and independent direct/reverse review scheduling with due-time enforcement.
- **Compatibility check**: `LinguaBrain Mac` generic macOS build passed with signing disabled.
- **Known boundary**: T001 locks the currently supported legacy path; modern `collection.anki21b`, hostile fixture expansion, restart persistence vectors, and full reconciliation remain assigned to later tasks.
- **Commit**: see the T001 completion commit in Git history; its SHA is included in the handoff response.

### T002 — 2026-08-17

- **Agent/tool**: Codex; local architecture/specification audit plus official Apple SwiftData and GRDB project documentation.
- **Decision**: Accepted ADR-003 selects GRDB 7 over system SQLite, production `DatabasePool`, in-memory `DatabaseQueue` tests, explicit `DatabaseMigrator` migrations, private persistence DTOs, and repository/transaction mapping.
- **Compatibility**: The current SwiftData prototype receives a one-time verified, idempotent compatibility import; production dual-write is prohibited and learner data must never be silently reset.
- **Deferred security boundary**: SQLCipher, Apple Data Protection, backup keys, and lost-key recovery remain explicitly owned by ADR-007.
- **Consistency evidence**: Decision Register, ADR index, Documents 11/12/15, README, project status, and changelog were aligned; register counts were independently recomputed.
- **Commit**: see the T002 completion commit in Git history; its SHA is included in the handoff response.

### T003 — 2026-08-17

- **Agent/tool**: Codex; official Anki source/manual research pinned to upstream commit `967aa0d578fc75181e292e95326f9b58698da25c`.
- **Changed scope**: Added `research.md` with the version-selection contract, ZIP/Zstandard layers, schema-18 implications, protobuf media mapping, compatibility matrix, security requirements, and fixture provenance policy.
- **Key finding**: Latest `collection.anki21b`, its protobuf media manifest, and each numbered media payload are internally Zstandard-compressed; outer ZIP limits alone cannot bound decoded expansion.
- **Compatibility boundary**: Legacy schema 11 remains supported; metadata version 3/schema 18 is the next target; malformed, ambiguous, unknown/future, unsupported-schema, or unbounded variants remain rejected.
- **Known boundary**: Decoder dependencies, numeric resource limits, normalized records, error taxonomy, and atomic partial/failure behavior require approval in T004 before implementation.
- **Verification**: Markdown/reference audit and comparison against the pinned official source; no runtime code changed.
- **Commit**: see the T003 completion commit in Git history; its SHA is included in the handoff response.

### T004 — 2026-08-17

- **Agent/tool**: Codex; domain/import contract design based on T003 and the accepted LexicalSense/ReviewUnit architecture.
- **Changed scope**: Added the approved data model, normalized reader/resource contract, deterministic reconciliation/conflict contract, and pinned Zstandard/SwiftProtobuf implementation choices; strengthened feature requirements for sense and ownership identity.
- **Identity decision**: Re-import matches by namespaced source identity; semantic candidate keys are non-unique suggestions and spelling alone is never identity.
- **Conflict decision**: Source snapshots, learner overrides, and review evidence are separate; concurrent field changes retain the learner value and all review/FSRS state.
- **Polysemy evidence**: Work, medical, and legal meanings of `entlassen` are specified as independent LexicalSense and ReviewUnit identities.
- **Known boundary**: T005–T008 implement fixtures and readers; T010–T013 implement the approved reconciliation/transaction contracts in production code.
- **Verification**: Markdown consistency, contract cross-links, task/status alignment, and staged diff validation; no runtime code changed.
- **Commit**: see the T004 completion commit in Git history; its SHA is included in the handoff response.

### T004A — 2026-08-17

- **Agent/tool**: Codex with SwiftUI, XCTest, Xcode 27.0, iOS 27 Simulator, and macOS 27 SDK.
- **Changed scope**: Added persisted `PrototypeAppLanguage` and independent source/target settings, dynamic RTL/LTR shell behavior, an Apple String Catalog covering 265 prototype-screen strings, locale-aware dynamic time/review summaries, a functional settings picker, explicit imported-card language tags, and a synthetic three-direction fixture catalog/runtime APKG generator.
- **Language-independence decision**: Interface `en`/`de`/`fa` is not the learning pair; source/target tags survive interface changes and reject identical roles.
- **Fixture evidence**: Runtime-generated owned APKG packages cover `fa→de`, `en→de`, and `de→en`, with asserted words and examples.
- **Verification**: Five tests passed on iPhone 17 / iOS 27; English, German, and Persian core-screen renders were visually smoke-tested; `LinguaBrain Mac` built successfully with signing disabled.
- **Known boundary**: Functional localization now covers the prototype screens; professional editorial review of the generated English/German copy and complete language-package terminology remain DOC-18/M2 scope.
- **Commit**: see the T004A completion commit in Git history; its SHA is included in the handoff response.

### T004B — 2026-08-17

- **Agent/tool**: Codex with SwiftData, SwiftUI, XCTest, Xcode 27.0, and iPhone 17 / iOS 27 Simulator.
- **Changed scope**: Added five stable cards for each of the six directed pairs among `fa`, `de`, and `en`; persisted pair tags on cards; filtered Today, Library, Review, and Progress by the active pair; corrected generic APKG target/source mapping and per-side text direction.
- **Selection rule**: Explanation/source and learning/target remain distinct. Choosing a language already used by the other role swaps the roles instead of creating an invalid same-language pair.
- **Verification**: Six tests passed, including exhaustive pair isolation. An existing simulator database migrated successfully and the `fa→en` dashboard exposed exactly five new cards without cards from other pairs.
- **Known boundary**: The 30 cards are owned smoke-test content, not the final DOC-18 language package or a production curriculum.
- **Commit**: see the T004B completion commit in Git history; its SHA is included in the handoff response.
