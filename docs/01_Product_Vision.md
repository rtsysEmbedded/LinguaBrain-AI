---
title: Product Vision
document_id: LB-DOC-01
version: 0.3.0
status: Draft
last_updated: 2026-07-21
---

# Product Vision

## Executive summary

LinguaBrain AI is an adaptive learning platform that combines cognitive science, spaced repetition, knowledge graphs, and optional AI assistance to create a personalized learning experience. It is not merely a flashcard application: it models what a learner knows, how confidently they can use it, and what they should do next.

The first implementation targets Persian-speaking learners of German. The product core is language-independent so that future language pairs and, eventually, non-language learning domains can reuse the same Learning Engine.

## Vision statement

Build a personal learning system that understands each learner's knowledge, skills, goals, strengths, weaknesses, current energy, and available time—and turns that understanding into the best next learning activity.

## Mission

Make structured, personalized language learning accessible without requiring users to manually create, organize, or schedule flashcards.

LinguaBrain should continuously answer:

1. What should this learner study now?
2. Why is it important for their goal?
3. Which skill needs practice: recognition, recall, listening, speaking, or writing?
4. How difficult should the activity be today?
5. What should follow after this activity?

## Problem

Traditional flashcard tools are excellent at scheduling reviews but impose manual content creation and organization on the learner. They typically do not understand semantic relationships between concepts, professional goals, or the difference between recognizing a word and being able to use it in conversation.

AI chat tools can explain grammar and create examples, but normally lack a durable, auditable model of the learner's knowledge and learning history. They generate content well; they do not provide reliable long-term learning management by themselves.

## Product solution

LinguaBrain combines these complementary capabilities:

- A **Learning Engine** that makes deterministic educational decisions.
- A **User Knowledge Model** and **Digital Twin** that represent mastery by skill, behavior, goals, and recurring errors.
- A **Knowledge Graph** that connects words, phrases, grammar, concepts, domains, and prerequisites.
- An **AI Orchestration Layer** that generates and evaluates content while remaining replaceable.
- A **Spaced Repetition Engine** based on FSRS for review scheduling.
- A **Daily Learning State** check-in that adapts the session to the learner's energy, time, motivation, and preferred mode.

## Product principles

### AI assists; the Learning Engine decides

AI can propose relations, produce examples, generate exercises, and explain errors. It must not directly alter learning state or make final scheduling decisions. The deterministic engine validates AI output and maintains auditable user progress.

### Learning is multidimensional

Knowing a word is not binary. A learner may recognize it while reading but fail to recall, pronounce, write, or use it. The platform tracks these skills independently.

### Knowledge is connected

Every knowledge item should be connected, where appropriate, to related vocabulary, grammar, usages, domains, examples, and learning prerequisites. The system should grow a network of concepts rather than a list of isolated cards.

### The learner's current condition matters

Each daily session uses a brief check-in: energy, available time, motivation, and preferred learning mode. A low-energy five-minute session should favor achievable review; a high-energy one-hour session can include new material and productive practice.

### Offline first and privacy first

Review, cached content, and core learning logic must remain useful without network access. User data belongs to the user. The native Apple clients prefer eligible on-device Foundation Models and Speech capabilities, while user-selected cloud/local providers remain replaceable fallbacks where hardware, region, or German–Persian language support is unavailable.

### Language packages, not language-specific core code

German-to-Persian is the first language package. Morphology, grammar, pronunciation, writing direction, and cultural conventions must be modular so that new languages do not require rewriting the core Learning Engine.

## Target users

### Beginner and image-based learner (post-MVP curriculum)

Learns universal concepts through images, sound, and recognition-first activities. This mode is intended for children, complete beginners, and learners who benefit from minimal dependence on a written source language.

### General language learner

Builds practical German vocabulary and grammar for daily life, including home, shopping, travel, family, emotions, and social interaction.

### Professional learner

Learns language in a domain such as software engineering, embedded systems, business, medicine, finance, law, or engineering. Examples and exercise contexts are aligned with the selected professional mission.

## Learning levels

1. **Level 1 — Image-based learning (post-MVP):** language-light foundational concepts, visual recognition, and audio.
2. **Level 2 — General language:** CEFR-oriented everyday vocabulary, phrases, grammar, and contexts.
3. **Level 3 — Professional language:** specialized vocabulary, scenarios, texts, and exercises based on a chosen domain.

## Core experience

1. The learner completes setup: native language, target language, current level, mission, and optionally professional domain.
2. At the start of a session, they choose available time, energy, and preferred mode.
3. In the MVP they add a word or phrase—or follow the suggested plan. Text, image, and document ingestion are later pipeline entry points.
4. The system creates or retrieves enriched knowledge items, classifies them, adds graph relations, and updates smart collections.
5. The Learning Engine selects review and practice activities based on FSRS, mastery by skill, mission relevance, known errors, and the daily state.
6. Each answer updates the learner model, which improves future recommendations.

## Differentiators

- Automatic organization into smart decks such as verbs, nouns, CEFR levels, domains, and weak items.
- Word-family and grammar-aware learning instead of isolated vocabulary.
- Skill-specific mastery: recognition, recall, listening, production, and writing.
- A learner Digital Twin that tracks learning patterns and recurring errors.
- Adaptive plans that account for energy and time on a given day.
- Bring-your-own-key cloud AI and local-model support; no permanent dependence on one provider.
- A pathway from input material (including future OCR imports) to learning-ready cards, exercises, and plans.

## MVP boundaries

The MVP validates the Learning Engine with German ↔ Persian learning, AI-enriched word cards, automatic classification, basic graph relations, FSRS reviews, adaptive daily plans, and translation/cloze exercises.

The first production implementation is Apple-native: Swift 6.4 and SwiftUI targeting iOS/iPadOS 27 and macOS 27 Golden Gate. iPhone is the primary controlled-pilot surface; iPad and Mac are supported local-first surfaces. Optional Release 1.0 accounts may synchronize the approved learner-data scope under ADR-014, while signed-out use remains complete.

The MVP explicitly excludes full social features, leaderboards, marketplaces, comprehensive real-time speaking evaluation, multi-language expansion, and complete OCR book ingestion.

## Success measures

- Local item creation acknowledges immediately; optional AI completion is measured separately by provider p50/p95 latency.
- Learners can review and complete core exercises offline using stored content.
- The system distinguishes weak skills from merely weak words.
- Automated tests show that controlled changes to time/energy, due state, mastery, or mission produce explainable plan changes.
- Learners need minimal manual deck management.
- A preregistered pilot measures delayed recall, proposal edit rate, plan acceptance, and learner-rated relevance against defined stop/go thresholds.

## Long-term direction

LinguaBrain is expected to progress from an adaptive language learning platform to an AI language teacher and then to a general-purpose Personal Learning Operating System. Language learning remains the first and primary use case; broader domains are a future extension, not an MVP requirement.

The same native Swift core serves the iPhone, iPad, and Mac applications. A future focused device must preserve the Knowledge, Learning, Review, Planning, Language Package, and AI data/command semantics, but a non-Apple runtime is not promised direct SwiftUI or Apple-framework reuse and requires a separate interoperability decision.

## Related documents

- [Learning Philosophy](02_Learning_Philosophy.md)
- [Learning Domain Model](05_Learning_Domain_Model.md)
- [Knowledge Graph Architecture](06_Knowledge_Graph_Architecture.md)
- [Adaptive Learning Engine](07_Adaptive_Learning_Engine.md)
- [AI Orchestration Layer](08_AI_Orchestration_Layer.md)
- [MVP Definition and Roadmap](10_MVP_Definition_and_Roadmap.md)

## Revision history

| Version | Date | Description |
| --- | --- | --- |
| 0.3.0 | 2026-07-21 | Set the product's first implementation to native Swift/SwiftUI on iOS, iPadOS, and macOS 27 with Apple capability fallbacks and an explicit non-Apple device boundary. |
| 0.2.1 | 2026-07-11 | Added platform-neutral product-surface extension contract for a future dedicated device. |
| 0.2.0 | 2026-07-11 | Cross-document architecture review; resolved domain, validation, scheduling, privacy, and MVP consistency contracts. |
| 0.1.0 | 2026-07-10 | Initial consolidated specification based on the product-design discussion. |
