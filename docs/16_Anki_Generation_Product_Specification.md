# Hermes Anki Generation Product Specification

Hermes generates vocabulary cards from a learner request, validates and previews them before persistence, and makes approved content available for in-app study and Anki export. Anki is an export target, not the source of truth.

## User flow

```text
Library → Create Deck → AI Generate Cards → Configure → Generate Preview
        → Edit/Reject → Approve → Study in Hermes / Export to Anki
```

The learner selects source and target languages, CEFR level, topic, card count, card direction, audio, and images. Natural requests such as “Create 20 A1 German words about shopping” resolve to the same structured settings.

AI output is never persisted directly as canonical content. Each proposed card supports editing, regeneration, rejection, and audio playback.

```text
PROPOSED → VALIDATED → ACCEPTED_PRIVATE → EXPORTED
                     ↘ REJECTED
```

## MVP scope

- German, English, and Persian with independent review directions;
- CEFR A1–B1;
- lemma, meaning, part of speech, CEFR, example, and example translation;
- multiple senses for one word;
- audio when available, with a recorded text-only fallback reason;
- duplicate detection, preview, approval, and internal persistence;
- TSV export first, followed by APKG after the exporter is complete.

## Acceptance criteria

1. A learner can approve only selected cards in a batch.
2. Different senses become separate `LexicalSense` records and review identities.
3. Rejected cards never enter study or export.
4. Approved cards remain available offline after restart.
5. Export includes language, direction, examples, level tags, and provenance.

