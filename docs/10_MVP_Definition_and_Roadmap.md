---
title: MVP Definition and Roadmap
document_id: LB-DOC-10
version: 0.1.0
status: Draft
last_updated: 2026-07-11
---

# MVP Definition and Roadmap

## Purpose

This document defines the smallest production-quality release that can validate LinguaBrain's central hypothesis:

> A deterministic Learning Engine using skill-level mastery, connected knowledge, FSRS, and controlled AI enrichment can provide a more relevant learning experience than manually organized flashcards.

The MVP is intentionally narrow. It must prove the learning loop before the project invests in broad language coverage, real-time conversation, social features, or cloud scale.

## Target learner

The primary MVP user is a Persian-speaking adult learning German at beginner or intermediate level who wants general or professional vocabulary, has limited daily study time, and is willing to use either a personal AI API key or validated cached content.

## Primary user journey

```mermaid
flowchart TD
    A[Onboarding: Persian → German] --> B[Choose level and mission]
    B --> C[Daily time and energy check-in]
    C --> D[Enter or select a German word]
    D --> E[Validate and enrich KnowledgeItem]
    E --> F[Create objectives and graph relations]
    F --> G[Build adaptive learning plan]
    G --> H[Review and practice]
    H --> I[Record events and update mastery]
    I --> G
```

## MVP scope

### Required product capabilities

1. **Local learner profile**
   - Persian learner language and German target language.
   - CEFR level, active mission, domains, daily target, and preferences.

2. **Daily check-in**
   - Available time and energy are required.
   - Preferred mode is optional: recovery, growth, or challenge.

3. **Knowledge-item ingestion**
   - Manual entry of a word or phrase.
   - Duplicate detection and German lemma normalization.
   - Preview and approval before unverified enrichment becomes canonical.

4. **Smart card enrichment**
   - Persian meaning, part of speech, CEFR estimate, pronunciation where available, and level-appropriate example.
   - German noun article/plural and essential verb forms.
   - Provider-independent AI with validation and caching.

5. **Automatic collections**
   - All items, nouns, verbs, adjectives, weak items, due reviews, CEFR level, and selected domain.
   - Collections are views; they do not duplicate KnowledgeItems.

6. **Basic Knowledge Graph**
   - Word family, related phrase, grammar relation, domain relation, synonym/antonym when validated.
   - One-hop learner-facing related-items view.

7. **Learning objectives and mastery**
   - Recognition, recall, and grammar usage are required.
   - Listening can use cached audio when available.
   - Mastery changes remain traceable to LearningEvents.

8. **FSRS review scheduling**
   - Again, Hard, Good, and Easy outcomes.
   - Persistent review history and offline scheduling.

9. **Adaptive daily plan**
   - Combines due reviews, weak objectives, mission relevance, time, and energy.
   - Provides a concise rationale and offline fallback.

10. **MVP exercises**
    - German → Persian recognition.
    - Persian → German recall.
    - Multiple-choice cloze.
    - Constrained word-form or article practice.

11. **Progress summary**
    - Due/learned counts, mastery by supported skill, weak patterns, mission progress, and recent activity.

12. **Data ownership**
    - Local-first storage, JSON/CSV export for core learner data, secure BYOK storage, and deletion controls.

## Explicit non-goals

- Full real-time AI conversation.
- Automatic pronunciation scoring.
- Complete OCR/PDF ingestion.
- Multi-device cloud sync and accounts.
- Social feeds, leaderboards, marketplace, or shared public decks.
- Multiple target languages.
- Fully general Learning OS support beyond the language-domain contracts.
- Advanced Level 1 image curriculum authoring.

These are postponed, not silently included in MVP estimates.

## Technology baseline

| Area | MVP choice |
| --- | --- |
| Client | Flutter, mobile-first |
| State management | Selected during Technical Architecture ADR |
| Local persistence | SQLite with migrations and repository abstraction |
| Review algorithm | FSRS implementation behind a scheduler interface |
| AI integration | Provider adapters; BYOK and OpenAI-compatible local endpoint |
| Backend | Not required for local MVP; FastAPI reserved for later sync/services |
| Audio | Cached TTS or validated media; offline playback |
| Testing | Unit, integration, widget, migration, and AI contract evaluations |

## Delivery milestones

### M0 — Repository and specifications

- Documents 01–14 completed.
- ADR process, coding conventions, and executable acceptance criteria established.
- Deliverable: approved implementation backlog.

### M1 — Domain walking skeleton

- Flutter shell and local database.
- KnowledgeItem, learner profile, LearningEvent, and repository interfaces.
- One manual German word can be stored and retrieved offline.

### M2 — Card and language foundation

- German/Persian package minimum capabilities.
- Manual ingestion, duplicate detection, validation preview, smart card display.
- Provider-independent enrichment with cache.

### M3 — Review loop

- LearningObjectives, FSRS state, rating flow, review history.
- Recognition and reverse-recall exercises.
- Complete offline review session survives restart.

### M4 — Adaptive intelligence

- Daily check-in, candidate ranking, session builder, weak-skill targeting.
- Basic Digital Twin summaries and explainable recommendations.

### M5 — Connected learning

- Validated one-hop graph, word-family view, cloze/article/form exercises.
- Mission/domain relevance in plan selection.

### M6 — MVP hardening and pilot

- Accessibility and RTL/LTR QA.
- Export/deletion, secure key storage, performance testing, crash recovery.
- Pilot release and measured learning feedback.

## MVP acceptance scenario

The release must demonstrate this end-to-end path:

1. A Persian-speaking learner selects German A2 and the mission “Work in Germany.”
2. They report 15 minutes and energy 4/10.
3. They add `arbeiten`.
4. The system normalizes it, enriches it, validates essential forms, and presents a preview.
5. The accepted item appears in All Items, Verbs, A1/A2 metadata, and Work collections without duplication.
6. Recognition, recall, and present-form objectives are created.
7. The daily plan combines due reviews with a short recovery-friendly activity.
8. Responses create LearningEvents, update objective mastery, and schedule future reviews.
9. The learner can close the app, reopen it offline, and continue without lost progress.

## Success metrics

### Product quality

- ≥99% successful persistence of completed local learning events in test scenarios.
- Core offline interactions meet Document 03 latency targets.
- Zero API keys in database, logs, analytics, or exports.
- AI enrichment records 100% required provenance metadata.

### Learning value

- Learners complete recommended sessions without excessive manual organization.
- Recall mastery is measured separately from recognition.
- Pilot learners report that recommendations are understandable and relevant.
- Retention and lapse trends can be compared with a non-adaptive baseline after sufficient data.

### Engagement guardrails

- Session completion and return rate may be measured with consent.
- Streak length and card volume are not primary success metrics.
- No dark patterns or punishment for missed days.

## Release gates

The MVP cannot enter pilot until:

- critical user journeys have integration tests;
- migration and backup/restore paths are verified;
- mixed Persian/German layouts pass accessibility review;
- AI failure does not block review;
- generated linguistic facts pass defined validation policy;
- privacy disclosures and local deletion/export behavior are complete.

## Post-MVP roadmap

| Phase | Candidate capabilities |
| --- | --- |
| 1.1 | Listening expansion, richer progress insights, import lists |
| 1.2 | OCR/text/PDF extraction with approval workflow |
| 1.3 | Guided writing and speaking evaluation |
| 2.0 | Account, encrypted sync, multiple devices |
| 2.x | Additional language packages and exam missions |
| Future | Conversation coach, professional plugins, broader Learning OS |

Roadmap candidates require evidence from the MVP and separate specifications.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Scope expansion | Enforce explicit non-goals and release gates. |
| Incorrect AI content | Structured output, validation, provenance, preview. |
| Over-engineered generality | Implement only German–Persian capabilities needed by MVP interfaces. |
| Weak adaptive data at start | Use transparent defaults and gradually personalize. |
| RTL/LTR usability defects | Include mixed-direction tests from M1 onward. |
| Vendor cost/dependency | BYOK, cache, local endpoint, deterministic fallback. |

## Open questions

- Which Flutter platforms are included in the first pilot: Android only or Android plus iOS?
- Which validated German lexical dataset is available under acceptable licensing?
- What pilot size and duration can provide meaningful retention evidence?
- Which FSRS library/version will be adopted and independently tested?

## Related documents

- `03_Non_Functional_Requirements.md` — Release quality constraints.
- `07_Adaptive_Learning_Engine.md` — Plan construction and ranking.
- `09_Language_Independence_Framework.md` — MVP German/Persian packages.
- `11_Technical_Architecture.md` — Implementation boundaries.
- `14_Frontend_UX_UI.md` — MVP screens and journeys.

## Revision history

| Version | Date | Description |
| --- | --- | --- |
| 0.1.0 | 2026-07-11 | Initial MVP definition and delivery roadmap. |
