# Export Contract v1

## TSV

The first export format contains stable columns for source text, target text, sense key, part of speech, examples, example translations, source/target languages, direction, CEFR level, tags, card source, and provenance identifier. Fields must preserve Unicode and RTL/LTR content.

## APKG

APKG export is gated on valid collection data, deterministic note/card identity, templates, tags, owned media, safe ZIP packaging, and clean-fixture round-trip verification. Unsupported media or template features must be reported before export.

## Selection

Export operates only on learner-selected approved cards. Imported and Hermes-generated cards are shown as separate source groups.

