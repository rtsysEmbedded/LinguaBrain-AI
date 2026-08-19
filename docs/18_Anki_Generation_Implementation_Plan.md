# Hermes Anki Generation Implementation Plan

## Phase 1 — Contracts and models

- Define `GenerationRequest`, `CardProposal`, `GeneratedCardBundle`, and `GenerationProvenance`.
- Define proposal and approval states.
- Define versioned schemas and fixtures.
- Connect to `LexicalSense`, `Sentence`, and `MediaAsset`.

## Phase 2 — Orchestrator and providers

- Build `AnkiGenerationOrchestrator`.
- Add the OpenAI-compatible/OpenRouter adapter.
- Require structured output.
- Implement timeout, cancellation, retry, and usage reporting.
- Preserve the manual/no-AI path.

## Phase 3 — Validation and duplicates

- Implement deterministic validation and text normalization.
- Implement sense-aware duplicate detection.
- Test polysemy such as `Bank`.
- Prevent commits when validation fails.

## Phase 4 — Media and approval

- Generate and cache audio.
- Support text-only fallback.
- Build card preview and transactional approval.
- Persist provenance and cache references.

## Phase 5 — Export

- Implement TSV with stable columns and language/level/source tags.
- Test TSV re-import.
- Implement APKG after collection, templates, media ownership, and round-trip tests are stable.

## Required tests

- Partial batch approval and cancellation;
- invalid or incomplete JSON;
- wrong target language;
- duplicates and multiple senses;
- provider without audio;
- restart before and after approval;
- RTL Persian and LTR German rendering;
- no API-key leakage in logs, storage, or exports.

## Definition of done

A learner can generate cards from a natural-language request or form, review and approve them, study them offline, and export the approved content as TSV or APKG without regenerating it.

