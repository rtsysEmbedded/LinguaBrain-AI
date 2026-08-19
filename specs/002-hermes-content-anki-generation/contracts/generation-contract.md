# Generation Contract v1

## Request

`POST`-equivalent application command with `schema_version`, `request_id`, source/target languages, level, topic/items, count, directions, and media preferences.

## Response

The provider returns a proposal with `proposal_id`, `schema_version`, cards, warnings, and provenance. Each card has lemma, part of speech, senses, examples, optional grammar, and optional media descriptors.

## Invariants

- JSON must validate against the versioned schema.
- Required language fields use BCP 47 tags.
- Provider output is never canonical by itself.
- Validation and approval occur in the Hermes application boundary.
- Retries use the request idempotency key.
- Credentials and private prompts are excluded from logs and response persistence.

## Error classes

`schema_error`, `provider_error`, `quota_error`, `validation_error`, `duplicate`, `media_error`, and `cancelled`.

