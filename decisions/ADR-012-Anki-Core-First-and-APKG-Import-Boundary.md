---
title: "ADR-012: Anki Core First and APKG Import Boundary"
status: accepted
date: 2026-08-03
decision_makers:
  - Product Owner
  - Learning Engine Architect
  - Persistence Lead
decision_ids:
  - LB-DEC-060
work_items:
  - LB-WI-ANKI-01
  - LB-WI-ANKI-02
  - LB-WI-ANKI-03
---

# ADR-012: Anki Core First and APKG Import Boundary

## Context

The visual prototype exposed two expected limitations: review ratings were not
connected to scheduling, and generated-card previews used static sample data.
Adding AI before durable import, review, and restart behavior would make it hard
to distinguish content-generation failures from defects in the learning loop.

Anki packages provide realistic notes, cards, templates, media, and optionally
scheduling history. They are therefore a useful bootstrap source for validating
LinguaBrain's local card and review foundation before AI enrichment is enabled.

## Decision drivers

- Prove a complete offline study loop before adding provider complexity.
- Let the product be tested with realistic learner-owned decks.
- Preserve LinguaBrain's KnowledgeItem, LearningObjective, ReviewUnit, and
  LearningEvent model rather than adopting Anki's storage schema as the domain.
- Keep future AI, graph, adaptive learning, OCR, conversation, and device inputs
  possible without rewriting the local learner store.
- Treat imported packages and HTML/media as untrusted input.

## Decision

LinguaBrain will deliver an **Anki Core validation release** before AI-backed
card generation and final visual-system approval.

The release must support:

1. secure import of `.apkg` deck packages;
2. mapping decks, notes, card templates, rendered fields, tags, and supported
   media into LinguaBrain-owned records;
3. a due-card queue and question/answer reveal flow;
4. functional Again, Hard, Good, and Easy ratings;
5. deterministic FSRS scheduling behind the ReviewScheduler port;
6. immutable review evidence/history and restart durability;
7. basic deck, due-count, session, and review-summary views;
8. fully offline operation after import.

### APKG is an adapter, not the database

```text
Untrusted .apkg package
        |
        v
Sandboxed APKG Import Adapter
        |
        v
Validated Import Proposal
        |
        v
LinguaBrain transaction
        |
        +--> KnowledgeItem / imported note representation
        +--> Card presentation snapshot and media references
        +--> LearningObjective / ReviewUnit
        +--> Source provenance and stable external identifiers
```

The application must not open an extracted Anki SQLite collection as its live
learner database. Anki table names, row types, protobuf/legacy package details,
HTML conventions, and scheduler fields remain confined to the import adapter.

### Scheduling-history policy

- Importing notes, cards, templates, tags, and supported media is the default.
- Importing existing progress and review history is opt-in and remains disabled
  until a separately tested mapping can preserve semantics without fabricating
  LinguaBrain LearningEvents.
- The first accepted implementation initializes new ReviewUnits when progress
  import is disabled.
- Re-import uses stored package/note/card identifiers and a documented conflict
  policy; it must not silently duplicate or overwrite learner edits.

### Security boundary

The importer must enforce archive-entry path validation, expanded-size and
entry-count limits, temporary-directory isolation, media allowlisting, safe
filename generation, HTML sanitization at rendering boundaries, transactional
commit, and cleanup after success, cancellation, or failure.

### AI and advanced learning

AI integration, Knowledge Graph expansion, Digital Twin inference, adaptive
planning, OCR, conversation, and final graphic polish are not removed. They are
sequenced after the Anki Core acceptance gate. AI continues to create or enrich
content only; it never owns review scheduling or rating persistence.

## Alternatives considered

### Implement AI card generation first

Rejected for sequencing. It combines provider, prompt, linguistic-validation,
persistence, and review risks before the basic learning loop is trustworthy.

### Use the Anki SQLite collection directly

Rejected. It couples the product domain to an external implementation, weakens
migration control, and obstructs objective-level mastery and future input types.

### Build only manual cards before import

Rejected as the sole validation route. Manual entry remains supported, but APKG
provides realistic volume, templates, media, and learner migration value.

### Clone all Anki behavior before continuing

Rejected. The scope is the minimum reliable import/review loop, not add-ons,
sync, every template feature, or byte-for-byte scheduler compatibility.

## Consequences

### Positive

- The first production behavior is useful without AI or network access.
- Scheduling and durability defects become observable with realistic data.
- Existing Anki users can evaluate LinguaBrain with familiar material.
- Later intelligence builds on verified learning events rather than mock state.

### Negative

- AI-visible differentiation arrives later.
- APKG compatibility and safe HTML/media handling add early engineering work.
- Imported templates may need a documented supported subset and fallback view.

## Acceptance evidence

- A representative `.apkg` with text, image, and audio imports transactionally.
- A corrupt or malicious archive leaves no partial learner records or unsafe
  extracted files.
- Again/Hard/Good/Easy create distinct, reproducible FSRS outcomes.
- Closing and reopening the app preserves cards, due state, media references,
  and review history.
- The same imported deck can be re-imported without uncontrolled duplication.
- No production domain or application target imports Anki-specific storage types.

## Follow-up actions

- [x] Accept ADR-003 for the native persistence and migration stack.
- [x] Accept ADR-004 for the pinned FSRS implementation and reference vectors.
- [ ] Define the APKG supported-format and rendering compatibility matrix.
- [ ] Implement importer security limits and adversarial fixtures.
- [ ] Implement the review transaction and restart integration suite.
- [ ] Resume AI-provider work only after the Anki Core exit criteria pass.

## References

- [Anki Manual: Packaged Decks](https://docs.ankiweb.net/importing/packaged-decks.html)
- [Anki Manual: Exporting and package behavior](https://docs.ankiweb.net/exporting.html)
- [Anki source repository](https://github.com/ankitects/anki)
