# APKG Contract v1

## Required entries

```text
collection.anki21
media
0, 1, 2, ...        # media files referenced by the media map
```

The collection must contain the selected notes, cards, models, templates, decks, tags, and supported scheduling fields. No unsupported template JavaScript or external URLs may be executed or trusted.

## Package invariants

- All paths are relative and normalized.
- No duplicate entry names, traversal, absolute paths, symlinks, or encrypted entries.
- Collection and media are bounded by configured size/count limits.
- Media indexes resolve to existing files and matching checksums.
- The destination is written atomically only after validation.
- The package can be inspected without Hermes or network access.

## Failure classes

`no_approved_cards`, `invalid_selection`, `missing_media`, `checksum_mismatch`, `unsupported_schema`, `sqlite_error`, `zip_error`, `limit_exceeded`, `cancelled`, and `round_trip_mismatch`.

