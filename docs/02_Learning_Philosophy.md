---
title: Learning Philosophy
document_id: LB-DOC-02
version: 0.2.0
status: Draft
last_updated: 2026-07-11
---

# Learning Philosophy

## Purpose

This document defines the educational principles that guide LinguaBrain AI. It is the policy foundation for the Learning Engine, exercise design, feedback, and learner-facing recommendations.

LinguaBrain must optimize for durable, usable competence—not short-term exposure, streaks, or the number of cards viewed.

## Core statement

> Learning is the gradual ability to recognize, recall, understand, and use knowledge reliably in meaningful contexts.

For language learning, knowing a word is not a binary state. A learner may understand a word while reading but fail to recall it in speech, write it correctly, or use its grammar accurately. LinguaBrain therefore tracks and practices competence by skill.

## Design principles

### 1. Active retrieval over passive exposure

Seeing an answer again is useful for introduction and recovery, but it is not sufficient evidence of learning. The system should regularly ask the learner to retrieve information without immediately seeing the answer.

Examples:

- Persian meaning → German lemma
- Audio → word or sentence recognition
- Prompt → sentence production
- A sentence with a blank → correct inflected form

**Implementation policy:** when recognition is strong but recall is weak, the Learning Engine should prioritize recall-oriented exercises instead of repeatedly showing the same flashcard.

### 2. Spaced repetition for long-term retention

Practice should be distributed over time. Each review should occur close enough to the predicted forgetting point to strengthen retention, while avoiding unnecessary repetition.

LinguaBrain uses FSRS as the preferred memory scheduler for learner-specific ReviewUnits. FSRS estimates memory state from versioned review ratings; mission importance, modality choice, and session priority belong to the Adaptive Learning Engine rather than FSRS.

**Implementation policy:** review scheduling remains deterministic and auditable. AI may create review content, but it must not alter scheduling state directly.

### 3. Learning by skill, not by item count

Each knowledge item can have several learning objectives. For example, a German noun may require a learner to:

- recognize its meaning;
- recall it from Persian;
- remember its article and plural;
- recognize it in speech;
- use it in a sentence.

A verb may additionally require conjugation, tense selection, separable-prefix handling, and correct preposition or case usage.

**Implementation policy:** mastery is recorded separately for recognition, recall, listening, production, writing, and relevant grammar usage. A total vocabulary count must never be presented as proof of full competence.

### 4. Context before abstraction

Language is used in situations, not as isolated dictionary entries. New vocabulary, grammar, and expressions should appear in realistic examples aligned with the learner's level, goals, interests, and professional domain.

Examples for `implementieren` should be different for a software engineer and a general beginner. A learner preparing for work in Germany should encounter workplace emails, meetings, and interview situations alongside general language.

**Implementation policy:** AI-generated examples must receive structured context: target language, source language, CEFR level, domain, mission, and relevant learner weaknesses.

### 5. Connected knowledge over isolated cards

New knowledge should reinforce existing knowledge. The platform should use the Knowledge Graph to surface word families, collocations, grammar links, semantic relations, prerequisites, and domain connections.

For example, learning `entscheiden` can naturally lead to `die Entscheidung`, `entscheidend`, and `eine Entscheidung treffen`.

**Implementation policy:** the system should suggest connected follow-up material when it supports the learner's mission and difficulty level. Suggestions remain optional and must not overwhelm the learner.

### 6. Desirable difficulty, not unnecessary frustration

Effective practice is challenging enough to require effort but achievable enough to maintain progress. Difficulty should adapt to evidence, not to a fixed global level alone.

The platform may adapt:

- sentence length and syntax;
- number and quality of distractors;
- audio speed and repetition;
- amount of contextual support;
- ratio of familiar to new vocabulary;
- task modality.

The default principle for generated texts and contextual exercises is approximately **90% familiar vocabulary and 10% controlled novelty**, adjusted for the learner's demonstrated ability.

### 7. Error patterns are learning signals

An incorrect answer is not merely a failed card. It may reveal a reusable weakness, such as German article selection, Dativ after a preposition, verb position, spelling, or listening discrimination.

**Implementation policy:** the system stores error patterns where possible and uses them to select targeted future activities. Feedback should identify the relevant rule or pattern, not only mark the answer wrong.

### 8. Feedback must be timely, specific, and proportionate

Feedback should help the learner correct the next attempt. It should be concise for simple errors and expand only when the learner asks for more detail or repeatedly struggles.

Good feedback includes:

- whether the answer is correct;
- what changed or is missing;
- a short reason;
- a corrected example where useful;
- a next opportunity to apply the correction.

Feedback must not shame the learner or over-explain routine mistakes.

### 9. The learner's daily condition matters

The most effective session depends on the learner's available time, energy, motivation, focus, stress, and preferred mode on that day.

At session start, LinguaBrain may ask for a lightweight daily check-in. The check-in informs session composition but does not replace long-term mastery data.

| Daily state | Preferred learning behavior |
| --- | --- |
| Low energy or little time | Short review, recognition, familiar audio, quick success |
| Typical energy | Balanced review, new material, and guided practice |
| High energy and ample time | Productive skills, longer reading/listening, writing, speaking, and challenge activities |

**Implementation policy:** low energy should reduce cognitive load, not silently lower the learner's long-term standards.

### 10. Consistency is more valuable than intensity

The system should support sustainable habits. A five-minute recovery session is a valid learning session when it maintains review continuity. The product must not punish users for missed days or pressure them into workloads that exceed their stated capacity.

Streaks and progress indicators may motivate, but they must never be the primary definition of success.

### 11. Learner agency and explainability

LinguaBrain should recommend rather than command. Learners can choose a mode, defer an item, adjust goals, correct classifications, and inspect why a recommendation was made.

Example explanation:

> This exercise is suggested because you have upcoming reviews for workplace verbs and recent recall errors with separable verbs.

**Implementation policy:** each generated daily plan should have a concise, evidence-based explanation available to the learner.

### 12. Privacy, ownership, and controlled AI use

Learning history is personal data. The learner owns their data and controls optional cloud AI use. Core learning activities should remain usable offline whenever cached content and local state are available.

AI is an enhancement layer. It generates, analyzes, and explains; owning domain services validate and promote content, while the Learning Engine retains final control over educational decisions.

## Learning progression

The following progression is conceptual. Individual skills may advance at different rates.

```text
Unknown
  ↓
Introduced
  ↓
Recognized
  ↓
Recalled
  ↓
Applied
  ↓
Automatic
```

The target is not merely to identify a translation. The target is automatic, context-appropriate use where required by the learner's mission.

## Consequences for product design

- Cards are one exercise format, not the product's only learning unit.
- The system should favor retrieval practice once basic familiarity exists.
- Exercise selection must depend on skill mastery and error history.
- New content must be contextualized and connected through the Knowledge Graph.
- The Daily Learning State modifies workload and modality.
- AI outputs require validation, provenance, and learner-appropriate constraints.
- Product metrics should include retention, skill growth, mission progress, and sustainable engagement—not only card volume or streak length.

## Open questions

- Which evidence thresholds should move an objective between mastery stages?
- How should speaking and pronunciation be assessed in the MVP versus later releases?
- Which learner controls should override adaptive recommendations?
- What validation sources will be used for grammar facts and lexical data?

## Acceptance criteria

- An introduced item advances only from eligible retrieval evidence, not exposure count alone.
- Recognition and recall are represented by different objective/ReviewUnit contracts.
- A low-energy check-in changes session load while preserving long-term targets and due-memory obligations.
- Feedback identifies the relevant error/component and offers a corrective opportunity.
- Contextual novelty is measured using the operational definition in Document 07 rather than an untestable raw word count.
- The same persisted planning/evidence snapshot produces the same deterministic educational decision.

## Related documents

- `01_Product_Vision.md` — Product goals and target experience.
- `03_Non_Functional_Requirements.md` — Privacy, reliability, and offline constraints.
- `05_Learning_Domain_Model.md` — Objectives, mastery, Digital Twin, and events.
- `06_Knowledge_Graph_Architecture.md` — Connected knowledge design.
- `07_Adaptive_Learning_Engine.md` — Deterministic daily planning and prioritization.

## Revision history

| Version | Date | Description |
| --- | --- | --- |
| 0.2.0 | 2026-07-11 | Cross-document architecture review; resolved domain, validation, scheduling, privacy, and MVP consistency contracts. |
| 0.1.0 | 2026-07-10 | Initial learning philosophy specification. |
