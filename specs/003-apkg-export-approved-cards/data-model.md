# Data Model: APKG Export

## ExportSelection

Represents learner-approved export scope: selected card identities, source groups (`hermes_generated` or `imported`), language directions, and export options.

## AnkiNoteRecord

Normalized note: deterministic note ID, model ID, deck reference, ordered fields, tags, source/sense identity, and provenance.

## AnkiCardRecord

Normalized card: deterministic card ID, note ID, deck ID, template/ordinal, due/scheduling mapping, and direction.

## AnkiModelRecord

Anki note model definition containing model ID, name, fields, templates, CSS, and format version.

## MediaExportRecord

Source media ID, numeric Anki media index, local staging path, checksum, byte size, MIME type, ownership, and availability/fallback state.

## ExportManifest

Export ID, feature/schema versions, source groups, selected identities, note/card counts, media records, checksums, scheduling policy, and validation report.

## APKGPackage

Final output URL, package checksum, collection schema, entry list, manifest, and integrity state.

## State transitions

```text
SELECTED → STAGED → VALIDATED → PACKAGED → DELIVERED
              ├────→ FAILED
              └────→ CANCELLED
```

No partial package is delivered. Temporary files are deleted after success, failure, or cancellation according to the repository retention policy.

