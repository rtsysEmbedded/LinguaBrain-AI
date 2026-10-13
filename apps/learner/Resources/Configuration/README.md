# App Configuration

The learner app reads provider settings and AI prompt text from the JSON files in this directory. Source code must not repeat these values.

| File | Loaded as | Purpose |
| --- | --- | --- |
| `provider-catalog.json` | `ProviderCatalog.bundled` | Default provider mode and protocol, endpoints, model identifiers, model lists, voices, request parameters, and Realtime transcription profiles. |
| `ai-prompts.json` | `AIPromptCatalog.bundled` | Prompt templates sent to text and image providers, and topic scopes for card generation. |
| `content-rules.json` | `LearningContentRules.bundled` | Default language pair and domain, stored deck names, generic domain names, part-of-speech markers, topic-classification terms, CEFR level lists, the weak-card threshold, skill-practice session limits, and the daily-plan coefficients. |
| `seed-cards.json` | `SeedCardCatalog.bundled` | Built-in vocabulary seeded into an empty installation and the multilingual sample cards. |

All files are bundled into the iOS and macOS app targets. The loader is `apps/learner/App/AppConfiguration.swift`.

## Loading rules

- The files are decoded once, on first use.
- A missing file, a malformed file, or a missing field stops the app with a diagnostic that names the file. There is deliberately no second, hardcoded copy of the values in code.
- `schemaVersion` is currently `1`. Increase it when the structure changes incompatibly.
- `AppConfigurationTests` in `apps/learner/Tests` verifies that the bundled files decode, that defaults are consistent, and that the daily-plan formula reproduces reference values.

## Values that apply only to new installations

The defaults are used only when the learner has not saved a value yet. Values the learner already saved in Settings (endpoint, model, voice, mode) are stored in `UserDefaults` and take precedence.

## `provider-catalog.json`

| Field | Meaning |
| --- | --- |
| `defaultMode` | Initial mode for the Text, Audio, and Image providers. Must be one of `built-in`, `local`, `cloud`, `off`. |
| `defaultProtocol` | Initial provider protocol. `openai-compatible` is the only protocol supported for text generation. |
| `endpoints.text`, `endpoints.image` | Initial base URLs (without a trailing slash) for text and image requests. |
| `endpoints.realtimeTranscription` | WebSocket URL for cloud live transcription in Utilities. |
| `models.*` | Initial model identifier for each role: `text`, `image`, `speech` (card pronunciation), `transcript` (completed audio), `stream` (live microphone text). |
| `defaultModelOptions.*` | Model lists shown before the provider's model list has been fetched. |
| `preferredModelOrder.*` | Sort order applied to models fetched from an endpoint whose host contains `hostMarkers.openAI`. |
| `openAICompatibleAudio` | Default voice and audio response format for OpenAI-compatible speech. |
| `googleNativeAudio` | Default voice, model marker, gender, encoding, and speaking rate for Google Cloud Text-to-Speech. |
| `hostMarkers.openAI` | Host fragment that identifies the OpenAI API. |
| `hostMarkers.googleTextToSpeech` | Host fragment of a stale Google audio endpoint that is repaired for OpenAI-compatible audio. |
| `hostMarkers.legacyGoogleVoice` | Voice-name fragment of a stale Google voice that is replaced by the OpenAI-compatible default. |
| `hostMarkers.replacedTextEndpoints` | Host fragments of stored text endpoints that are replaced with `endpoints.text` at launch. See audit finding A3 in `docs/PROJECT_AUDIT_2026-10-13.md`; an empty list disables the replacement. |
| `requests.<operation>` | `timeoutSeconds`, `temperature`, and optional `maxTokens` per text operation. When `maxTokens` is absent, no `max_tokens` field is sent. |
| `vocabularyExtraction.minimumConfidence` | Candidates with a lower model confidence are discarded. |
| `cardGeneration.maximumPassageCharacters` | Maximum learner passage length included in a card-generation prompt. |
| `cardGeneration.minimumNormalizationConfidence` | In the passage flow, a word whose dictionary form the model normalized with a lower confidence is not turned into a card. |
| `imageGeneration` | Image `size`, image `count`, and `responseFormat`. |
| `realtimeTranscription.connectionTimeoutSeconds` | Time allowed for the WebSocket to open. |
| `realtimeTranscription.noiseReduction` | Input noise-reduction type sent in the session update. |
| `realtimeTranscription.supportedModels` | Models accepted for cloud transcription; any other selection falls back to `models.stream` or `models.transcript`. |
| `realtimeTranscription.profiles` | Per-model language hint: `languageField` is `language` (single ISO 639-1 code), `languages` (list), or absent (no hint); `delay` is optional. |
| `realtimeTranscription.defaultProfile` | Profile for models without an entry in `profiles`. |

## `ai-prompts.json`

Templates use `{name}` placeholders. Rendering is single-pass: a substituted value is never scanned again, so learner text that contains braces is sent unchanged. Unknown placeholders are left as written.

| Template | Placeholders |
| --- | --- |
| `translateText` | `sourceLanguageTag`, `targetLanguageTag` |
| `extractImportantWords` | `languageTag`, `topic`, `minimumLevel` |
| `normalizeVocabularyItem` | `languageTag` |
| `representativeSenses` | — |
| `generateCardCategoryScope` | `categoryScope`, `sourceLanguageTag`, `targetLanguageTag` |
| `generateCardLanguageContract` | `targetLanguageTag`, `sourceLanguageTag` |
| `generateCardPassageContext` | `passage` |
| `generateCardNoPassageContext` | — |
| `generateCardMinimumLevel` | `level` |
| `generateCardSystem` | `targetLanguageTag`, `sourceLanguageTag` |
| `generateCardUser` | `targetLanguageTag`, `word`, `domain`, `categoryScope`, `contextInstruction` |
| `translate`, `streamTranslate` | `targetLanguageTag` |
| `a1ImageIllustration` | `word` |
| `cardImageIllustration` | `word` (batch and passage card images) |
| `generateCardSchemaRetry` | `word`; the learner passage, if any, is appended after rendering |
| `generateCardSourceLanguageRetry` | `sourceLanguageTag`, `passage` |

The card-generation user message is assembled as:

1. `categoryScope` = `generateCardCategoryScope` with the resolved topic scope.
2. `contextInstruction` = `generateCardLanguageContract` + (`generateCardPassageContext` or `generateCardNoPassageContext`) + (`generateCardMinimumLevel` when a level is requested).
3. `generateCardUser` with both values.

### Topic scopes

`categoryScopes` is an ordered list. The learner category is case- and diacritic-folded; the first entry whose `equals` list contains the folded category, or whose `contains` list has a fragment found in it, supplies the scope. Otherwise `defaultCategoryScope` is used with the `{domain}` placeholder.

## `content-rules.json`

| Field | Meaning |
| --- | --- |
| `defaults.sourceLanguageTag`, `defaults.targetLanguageTag` | Language pair used before the learner chooses one, and for imported cards without language tags. |
| `defaults.domain` | Domain assigned to cards without a topic. |
| `deckNames.core`, `deckNames.generated`, `deckNames.multilingual` | Names of the built-in, AI-generated, and multilingual sample decks. Existing decks are found by these names; cards in the built-in and multilingual decks count as reviewed content. |
| `deckNames.cloudFallback` | Deck for cards restored from an iCloud backup whose deck name is missing. |
| `classifierFallbackDomain` | Domain returned when no classification term matches. |
| `genericDomainNames` | Lower-cased domain names treated as "no topic"; such cards may be reclassified. |
| `nounPartOfSpeechMarkers`, `verbPartOfSpeechMarkers` | Case-insensitive fragments that identify nouns (article practice) and verbs (odd-meaning practice) in a stored part of speech. |
| `domainKeywords` | Ordered topic terms; the domain with the most matching terms in a card's text wins. |
| `levels.cefr` | Ordered CEFR scale. Used to compare levels and as the allowed values in structured model output. |
| `levels.cardGeneration`, `levels.cardGenerationDefault` | Minimum-level choices and default in the batch and passage flows of Add Word. |
| `onboarding.levels`, `onboarding.defaultLevel` | Current-level choices and default in onboarding. A value that is not in `levels.cefr` is displayed with the localization key `onboarding.level.<value>`. |
| `onboarding.missionKeys`, `onboarding.defaultMissionKey` | Localization keys of the learning goals offered in onboarding, and the preselected goal. |
| `addWord.initialWord` | Word prefilled in the single-word field of Add Word. |
| `addWord.defaultTopic` | Topic preselected for single-word and batch generation. |
| `addWord.defaultExportFileName` | Package name used when the batch export name is empty; `.apkg` is appended. |
| `weakStrengthThreshold` | A reviewed card whose memory strength is below this value counts as weak (Today, Library filter and tint). |
| `skillPractice.cardLimitWithoutNewCardLimit` | Session size of the legacy skill practice when today's new-card limit is 0. |
| `skillPractice.maximumCardLimit` | Upper bound of a legacy skill-practice session, and its size when no limit is passed. |
| `dailyPlan.defaultEnergy`, `defaultAvailableMinutes`, `defaultMotivation` | Today check-in values before the learner answers. |
| `dailyPlan.availableMinuteOptions` | Time choices in the Today check-in. |
| `dailyPlan.*Factor*`, `minutesPerNewCard`, `modeFactors`, `maximumNewCards` | New cards per session = `min(maximumNewCards, round(minutes / minutesPerNewCard × (energyFactorBase + energy / energyFactorDivisor) × (motivationFactorBase + (motivation − 1) × motivationFactorStep) × modeFactor))`, then capped by the number of unreviewed cards. |
| `dailyPlan.recoveryEnergyAtMost`, `challengeEnergyAtLeast` | Energy bounds for the recovery and challenge labels on Today. |

**Stable identifiers.** `defaults`, `deckNames`, and `genericDomainNames` are compared with values already stored on learners' devices. Changing them after release orphans existing records or creates duplicate decks. The three `defaults` values are also mirrored by the SwiftData schema defaults of `PrototypeCardRecord` (`domain`, `sourceLanguageTag`, `targetLanguageTag`), which are needed for lightweight migration of older stores and must stay literal; keep both in sync and never change either after release.

## `seed-cards.json`

| Field | Meaning |
| --- | --- |
| `words` | German–Persian cards (`german`, `persian`, `level`, `partOfSpeech`, `example`, `exampleTranslation`, optional `article`) inserted only into an empty store. |
| `multilingualSampleDefaults` | `idPrefix`, `level`, `partOfSpeech`, and `domain` shared by all sample cards. |
| `multilingualSamples` | One card per entry with `number`, language tags, and source/target text and examples. The card ID is `idPrefix` followed by `number` as 12 zero-padded digits, so `number` must never be reused or changed. |

## Values that remain in code

These values are part of code contracts rather than settings and stay in Swift:

- JSON Schemas for structured model output, which must match the Swift decoding types. Their CEFR enumerations are read from `levels.cefr`.
- Realtime and chat-completion protocol event names, field names, and the 24 kHz PCM input format.
- Substring heuristics that classify fetched model identifiers into speech, transcript, and stream roles.
- Persisted protocol identifiers (`openai-compatible`, `google-native`).
- The SwiftData schema defaults of `PrototypeCardRecord` described above.
- Language facts used as logic, such as treating Persian (`fa`) as right-to-left.
- Format-specific import mappings, such as the field names of known Anki deck layouts.
- Input scales that are part of stored data: daily energy 1–10 and motivation 1–5 (clamped by `PrototypeStore.saveDailyLearningState` and `DailyLearningState`).
- FSRS-6 algorithm constants and numeric tolerances, which are defined by the scheduler specification rather than by product settings.
