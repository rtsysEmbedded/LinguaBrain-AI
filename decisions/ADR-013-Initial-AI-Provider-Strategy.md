---
title: "ADR-013: Initial AI Provider Strategy"
status: accepted
date: 2026-08-10
decision_makers:
  - Product Owner
  - AI Platform Architect
decision_ids:
  - LB-DEC-061
work_items:
  - LB-WI-M2-04
  - LB-WI-M2-11
---

# ADR-013: Initial AI Provider Strategy

## Context

LinguaBrain needs optional AI card enrichment for German–Persian content while
remaining usable without AI. Apple OS 27 provides Foundation Models access to
the on-device Apple Intelligence model without an application API key, but
availability depends on eligible hardware, Apple Intelligence being enabled,
download readiness, region, and supported language/locale. Persian is not a
guaranteed Apple Intelligence language for the current product baseline.

OpenRouter provides one authenticated API surface for many model families and
supports provider/model routing and structured output on compatible models. It
therefore reduces the number of provider-specific integrations needed for the
first cloud implementation while preserving model choice.

## Decision

1. OpenRouter is the first third-party cloud adapter implemented after the Anki
   Core acceptance gate.
2. The learner supplies an OpenRouter API key. It is stored only in Keychain,
   never in SwiftData, logs, exports, prompts, or analytics.
3. The app exposes explicit model selection, connection testing, estimated
   usage/cost, configurable budgets, and privacy disclosure before cloud use.
4. Card generation requests require strict JSON Schema output when the selected
   model supports it. The router must require requested parameters rather than
   silently selecting an incompatible endpoint.
5. Requests containing private learner data default to endpoints that deny data
   collection or provide an approved zero-data-retention policy. Raw meeting
   audio/transcripts require separate explicit consent and are out of the first
   card-generation integration.
6. Apple Foundation Models remains a planned optional on-device adapter. It
   requires no user API key, but it is capability- and locale-gated and cannot
   be the sole German–Persian provider until Persian quality/support passes the
   product evaluation suite.
7. The no-AI path and imported/manual cards remain first-class. Provider output
   is a proposal that must pass schema and language validation and user approval
   before persistence.
8. Neither OpenRouter nor Apple Foundation Models may write scheduling,
   mastery, Knowledge Graph, or canonical learner data directly.

## Routing baseline

```text
Card enrichment request
        |
        v
AI Orchestrator + task/schema contract
        |
        +--> OpenRouter adapter (initial cloud implementation)
        |
        +--> Apple Foundation Models (future, on-device, no API key)
        |
        +--> Local/OpenAI-compatible adapter (future fallback)
        |
        +--> No-AI/manual path
        v
Validation proposal -> learner preview -> application transaction
```

## Consequences

- One initial cloud integration offers broad model choice.
- OpenRouter still requires an API key and network connection and transmits
  request content through OpenRouter and the selected model provider.
- Privacy policy and retention differ by routed provider, so routing constraints
  and user-visible provenance are mandatory.
- Apple on-device generation can later reduce cost and improve privacy for
  supported tasks without changing domain or Learning Engine contracts.
- Prompt/model evaluations must be versioned because both routed cloud models
  and Apple's system model change over time.

## Revisit triggers

- Apple adds supported, evaluated Persian generation suitable for the card
  contract.
- OpenRouter changes authentication, privacy, routing, or structured-output
  behavior materially.
- Evaluation shows a direct provider or local model is substantially safer,
  cheaper, or more accurate for German–Persian cards.
- The dedicated-device work requires a different offline inference runtime.

## References

- [Apple Foundation Models](https://developer.apple.com/documentation/FoundationModels)
- [Apple SystemLanguageModel availability](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)
- [OpenRouter quickstart](https://openrouter.ai/docs/quickstart)
- [OpenRouter structured outputs](https://openrouter.ai/docs/guides/features/structured-outputs)
- [OpenRouter provider routing](https://openrouter.ai/docs/guides/routing/provider-selection)

