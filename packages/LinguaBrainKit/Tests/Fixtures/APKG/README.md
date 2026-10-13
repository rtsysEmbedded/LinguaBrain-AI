# APKG Export Test Fixtures

## Provenance

These test fixtures simulate approved Hermes card bundles with German/Persian text and media assets for APKG export testing per quickstart.md requirements.

## Structure

- `approved-cards.json` - Serialized approved card bundles with text content, RTL/LTR support, and media references
- `media/` - Sample media files simulating owned assets (audio/image)

## Standardized Anki Compatibility Fixture (T035)

The following fixture enables round-trip verification testing:

### `standard-anki-sample.json`

A sanitized standard-Anki compatibility fixture with:
- Simplified note/card structure compliant with anki21 schema
- Basic front/back fields
- No custom scheduling fields (FSRS/mastery)
- Media entries with valid checksums

### Verification Procedure

1. Load `standard-anki-sample.json` as source data
2. Generate APKG using the export pipeline with fresh Anki scheduling
3. Import generated APKG into a clean Anki environment
4. Export as TSV from Anki
5. Compare normalized fields (text, tags, media references) for equivalence

## Usage

Feed these fixtures into APKG export tests to verify:
- Valid collection.anki21 SQLite generation
- RTL/LTR Unicode preservation
- Media checksum computation
- Manifest consistency
- Round-trip equivalence for text, senses, examples, directions, Unicode/RTL/LTR, media, tags, and provenance

## Round-Trip Evidence

`LinguaBrainAnkiExportTests/AnkiExportEvidenceTests.swift` validates the round-trip verification procedures of T036. `MediaFixturePackagingTests.swift` packages `media/test-audio.mp3` (a 0.3 s MPEG audio file) and `media/test-image.jpg` (an 8 × 8 JPEG) and checks their SHA-256, size, and MIME type.