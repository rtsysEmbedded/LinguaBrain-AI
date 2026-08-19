# Data Model: Hermes Content and Anki Generation

## GenerationRequest

Learner intent: source/target BCP 47 languages, CEFR level, topic or explicit items, count, directions, media preferences, owner scope, and request idempotency key.

## GenerationJob

Durable execution state: job ID, request reference, status, stage attempts, timestamps, provider/model, schema versions, errors, cancellation state, and proposal reference.

## CardProposal

Unapproved output containing lemma, part of speech, one or more senses, examples, grammar, media references, warnings, validation issues, and provenance.

## GeneratedCardBundle

Approved content bundle containing a stable word identity, `LexicalSense` records, ordered `Sentence` records, review directions, `MediaAsset` records, approval state, and provenance.

## Identity

```text
source_language + target_language + lemma + sense_key + part_of_speech + direction
```

Identity must be stable across retries and exports. Separate senses and directions have separate review identities.

## State transitions

```text
QUEUED → RUNNING → WAITING_FOR_APPROVAL → APPROVED
                              ├──────────→ REJECTED
                              ├──────────→ PARTIAL
                              └──────────→ CANCELLED
```

Only approved bundles enter canonical learner storage and study queues.

## MediaAsset requirements

Each asset records kind, locale, checksum, byte/type limits, provider/model, generation time, consent/entitlement context, cache reference, availability, and fallback reason where applicable.

