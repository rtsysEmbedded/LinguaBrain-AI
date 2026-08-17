# Contract: Deterministic Import Reconciliation and Conflict Management

**Status**: Approved for T010–T013 implementation

## Purpose

Reconcile a normalized Anki package with LinguaBrain-owned data without equating spelling with meaning, duplicating unchanged records, overwriting learner edits, or resetting review history.

## Inputs

- `NormalizedAnkiPackage`;
- exact `ImportPackageRevision` fingerprint;
- selected or newly created `ImportSource` lineage;
- existing source-record mappings and source snapshots;
- existing `LexicalSense`, imported card, override, and ownership links;
- read-only facts about learner review evidence;
- versioned reconciliation policy.

## Matching precedence

1. **Exact package revision**: same SHA-256 and completed prior report -> return the prior semantic result as unchanged; do not duplicate.
2. **Authoritative source identity**: same `(ImportSource, entityKind, externalID)` -> compare source content hashes.
3. **Explicit prior link**: use a learner-approved mapping from this source record to a sense.
4. **Semantic candidate**: propose candidates using the versioned sense key; do not automatically merge.
5. **No candidate**: insert a new meaning/domain-specific sense.

Filename and normalized lemma alone are never matching rules.

## Decision table

| Existing mapping | Incoming source hash | Learner override/reviews | Decision |
| --- | --- | --- | --- |
| none | any valid | none | `inserted` with a new sense unless learner explicitly links a proposed candidate |
| none | resembles one/many senses | any | propose `linkedExisting` or new sense; ambiguity is `conflict` |
| same source identity | same | any | `skippedUnchanged`; preserve all learner state |
| same source identity | changed | no override conflict | `updated`; preserve IDs and all review state |
| same source identity | changed | same field edited by learner | update source snapshot underneath override and emit `concurrentFieldChange` |
| duplicate source identity in incoming package | any | any | reject package/record set before commit |
| source identity reused for incompatible entity/sense | changed | any | `sourceIdentityReused` conflict; no overwrite |
| prior source record absent in new revision | n/a | no learner/shared ownership | mark source-retired; deletion follows ownership policy |
| prior source record absent in new revision | n/a | edits, reviews, or another owner | detach/retire source link and preserve learning data |

## Meaning/domain behavior

Given three incoming records:

```text
entlassen | verb | اخراج کردن | work
entlassen | verb | مرخص کردن | medicine
entlassen | verb | آزاد کردن | legal
```

the reconciler produces three `LexicalSense` identities. It must not skip the second and third because `normalizedLemma == "entlassen"`. Each receives independent recognition and reverse-translation `ReviewUnit` identities.

If a later package changes the medical Persian text from `مرخص کردن` to a more precise translation but retains the authoritative source identity, it updates that medical source snapshot and sense presentation without touching the work/legal senses or any FSRS fields.

## Learner-owned field resolution

For each field:

```text
base = source snapshot when learner override was created
local = learner override
incoming = latest source value
```

- `incoming == base`: keep local; no conflict.
- `local == base`: accept incoming; the override may be removed.
- `incoming == local`: accept value and clear redundant conflict.
- all three differ: retain local as effective value, retain incoming as source value, emit `concurrentFieldChange`.

Available learner actions are `keepMine`, `acceptSource`, and `editResolvedValue`. No conflict action modifies review history.

## Import plan and report

Before confirmation, reconciliation returns an immutable plan containing:

- inserted, updated, skipped, linked, conflicted, rejected, and retired counts;
- per-operation reason codes;
- affected senses/decks/media;
- learner-state preservation assertions;
- warnings and required learner resolutions.

Unresolved destructive conflicts block commit. Non-destructive concurrent-field conflicts may commit only when the policy explicitly retains the learner override and exposes the conflict in the report.

After successful transaction, the same plan plus resulting record IDs becomes an immutable `ImportReport`.

## Atomicity

The transaction order is:

1. verify plan still matches package revision and store generation;
2. create/update source lineage and package revision;
3. apply source snapshots and normalized entities;
4. apply explicit links/new senses/imported cards;
5. transfer validated media ownership;
6. retire absent source mappings according to ownership policy;
7. write conflict decisions and immutable report;
8. commit once.

Any failure rolls back all steps. Review tables are outside the writable import change set except for creating empty ReviewUnits for genuinely new accepted learning objectives.

## Determinism

Given identical normalized input, import-source selection, existing store snapshot, policy version, and explicit learner decisions, operation ordering and results must be identical. Stable ordering is by entity kind, external source ID, then canonical content hash; UUID creation occurs only for deterministic `inserted` operations and is captured in the committed report.

## Required tests

1. Unchanged exact re-import produces only `skippedUnchanged`.
2. Updated source identity changes source content but preserves record UUID and FSRS state.
3. `entlassen` work/medical/legal senses coexist and schedule independently.
4. Same lemma/translation with different usage context is not automatically merged.
5. Same-field source/learner change retains learner effective value and reports conflict.
6. Source deletion with reviews detaches/retains instead of deleting.
7. Duplicate/reused source identities are rejected without partial writes.
8. Store mutation between preview and confirmation invalidates and rebuilds the plan.
9. Transaction failure leaves zero partial records/media ownership.
10. Package removal preserves shared or learner-owned senses and all required review evidence.
