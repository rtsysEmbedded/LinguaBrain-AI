# Contract: Normalized Anki Package Reader

**Status**: Approved for T005–T008 implementation

## Inputs

- staged read-only APKG URL;
- successful bounded archive inspection;
- exact package SHA-256;
- cancellation token and progress sink;
- versioned import policy.

## Supported envelope

- metadata-absent legacy 1: `collection.anki2`, schema 11;
- metadata-absent legacy 2: `collection.anki21`, schema 11;
- metadata-declared versions 1/2 with matching schema-11 entry;
- metadata version 3: `collection.anki21b`, Zstandard-decoded schema 18.

Unknown metadata versions, mismatched entries, unsupported schemas, malformed protobuf, or unbounded decode are errors and produce no normalized package.

## Resource policy v1

| Resource | Limit |
| --- | ---: |
| APKG file | 512 MiB |
| Outer ZIP members | 10,000 |
| Outer ZIP expanded aggregate | 1 GiB |
| Outer ZIP individual member | 128 MiB |
| Central directory | 32 MiB |
| Outer ZIP compression ratio | 200:1 |
| Decoded modern collection | 512 MiB |
| Decoded media manifest | 16 MiB |
| Manifest media entries | 10,000 |
| Decoded individual media | 128 MiB |
| Decoded media aggregate | 1 GiB |
| Cards read | 100,000 |

Inner Zstandard limits are enforced while streaming and do not rely on outer ZIP sizes. If the selected decoder supports a window-memory limit, v1 caps it at 128 MiB. A dependency unable to enforce streaming output and memory/cancellation requirements is not conforming.

Numeric limits are product policy, not claims about Anki's maximums. A limit failure is recoverable and distinct from corruption.

## Output

```text
NormalizedAnkiPackage
  metadata
  decks[]
  notetypes[]
    fields[] ordered by ord
    templates[] ordered by ord
  notes[]
    fieldValues[] aligned with notetype fields
    tags[]
  cards[]
  media[]
  warnings[]
  unsupportedFeatures[]
```

All output values are immutable, `Sendable`, database-independent, and preserve their `SourceRecordIdentity` components. Raw SQL rows, SQLite handles, temporary URLs, and decoder buffers do not cross this boundary.

## Validation order

1. Validate outer ZIP and duplicate/path/compression policy.
2. Decode authoritative `meta` or apply the documented absent-meta legacy fallback.
3. Select exactly the collection required by metadata.
4. Stream-decode modern payload within policy limits.
5. Verify SQLite signature, read-only open, integrity, `col.ver`, required tables, and required columns.
6. Read normalized records with bounded counts and lengths.
7. Decode and validate media manifest.
8. Validate every referenced numbered media payload, decoded size, and SHA-1 before ownership transfer.
9. Return preview-ready normalized values; perform no learner-store write.

## Reader protocol

```swift
protocol NormalizedAnkiPackageReading: Sendable {
    func read(
        inspectedPackage: InspectedAnkiPackage,
        policy: AnkiImportPolicy,
        progress: @Sendable (ImportProgress) -> Void
    ) async throws -> NormalizedAnkiPackage
}
```

Separate schema-11 and schema-18 adapters implement a shared normalized output. The UI and reconciliation service cannot query Anki SQLite directly.

## Temporary-file ownership

- All decoded files live below one importer-created per-operation directory.
- Filenames are generated internally and never derived as paths from archive values.
- Handles are read-only after decode.
- Cancellation, error, or completion removes the operation directory after required data/media transfer.
- Cleanup failure is logged without converting a rolled-back import into success.

## Decoder dependencies

- **Zstandard**: official Zstandard 1.5.7 decoder source, integrated as a decoder-only `CZstd` SwiftPM C target under the BSD license; retain upstream license/notices and exclude compression/export code.
- **Protocol Buffers**: Apple SwiftProtobuf 1.38.1 with clean LinguaBrain-owned declarations for only the pinned metadata/media wire fields; do not copy generated or runtime code from Anki.

Before T006 merges, both require resolved-version tracking, license attribution, Apple-platform build evidence, streaming-limit tests, cancellation tests, and a vulnerability-update owner. This contract prevents either dependency from leaking into domain/application interfaces.

## Error categories

- `unsupportedVersion`
- `unsupportedSchema`
- `resourceLimitExceeded(resource, limit)`
- `corruptMetadata`
- `corruptCompressedPayload`
- `corruptSQLite`
- `missingRequiredRecord`
- `unsafeMediaName`
- `mediaIntegrityMismatch`
- `cancelled`
- `ioFailure`

Error details may identify safe archive member names but must not expose learner text in telemetry.
