# App Configuration

The learner app reads provider settings and AI prompt text from the JSON files in this directory. Source code must not repeat these values.

| File | Loaded as | Purpose |
| --- | --- | --- |
| `provider-catalog.json` | `ProviderCatalog.bundled` | Default provider mode and protocol, endpoints, model identifiers, model lists, voices, request parameters, and Realtime transcription profiles. |
| `ai-prompts.json` | `AIPromptCatalog.bundled` | Prompt templates sent to text and image providers, and topic scopes for card generation. |

Both files are bundled into the iOS and macOS app targets. The loader is `apps/learner/App/AppConfiguration.swift`.

## Loading rules

- The files are decoded once, on first use.
- A missing file, a malformed file, or a missing field stops the app with a diagnostic that names the file. There is deliberately no second, hardcoded copy of the values in code.
- `schemaVersion` is currently `1`. Increase it when the structure changes incompatibly.
- `AppConfigurationTests` in `apps/learner/Tests` verifies that both bundled files decode and that defaults are consistent.

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

The card-generation user message is assembled as:

1. `categoryScope` = `generateCardCategoryScope` with the resolved topic scope.
2. `contextInstruction` = `generateCardLanguageContract` + (`generateCardPassageContext` or `generateCardNoPassageContext`) + (`generateCardMinimumLevel` when a level is requested).
3. `generateCardUser` with both values.

### Topic scopes

`categoryScopes` is an ordered list. The learner category is case- and diacritic-folded; the first entry whose `equals` list contains the folded category, or whose `contains` list has a fragment found in it, supplies the scope. Otherwise `defaultCategoryScope` is used with the `{domain}` placeholder.

## Values that remain in code

These values are part of code contracts rather than settings and stay in Swift:

- JSON Schemas for structured model output, which must match the Swift decoding types.
- Realtime and chat-completion protocol event names, field names, and the 24 kHz PCM input format.
- Substring heuristics that classify fetched model identifiers into speech, transcript, and stream roles.
- Persisted protocol identifiers (`openai-compatible`, `google-native`).
