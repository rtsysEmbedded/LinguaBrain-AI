# Research: Modern Anki Package Compatibility

**Feature**: `001-anki-core-modern-import`

**Task**: T003

**Status**: Complete research baseline

**Date**: 2026-08-17

**Upstream baseline**: Ankitects/Anki `967aa0d578fc75181e292e95326f9b58698da25c`

## 1. Purpose

This document pins the modern Anki package envelope that LinguaBrain may implement in T005–T008. It records upstream evidence, supported and rejected variants, security constraints, schema implications, and fixture provenance. It does not select a Swift Zstandard or Protocol Buffers dependency and does not implement a decoder.

The primary conclusion is:

> `collection.anki21b` is not a SQLite file merely stored under a new name. In a latest-format package it is a Zstandard-compressed SQLite schema-18 collection inside an outer ZIP archive.

The current prototype correctly rejects this format. It must not remove that rejection until the two-layer decoding, validation, and schema-18 reader are implemented and covered by hostile fixtures.

## 2. Research method and authority

The format is derived from the official Anki source and manual rather than third-party reverse-engineering. The source was inspected at the pinned commit above so later upstream changes cannot silently redefine this contract.

Anki's architecture documentation explicitly states that its protobuf definitions are not a public API. LinguaBrain therefore treats the inspected messages as a pinned compatibility contract, rejects unknown package versions, and must not infer compatibility from field names or an unpinned generated client.

## 3. Package envelope

### 3.1 Outer container

The APKG remains a ZIP archive. The existing bounded central-directory preflight remains the first trust boundary and must run before any entry is materialized.

Official latest-format exports use stored ZIP entries for `meta`, `collection.anki21b`, `media`, and numbered media payloads because the relevant payloads are compressed internally with Zstandard. A modern export also contains a dummy `collection.anki2` for older clients. That dummy must never win collection selection when a valid `meta` declares the latest format.

### 3.2 Metadata and version selection

`meta` is an encoded `PackageMetadata` protobuf containing enum field 1:

| Value | Upstream name | Expected collection | Collection schema | Inner compression | Media manifest |
| ---: | --- | --- | ---: | --- | --- |
| 0 | `VERSION_UNKNOWN` | none | none | none | none |
| 1 | `VERSION_LEGACY_1` | `collection.anki2` | 11 | none | JSON map |
| 2 | `VERSION_LEGACY_2` | `collection.anki21` | 11 | none | JSON map |
| 3 | `VERSION_LATEST` | `collection.anki21b` | 18 | Zstandard | protobuf |

Official Anki falls back only when `meta` is absent: presence of `collection.anki21` selects legacy 2; otherwise legacy 1 is assumed. LinguaBrain will preserve legacy compatibility but use stricter validation:

- A present, decodable `meta` is authoritative.
- Version 0, an unknown enum value, or an unsupported future version is rejected as `packageTooNew`/unsupported; it does not fall back to a dummy legacy collection.
- The collection entry required by the declared version must exist exactly once.
- Conflicting collection entries may coexist for compatibility, but only the metadata-selected entry is read.
- Duplicate `meta`, selected collection, `media`, or numbered media entry names are rejected by archive preflight.
- A malformed `meta` is corruption, not a reason to guess a version.

### 3.3 Collection payload

For version 3, the bytes of `collection.anki21b` form a Zstandard stream. Successful ZIP extraction alone does not expose SQLite. The reader must:

1. stream-decode the selected entry into an importer-owned temporary file;
2. enforce a decoded-byte limit while streaming;
3. reject decoder errors, truncation, excessive output, and invalid trailing content according to the chosen decoder contract;
4. verify the decoded SQLite header;
5. open the database read-only with URI/flags that prohibit creation and writes;
6. run structural validation and inspect `col.ver` before queries;
7. accept only an explicitly supported schema version.

The outer ZIP's expanded-size and compression-ratio limits do not bound inner Zstandard expansion. Modern support therefore requires a second independent decompression budget.

### 3.4 Media manifest and payloads

For latest packages, `media` is a Zstandard-compressed protobuf `MediaEntries` message. Each repeated entry contains:

- `name` (field 1, string),
- `size` (field 2, unsigned 32-bit integer),
- `sha1` (field 3, bytes), and
- optional legacy ZIP filename (field 255; not emitted by current exports).

The ordinal position of each manifest entry maps to the outer ZIP member named `0`, `1`, `2`, and so on. Each modern numbered payload is itself Zstandard-compressed. `size` and SHA-1 describe the decoded media, not the stored Zstandard bytes.

LinguaBrain must validate normalized filenames, prohibit separators/traversal and unsafe names, require the numbered member, stream-decode within per-file and aggregate budgets, verify decoded size and SHA-1, and materialize only into importer-owned storage. SHA-1 is an upstream integrity field, not a security identity; LinguaBrain may additionally record SHA-256 for its own provenance and deduplication.

## 4. Schema-18 implications

Modern packages use collection schema 18. Notes, cards, and review logs retain recognizable relational tables, but schema 14/15 moved important data out of schema-11 JSON columns:

- deck configurations, preferences, and tags have dedicated tables;
- notetypes, fields, and templates have dedicated tables;
- decks have a dedicated table;
- multiple configuration columns are protobuf blobs rather than schema-11 JSON;
- schema 17 changes the tag table; schema 18 changes graves and records `col.ver = 18`.

Consequences for T007:

- The existing schema-11 reader cannot be reused by merely changing the filename.
- A normalized collection-reader protocol must hide legacy JSON versus modern relational/protobuf storage.
- Field ordering comes from `fields.ord`; template ordering comes from `templates.ord`.
- Deck, notetype, template, and configuration protobuf payloads require pinned decoding or a deliberately limited query contract.
- LinguaBrain must not run Anki migrations against the source. It reads the exported schema as-is and maps into LinguaBrain-owned records.
- Schema versions other than the explicitly approved legacy 11 and modern 18 are rejected until separately researched and tested.

## 5. Compatibility matrix

| Package condition | Current behavior | Target behavior | Rationale |
| --- | --- | --- | --- |
| No `meta`, `collection.anki2`, schema 11 | Supported | Supported | Official legacy-1 fallback. |
| No `meta`, `collection.anki21`, schema 11 | Supported | Supported | Official legacy-2 fallback. |
| `meta` version 1 + expected schema-11 entry | Not guaranteed | Supported after metadata parser | Valid pinned enum; useful for defensive compatibility. |
| `meta` version 2 + expected schema-11 entry | Not guaranteed | Supported after metadata parser | Valid pinned enum; useful for defensive compatibility. |
| `meta` version 3 + `collection.anki21b`, schema 18 | Explicitly rejected | Target supported | Primary modern format. |
| Version 3 with dummy `collection.anki2` | Explicitly rejected as modern | Read only `collection.anki21b` | Dummy exists for old clients and is not learner content. |
| Missing/malformed `meta` with only `.anki21b` | Rejected | Rejected | No safe version/compression contract. |
| Unknown/future metadata version | Rejected | Rejected as too new | Protobuf is not a public stable API. |
| Metadata/required-entry mismatch | Rejected | Rejected as corrupt | Prevents ambiguous downgrade/fallback. |
| Selected DB schema other than 11 or 18 | Rejected | Rejected as unsupported | No opportunistic parsing of unknown schemas. |
| Truncated/invalid/excessive Zstandard output | Rejected | Rejected as corrupt/resource limit | Inner decompression is an independent trust boundary. |
| Invalid media name, size, SHA-1, or numbered member | Media unsupported | Reject affected import before commit | Media must not partially corrupt an atomic import. |

## 6. Resource and security constraints

The prototype already preflights the outer ZIP for traversal, symlinks, encryption, duplicates, ZIP64, suspicious compression ratios, entry count, entry size, and aggregate expansion. Modern decoding adds these mandatory controls:

- separate decoded limits for the collection, manifest, each media file, and all decoded media;
- streaming decode to importer-owned temporary files, never unbounded `Data` buffers;
- cancellation and progress reporting for large packages;
- no extraction into a user-selected directory;
- SQLite header, read-only opening, `col.ver`, required-table/column, and integrity validation;
- bounded protobuf message size and repeated-entry count;
- exact media ordinal/name mapping, normalized safe names, decoded-size equality, and checksum equality;
- atomic cleanup on cancellation or any validation failure;
- no database or media mutation before preview confirmation and the final LinguaBrain transaction.

T004 must approve numeric limits. Current outer-package prototype values are evidence, not automatic inner-Zstandard limits; copying them without memory/disk and representative-deck tests would create a false security guarantee.

## 7. Decoder dependency questions reserved for T004

Apple's native Compression framework does not provide Zstandard as one of its documented algorithms. Modern support therefore needs a reviewed decoder dependency or a separately isolated native implementation. T004 must record:

- exact dependency and pinned version;
- license compatibility and attribution;
- iOS, iPadOS, and macOS build support;
- streaming API, decoded-size and window-limit controls;
- concurrency/cancellation behavior;
- maintenance and vulnerability-update process;
- fallback behavior when the capability is unavailable.

The same decision applies to Protocol Buffers: use a pinned SwiftProtobuf-based contract or a minimal audited decoder for only the required wire fields. Generated definitions copied from Anki cannot be presented as a stable public API, and upstream AGPL source must not be copied into the MIT repository without a license review.

## 8. Fixture provenance policy

No personal APKG, downloaded public deck, copyrighted course deck, or opaque third-party fixture may be committed.

Every golden fixture must be generated from a synthetic German–Persian collection and accompanied by a manifest containing:

- fixture ID and purpose;
- exact Anki application version/build and platform;
- export options (scheduling, deck configuration, media, legacy mode);
- upstream format baseline commit used by the reader contract;
- generation steps or repository script;
- expected deck/model/note/card/template/tag/media counts;
- SHA-256 of the complete APKG and each decoded canonical payload;
- assertion that names, text, media, and history contain no learner/private data;
- license/ownership statement for every media asset;
- expected accept/reject result and stable error category.

Required T005 fixtures:

1. legacy `collection.anki2` text-only baseline;
2. legacy `collection.anki21` baseline;
3. latest schema-18 text-only package;
4. latest package with synthetic image and short synthetic audio;
5. latest package including scheduling and deck configuration;
6. multiple note types, reordered fields, multiple templates, tags, sibling/nested decks, and Unicode/RTL content;
7. malformed, missing, unknown-version, and metadata/entry-mismatch cases;
8. truncated Zstandard collection, invalid SQLite header, failed integrity check, and unsupported schema;
9. oversized collection/manifest/media and high-expansion streams;
10. unsafe/duplicate media names, missing ordinal, incorrect decoded size, and incorrect checksum.

Small corrupt fixtures should be derived deterministically from owned valid fixtures so their provenance remains reproducible.

## 9. Implementation consequences

T006–T008 should introduce these separable boundaries:

```text
APKGInspector
  -> PackageMetadataReader
  -> BoundedPayloadDecoder
  -> ReadOnlyAnkiCollectionReader (schema 11 | schema 18)
  -> MediaManifestReader
  -> NormalizedAnkiPackage
```

- `APKGInspector` owns outer-ZIP policy and version-selected entry discovery.
- `PackageMetadataReader` decodes only the pinned metadata contract.
- `BoundedPayloadDecoder` streams and accounts for inner decompression.
- Version-specific readers map into one normalized, database-independent representation.
- The media reader validates all manifest/payload relationships before ownership transfer.
- No layer writes learner records; reconciliation and commit remain later application services.

## 10. Decisions for T004

T004 must turn this research into approved contracts for:

1. Zstandard and protobuf implementation choices;
2. exact decoded byte/count/window limits;
3. schema-18 tables, protobuf fields, and unsupported-feature behavior;
4. package/source identity and fixture identity;
5. all-or-nothing versus explicit partial behavior for unsupported templates/media;
6. normalized deck/model/note/card/template/tag/media records;
7. error taxonomy shown in preview and import reports;
8. cleanup, cancellation, and temporary-file ownership.

## 11. Conclusion

Supporting official latest APKG exports is feasible without making Anki code part of the runtime, but it is a new reader path rather than a small extension of the legacy reader. The safe minimum is metadata-driven selection, bounded streaming Zstandard decoding, a schema-18 normalized reader, validated protobuf media mapping, owned reproducible fixtures, and explicit rejection of future variants.

Until those pieces land together, retaining the current user-visible modern-format rejection is the correct behavior.

## 12. Primary references

- [Anki package metadata implementation](https://github.com/ankitects/anki/blob/967aa0d578fc75181e292e95326f9b58698da25c/rslib/src/import_export/package/meta.rs)
- [Anki package exporter](https://github.com/ankitects/anki/blob/967aa0d578fc75181e292e95326f9b58698da25c/rslib/src/import_export/package/colpkg/export.rs)
- [Anki media package implementation](https://github.com/ankitects/anki/blob/967aa0d578fc75181e292e95326f9b58698da25c/rslib/src/import_export/package/media.rs)
- [Anki import/export protobuf definitions](https://github.com/ankitects/anki/blob/967aa0d578fc75181e292e95326f9b58698da25c/proto/anki/import_export.proto)
- [Anki schema-11 definition](https://github.com/ankitects/anki/blob/967aa0d578fc75181e292e95326f9b58698da25c/rslib/src/storage/schema11.sql)
- [Anki schema upgrades](https://github.com/ankitects/anki/tree/967aa0d578fc75181e292e95326f9b58698da25c/rslib/src/storage/upgrades)
- [Anki architecture and protobuf stability statement](https://github.com/ankitects/anki/blob/967aa0d578fc75181e292e95326f9b58698da25c/docs/architecture.md)
- [Anki manual: exporting](https://docs.ankiweb.net/exporting.html)
