# Data Model: Anki Import, Lexical Senses, and Reconciliation

**Feature**: `001-anki-core-modern-import`

**Task**: T004

**Status**: Approved contract baseline

**Date**: 2026-08-17

## 1. Design rules

1. A spelling is not a meaning. `entlassen` may produce independent work, medical, legal, or general senses.
2. An Anki source identity and a LinguaBrain learning identity are different identities.
3. Source content, learner overrides, and review evidence have separate ownership.
4. Re-import may update source-owned content but must never reset or replace learner-owned review state.
5. Ambiguous identity or destructive change becomes a reported conflict; it is never guessed silently.
6. Imported data is proposed and reconciled before one atomic commit.

## 2. Identity hierarchy

```text
ImportSource (stable lineage chosen/confirmed by learner)
  -> ImportPackageRevision (one immutable APKG byte revision)
  -> SourceRecordIdentity (source + Anki entity type + Anki ID)
  -> ImportedCard / SourceContentSnapshot
  -> LexicalSense (meaning/domain-specific learning identity)
  -> ReviewUnit (recognition, reverse translation, ...)
  -> FSRSState + immutable ReviewEvent
```

### 2.1 ImportSource

A stable LinguaBrain-owned lineage for a deck/package family.

| Field | Type | Rule |
| --- | --- | --- |
| `id` | UUID | Generated once; primary namespace for all source record identities. |
| `displayName` | String | Learner-editable; never identity-bearing. |
| `originKind` | Enum | `ankiPackage`, with future kinds allowed. |
| `createdAt` | Instant | Immutable. |
| `lastImportedAt` | Instant | Updated only after successful commit. |

An exact package hash links automatically to its existing source. An updated package may be suggested as the same lineage using source-ID overlap, but that suggestion requires learner confirmation before reconciliation. Filename alone is never lineage identity.

### 2.2 ImportPackageRevision

An immutable record of one inspected APKG.

| Field | Type | Rule |
| --- | --- | --- |
| `id` | UUID | Internal identity. |
| `importSourceID` | UUID | Stable lineage. |
| `packageSHA256` | 32 bytes | Unique exact-byte fingerprint. |
| `formatVersion` | Enum | `legacy1`, `legacy2`, `latest3`. |
| `collectionSchema` | Integer | Initially 11 or 18 only. |
| `sourceFileName` | String | Display/audit metadata only. |
| `inspectionPolicyVersion` | String | Reproduces compatibility result. |
| `importedAt` | Instant | Set at committed import. |
| `reportID` | UUID | Links the immutable import report. |

### 2.3 SourceRecordIdentity

```text
(importSourceID, entityKind, externalID)
```

`entityKind` is one of `deck`, `notetype`, `field`, `template`, `note`, `card`, `media`. `externalID` is the stable Anki integer ID where one exists; composite ordinal IDs are used for fields/templates, and validated manifest identity is used for media.

This tuple is the authoritative re-import match. A raw Anki ID is not globally trusted without the `ImportSource` namespace.

## 3. Normalized import entities

The normalized reader returns immutable values and performs no learner-store writes.

### NormalizedAnkiPackage

- package metadata and exact fingerprint;
- decks;
- notetypes with ordered fields and templates;
- notes with ordered field values and tags;
- cards with deck, note, template ordinal, and scheduling source metadata;
- validated media descriptors;
- warnings and unsupported-feature descriptors.

The complete contract is defined in [normalized-reader.md](contracts/normalized-reader.md).

## 4. LexicalSense

`LexicalSense` is the learning identity for one meaning in one relevant context.

| Field | Type | Ownership |
| --- | --- | --- |
| `id` | UUID | LinguaBrain, immutable |
| `languageTag` | BCP 47 | LinguaBrain, immutable after creation |
| `lemma` | String | source value plus optional learner override |
| `partOfSpeech` | String? | source value plus optional learner override |
| `meaning` | String | source value plus optional learner override |
| `domain` | String? | source value plus optional learner override |
| `usageContext` | String? | source value plus optional learner override |
| `register` | String? | source value plus optional learner override |
| `senseKeyVersion` | String | normalization contract version |
| `createdAt` | Instant | LinguaBrain, immutable |

### 4.1 Sense candidate key

The following versioned key is used only to propose semantic matches:

```text
SHA256(
  languageTag + U+001F +
  normalizedLemma + U+001F +
  normalizedPartOfSpeech + U+001F +
  normalizedMeaning + U+001F +
  normalizedDomain + U+001F +
  normalizedUsageContext
)
```

It is not a database uniqueness constraint. Different senses may share the same lemma and even the same short translation. An authoritative source mapping wins for re-import; otherwise uncertain semantic equivalence is offered as a link/merge decision rather than applied automatically.

### 4.2 Required example

These records must coexist:

| Lemma | Part of speech | Persian meaning | Domain | Result |
| --- | --- | --- | --- | --- |
| `entlassen` | verb | اخراج کردن | work | independent sense A |
| `entlassen` | verb | مرخص کردن | medicine | independent sense B |
| `entlassen` | verb | آزاد کردن | legal/general | independent sense C |

Each sense has its own cards and independent recognition/reverse `ReviewUnit` states.

## 5. ImportedCard and source mapping

`ImportedCard` represents the supported semantics of one Anki card/template rendering and links to one or more learning items without becoming the learning identity itself.

| Field | Purpose |
| --- | --- |
| `id` | LinguaBrain UUID |
| `sourceRecordIdentity` | Authoritative re-import identity for the Anki card |
| `noteSourceIdentity` | Stable source note link |
| `templateOrdinal` | Source card-template relation |
| `deckID` | LinguaBrain deck relation |
| `lexicalSenseID` | Meaning-specific learning relation when mapping is supported |
| `sourceSnapshotID` | Last accepted source-owned content |
| `isRetiredAtSource` | Soft source deletion state; never deletes review evidence |

A single Anki note may generate multiple imported cards. Multiple cards may intentionally target one sense, while a multi-sense note must be split into explicit sense proposals or marked for learner resolution rather than collapsed by spelling.

## 6. Field ownership and revisions

### SourceContentSnapshot

An immutable snapshot of imported source-owned fields with:

- source record identity;
- canonical serialized content hash;
- field values and provenance;
- package revision ID;
- accepted timestamp.

### LearnerFieldOverride

An optional learner-owned value for one entity/field. It records the source snapshot on which editing began. Effective display is:

```text
learner override ?? latest source value
```

Re-import may update the underlying source snapshot without erasing the override. If the same source field changed since the override's base, the report records `concurrentFieldChange`; the learner chooses keep override, accept source, or manually edit.

## 7. Review ownership

`ReviewUnit`, `FSRSState`, and `ReviewEvent` are learner-owned and keyed by stable LinguaBrain UUIDs, never by mutable spelling, meaning, filename, or raw Anki ID.

Import and re-import are prohibited from:

- recreating a `ReviewUnit` when its linked sense/card is matched;
- modifying stability, difficulty, due date, phase, lapses, repetitions, or algorithm version;
- deleting review events;
- combining recognition and reverse-translation state;
- marking mastery from source scheduling metadata.

Source scheduling may be retained as provenance or used only by a separately approved migration policy.

## 8. Reconciliation result model

Every proposed operation has exactly one result:

| Result | Meaning |
| --- | --- |
| `inserted` | No authoritative source mapping or approved semantic link exists; create new records. |
| `updated` | Same source identity, changed source snapshot, safe non-destructive update. |
| `skippedUnchanged` | Same source identity and canonical source content hash. |
| `linkedExisting` | Learner explicitly approved linking a new source identity to an existing sense. |
| `conflict` | Identity/content/deletion is ambiguous or would overwrite learner-owned data. |
| `rejected` | Invalid, unsafe, or unsupported record cannot enter the transaction. |

The UI may aggregate `skippedUnchanged` under “skipped,” but reports retain the precise code.

## 9. Conflict kinds

| Conflict | Trigger | Safe default |
| --- | --- | --- |
| `ambiguousLineage` | Updated package could belong to multiple import sources. | Import as new source or ask learner; never guess. |
| `ambiguousSense` | New source record resembles multiple senses. | Create separate sense or ask learner; never merge automatically. |
| `semanticCollision` | Same candidate key points to substantively different context/content. | Preserve both and request resolution. |
| `concurrentFieldChange` | Source and learner changed the same field since base snapshot. | Keep learner override effective; retain new source underneath. |
| `sourceDeletionWithLearningState` | Source removed a card/sense with learner reviews or edits. | Retire source link; preserve sense/reviews. |
| `sourceIdentityReused` | Same source identity changes entity kind or implausibly changes semantic identity. | Reject operation and flag corrupt/reused identity. |
| `duplicateExternalIdentity` | Package contains duplicate source identity. | Reject package before commit. |

The full decision table is defined in [reconciliation.md](contracts/reconciliation.md).

## 10. Package removal

Removing an imported package removes source ownership only after confirmation. A record may be physically deleted only if it is exclusively owned by that source and has no learner override, no review evidence, no other source link, and no dependent learner-created content. Otherwise it is detached or retired and learner data remains.

The original APKG file is never deleted by LinguaBrain.

## 11. Transaction boundary

The confirmed import transaction atomically commits:

- import source/revision;
- normalized source mappings and snapshots;
- accepted senses/cards/decks/templates/tags;
- validated media ownership;
- reconciliation decisions/conflicts;
- immutable import report.

Any failure rolls back all learner-visible changes. Temporary decoded files and unowned media are cleaned independently after rollback.

## 12. Invariants

1. `(importSourceID, entityKind, externalID)` is unique.
2. `packageSHA256` uniquely identifies an exact package revision.
3. `LexicalSense.id` is independent from lemma and translation text.
4. A semantic candidate key is non-authoritative and non-unique.
5. Review state has exactly one stable `ReviewUnit` owner and cannot be imported over.
6. Learner overrides survive source updates and package removal.
7. A conflict cannot be counted as an update or silently committed as a merge.
8. A committed import always has a reproducible immutable report.

## 13. Approved implementation dependencies

- Modern Zstandard decode uses official Zstandard 1.5.7 source in a decoder-only `CZstd` SwiftPM C target under its BSD license.
- Package/media protobuf decode uses Apple SwiftProtobuf 1.38.1 with LinguaBrain-owned minimal message declarations pinned to the researched wire fields.
- No Anki AGPL implementation or generated source is copied into LinguaBrain.
- These libraries are infrastructure details behind `BoundedPayloadDecoder` and metadata/manifest reader protocols; domain entities do not import them.
