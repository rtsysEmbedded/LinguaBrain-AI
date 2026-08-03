---
title: MVP Card Inventory and Interaction Requirements
document_id: LB-UX-CARDS-001
version: 0.1.0
status: Review Draft
last_updated: 2026-08-03
---

# MVP Card Inventory and Interaction Requirements

## Purpose

This supporting specification defines the minimum card and card-like learning
surfaces that must be reviewed before LinguaBrain's visual design system is
finalized. It validates information hierarchy, learning intent, interaction,
feedback, accessibility, and right-to-left/left-to-right behavior. It does not
approve final colors, typography, illustration, or motion.

## Shared contract

Every learning card must:

- have one primary learning objective;
- distinguish Persian right-to-left content from German left-to-right content;
- present a clear prompt before revealing an answer;
- never advance mastery from exposure or reveal alone;
- provide an accessible label for every icon-only control;
- support Dynamic Type without clipping essential content;
- expose provenance and validation state when AI-generated content becomes real;
- preserve the learner's answer and evidence as a LearningEvent in production;
- work without network access when its required content is cached;
- avoid color as the only indication of state or correctness.

## Minimum inventory

| ID | Surface | Primary objective | Required information | Required interaction |
| --- | --- | --- | --- | --- |
| CARD-01 | General word card | Understand a lexical sense in context | lemma, Persian meaning, POS, CEFR, pronunciation action, example and translation | play pronunciation; inspect details |
| CARD-02 | Noun card | Learn noun form and grammatical identity | lemma with article, gender/article, plural, meaning, common usage | play pronunciation; inspect forms |
| CARD-03 | Verb card | Learn verb identity and core forms | infinitive, meaning, Präsens example, Präteritum, Perfekt, separability/auxiliary when relevant | play pronunciation; inspect forms |
| CARD-04 | Recognition review | Recognize German meaning | German prompt, task instruction, answer choices or reveal control | submit one answer before feedback |
| CARD-05 | Reverse translation | Recall German from Persian | Persian prompt, expected German lemma/sense, optional hint | type/speak answer or explicitly reveal |
| CARD-06 | Cloze | Select or produce a word in context | sentence, blank, target objective, plausible distractors | choose/type answer; submit |
| CARD-07 | Listening | Recognize spoken language | audio control, replay state, speed, task, response controls | play/replay; answer without transcript first |
| CARD-08 | Result and feedback | Understand and correct an error | outcome, component-specific explanation, correct answer, learner answer | retry or continue |
| CARD-09 | Daily plan | Understand today's adaptive session | available time, activity sequence, duration, rationale/priority | start or adjust session |
| CARD-10 | Mastery status | Understand skill-specific competence | item/objective identity, recognition, recall, listening and production estimates | inspect evidence/history; start targeted practice |

## State requirements

Review and exercise cards require explicit states: `ready`, `answering`,
`submitted-correct`, `submitted-partial`, `submitted-incorrect`, `retry`, and
`completed`. Content cards require `loading`, `available`, `unvalidated`,
`learner-edited`, and `unavailable-offline` states where applicable.

## Evaluation checklist

For each prototype card, reviewers must answer:

1. Is the learning task clear within three seconds?
2. Is the German/Persian reading direction unambiguous?
3. Is the essential answer hidden until the learner responds or requests reveal?
4. Is the amount of information appropriate for the task?
5. Does feedback identify the specific component that was correct or incorrect?
6. Can the learner recover from an error without leaving the flow?
7. Does the card remain usable with large text, VoiceOver, keyboard, and reduced motion?
8. Is the same semantic contract feasible on iPhone, iPad, and Mac?

## Prototype location

The executable mock gallery is available from **Library → MVP Card Gallery** in
the native SwiftUI prototype. It uses static data and must not be interpreted as
production scheduling, scoring, persistence, or AI behavior.

## Approval gate

Final visual-system work may begin only after CARD-01 through CARD-10 have been
reviewed for content completeness and interaction clarity. Approval of this
inventory does not complete the M1 production walking skeleton.
