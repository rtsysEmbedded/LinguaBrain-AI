# Hermes Anki Generation Technical Contract

```text
GenerationRequest → Orchestrator → Provider Adapter → Structured Proposal
                  → Validators → Media → Duplicate Check → Approval
                  → CardBundle / Exporter
```

Providers must not directly modify the database, scheduler, mastery state, or Knowledge Graph.

## Request

```json
{
  "source_language": "de",
  "target_language": "fa",
  "level": "A1",
  "topic": "shopping",
  "items": ["kaufen", "der Laden"],
  "count": 20,
  "directions": ["recognition", "recall"],
  "audio": true,
  "image": false,
  "owner_scope": "USER_PRIVATE"
}
```

## Proposal requirements

Each proposal contains a stable `proposal_id`, source/target languages, level, cards, senses, examples, grammar data, media metadata, and versioned provenance including provider, model, prompt version, and validator version.

The validator runs outside the model and checks schema, BCP 47 language tags, CEFR, required fields, example length, non-empty translations, safe text, part-of-speech consistency, media checksum, and provenance.

## Identity and duplicates

```text
source_language + target_language + lemma + sense_key + part_of_speech + direction
```

The lemma alone must never determine duplication. Errors are classified as `schema_error`, `provider_error`, `quota_error`, `validation_error`, `duplicate`, `media_error`, and `cancelled`. Retries require an idempotency key and are limited to transient errors.

Provider credentials are stored only in Keychain. Prompts, credentials, and private learner data must not appear in logs or exports. Cloud consent and the selected provider/model must be shown before the first request.

