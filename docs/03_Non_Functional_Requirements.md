---
title: Non-Functional Requirements
document_id: LB-DOC-03
version: 0.2.0
status: Draft
last_updated: 2026-07-11
---

# Non-Functional Requirements

## Purpose

This document defines the quality attributes and operating constraints for LinguaBrain AI. Functional requirements describe what the product does; these requirements describe how safely, quickly, reliably, privately, and sustainably it must do it.

## Architectural baseline

LinguaBrain is a deterministic, offline-first Learning Engine with an optional AI enhancement layer.

> The application must remain useful when a network connection or AI provider is unavailable.

AI generation may be delayed or unavailable. Existing knowledge items, review scheduling, cached exercises, learner history, and core progress tracking must continue to work.

## Performance

### User-facing response targets

| Operation | Target | Notes |
| --- | --- | --- |
| Open a locally stored card | ≤ 100 ms | Excludes image/audio download. |
| Start an offline review session | ≤ 300 ms | From a warm local database. |
| Save a review outcome | ≤ 100 ms | Persist locally before sync. |
| Local vocabulary search | ≤ 200 ms | At 10,000 knowledge items. |
| Build a local daily plan | ≤ 1 s | No network dependency. |
| Basic graph relation query | ≤ 100 ms | At MVP data scale. |
| AI request acknowledgement | ≤ 250 ms | Show cancellable progress after local validation. |
| AI completion | Measured p50/p95, no hard provider-independent SLO | Timeout/fallback policy applies; provider latency is reported separately. |

### Interface performance

- The application must avoid blocking the UI during database access, media processing, AI requests, or synchronization.
- Scrolling lists of cards, decks, review history, and search results must use paging or virtualization.
- The primary mobile experience should target smooth interaction on a mid-range device.
- Expensive graph visualizations must load on demand and must not block a review session.

Performance acceptance uses a named benchmark device class, a fixed 10,000-item/50,000-event dataset, cold/warm conditions, and p50/p95 results. The exact pilot device is recorded in the implementation test plan.

### Capacity targets for the MVP

- At least 50,000 locally stored knowledge items per learner.
- At least 200,000 stored graph relations per local database.
- Review history retained indefinitely, subject to a documented archival/compression policy.
- Configurable audio cache; default target is no more than 200 MB.

## Reliability and resilience

### Offline-first behavior

The following capabilities are required without network access:

- browsing locally stored knowledge items and smart decks;
- FSRS review scheduling and review completion;
- recording learning events and updating local mastery state;
- local search;
- cached card content, examples, and media;
- template-based basic exercises where sufficient data is available.

The following may degrade gracefully while offline:

- new AI enrichment;
- AI-generated exercises or explanations;
- cloud synchronization;
- cloud text-to-speech and speech recognition.

### Failure behavior

| Failure | Required behavior |
| --- | --- |
| Network loss | Preserve local work; present offline state without blocking core learning. |
| AI timeout or provider error | Retry only when safe; offer cached/rule-based fallback; never lose user input. |
| Invalid AI output | Reject or quarantine it; do not persist it as verified learning data. |
| Application interruption during review | Persist the latest completed event atomically; resume safely. |
| Local database corruption | Detect it, protect the original data, offer restore from backup/export, and log diagnostics. |
| Sync conflict | Preserve event history and apply documented conflict-resolution rules. |

### Data integrity

- Every persisted domain entity must have a stable identifier.
- Learning events are append-only; corrections must be represented as subsequent events or auditable revisions.
- AI-generated content must retain provenance: provider/model, prompt version, timestamp, validation state, and source input where allowed.
- The UI must not write directly to persistence; domain/application services enforce validation.
- AI providers must never write directly to learner state, review schedule, or the graph.

## Security

### Authentication and authorization

The MVP may operate in local-only mode without a cloud account. When accounts and synchronization are introduced:

- authentication tokens must be short-lived and revocable;
- authorization must enforce ownership of all user-scoped data;
- server-side APIs must validate input and never trust client-side learning state blindly;
- administrative access must be separated from normal learner access.

### API keys and BYOK

Users may provide their own keys for supported AI providers.

- Keys must be stored only in platform-secure encrypted storage.
- Keys must never be written to logs, analytics, exported reports, screenshots, or normal database fields.
- A user-provided key must be sent only to the selected provider endpoint.
- The application must make it clear whether a request uses a personal key, a project-managed service, or a local model.
- Removing a provider configuration must securely remove associated local key material.

### Secure engineering baseline

- Validate and normalize external input, including imported text and OCR output.
- Apply output-size limits and timeouts to AI, OCR, and media operations.
- Avoid executing arbitrary model-generated code, URLs, commands, or database queries.
- Keep dependencies updated through a documented dependency-review process.
- Use secure transport for all network calls.

## Privacy and data ownership

### Ownership

Learners own their knowledge items, learning history, settings, AI usage configuration, and exported data.

### Data minimization

- Collect only information necessary for learning features the user has enabled.
- Telemetry must be opt-in and must not include raw API keys, full private learning content, or sensitive free-form notes.
- The product must disclose what is sent to an AI provider before cloud generation is used.

### Export and deletion

The product roadmap must provide user-readable export of core data and a clear deletion path for local and future synchronized data. Export format requirements are specified in the persistence and import/export documents.

## AI reliability, safety, and cost control

### AI is optional

The Learning Engine must not depend on a particular provider, model, or internet connection. Provider adapters must be replaceable.

### Validation and hallucination control

- Structured AI tasks should require schema-conforming output.
- High-impact linguistic facts, such as morphology and grammar classifications, must be validated against language rules, trusted lexical sources, or explicit user review where appropriate.
- The system must mark AI suggestions as unverified until validation completes.
- Prompt instructions must separate untrusted user content from system-controlled task instructions to reduce prompt-injection risk.

### Cost controls

- Cache generated content using a key based on task, inputs, language pair, level, domain, prompt version, and relevant model settings.
- Prefer local deterministic transformations and existing validated content before calling AI.
- Batch independent operations only when it does not reduce validation quality or user control.
- Enforce configurable daily and monthly request/token budgets.
- Provide a user-facing AI usage view showing provider, request count, estimated token usage, and estimated cost where available.

## Synchronization and multi-device support

Synchronization is not an MVP prerequisite, but the local architecture must remain ready for it.

- Local changes are recorded as durable events suitable for later delta sync.
- Review outcomes and learning events take precedence over derived AI enrichment.
- User edits take precedence over regenerated AI metadata.
- Conflicts must be visible, recoverable, and logged; silently discarding learning events is not acceptable.
- Sync must be idempotent: replaying the same event cannot duplicate results.

## Maintainability and extensibility

- Core domain logic must remain independent of UI framework, database implementation, and AI provider SDKs.
- Language-specific rules belong to language packages, not general-purpose core code.
- Exercise types must have an explicit interface so that new forms can be added without changing the Learning Engine's essential logic.
- Prompts must be versioned and stored outside compiled application logic where possible.
- Significant technical choices require Architecture Decision Records in `decisions/`.
- Public module interfaces must be documented and covered by automated tests appropriate to their risk.

## Observability

Observability must be privacy-conscious and useful for diagnosing product quality.

### Required local diagnostics

- application and migration errors;
- synchronization failures;
- AI provider failures without secret values;
- cache hit/miss metrics;
- performance timings for key user flows.

### Product metrics

Subject to user consent, the project may collect aggregated measures such as:

- session completion rate;
- review completion rate;
- recall/retention trends;
- exercise outcomes by skill;
- AI request success and latency;
- learning-plan acceptance or modification.

Metrics must support product improvement, not surveillance or advertising profiles.

## Accessibility and localization

- Support scalable text, screen readers, keyboard navigation where applicable, and high-contrast/dark modes.
- Persian interface and content flows must correctly support RTL rendering; German learning content must retain correct LTR behavior within mixed-language screens.
- Audio controls must support replay and configurable speed.
- Accessibility requirements are expanded in `14_Frontend_UX_UI.md`.

## Acceptance criteria

The MVP architecture satisfies this document when:

- a learner can complete an offline review session and retain all results after app restart;
- an unavailable AI provider cannot prevent reviewing, searching, or building a local plan;
- user API keys are absent from databases, logs, and exports;
- AI output cannot directly modify learning schedules or mastery state;
- key local interactions meet the stated response targets on the supported MVP device class;
- an AI-generated item records source and validation metadata;
- the project can add a language package or AI provider without a core-engine rewrite.

## Open questions

- Which platform-secure storage APIs are required for the initial Flutter targets?
- Which encryption approach is justified for the local MVP database, given usability and recovery trade-offs?
- What operational metrics are acceptable under the final privacy policy?
- At what scale, if any, should a graph database replace relational graph tables?
- What backup mechanism best supports local-only learners before cloud sync exists?

## Related documents

- `01_Product_Vision.md` — Product direction and MVP scope.
- `02_Learning_Philosophy.md` — Educational principles.
- `08_AI_Orchestration_Layer.md` — Provider routing, prompts, validation, and caching.
- `11_Technical_Architecture.md` — Module boundaries and deployment design.
- `12_Database_Schema_and_Persistence.md` — Data model, migrations, and backups.

## Revision history

| Version | Date | Description |
| --- | --- | --- |
| 0.2.0 | 2026-07-11 | Cross-document architecture review; resolved domain, validation, scheduling, privacy, and MVP consistency contracts. |
| 0.1.0 | 2026-07-10 | Initial non-functional requirements specification. |
