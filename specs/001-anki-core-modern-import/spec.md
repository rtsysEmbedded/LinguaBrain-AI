# Feature Specification: Anki Core Modern Import and Offline Review Gate

**Feature Branch**: `001-anki-core-modern-import`

**Created**: 2026-08-16

**Status**: Active — foundational contracts approved

**Input**: Complete the Anki Core validation gate defined by ADR-012 and the supporting Anki Core MVP specification.

## User Scenarios & Testing

### User Story 1 — Safely import a representative APKG (Priority: P1)

As a learner, I can inspect and import an Anki package containing modern or legacy collection data so that its supported decks, notes, cards, fields, tags, templates, and media become usable LinguaBrain records without modifying the original file.

**Why this priority**: Imported content validates the learning loop without depending on AI generation.

**Independent Test**: Select a supported fixture, review its preview, confirm import, and verify expected counts and provenance in the local library.

**Acceptance Scenarios**:

1. **Given** a valid package containing `collection.anki21b`, **When** inspection and confirmed import complete, **Then** supported notes, cards, decks, templates, tags, and media references are mapped transactionally.
2. **Given** a valid legacy `collection.anki2` or `collection.anki21` package, **When** it is imported, **Then** existing supported behavior remains intact.
3. **Given** a package that fails security or compatibility checks, **When** it is inspected, **Then** no learner records are committed and the user receives an actionable reason.

### User Story 2 — Re-import without uncontrolled duplication (Priority: P1)

As a learner, I can import the same or updated package again so that existing records are deterministically matched and reported instead of duplicated unpredictably.

**Independent Test**: Import the same fixture twice and then an updated fixture; verify stable identities, unchanged review history, and accurate inserted/updated/skipped/conflict counts.

**Acceptance Scenarios**:

1. **Given** an unchanged imported package, **When** it is re-imported, **Then** no uncontrolled duplicate cards, senses, or review units are created.
2. **Given** changed source content with the same provenance identity, **When** it is re-imported, **Then** safe updates are reconciled without resetting independent review schedules.
3. **Given** an ambiguous destructive conflict, **When** reconciliation runs, **Then** it is surfaced rather than silently overwriting learner data.

### User Story 3 — Complete an offline four-rating review (Priority: P1)

As a learner, I can review imported cards offline using reveal plus Again, Hard, Good, and Easy, close the app, and later continue with intact due dates and history.

**Independent Test**: Import a fixture, use all four ratings with a controlled clock, restart, and compare the restored queue/history with expected FSRS results.

**Acceptance Scenarios**:

1. **Given** an imported due card, **When** its answer is revealed and rated, **Then** the pinned FSRS scheduler records the event and next due state atomically.
2. **Given** a card rated Again or Hard, **When** its displayed interval becomes due, **Then** it returns to the queue and not before.
3. **Given** persisted reviews, **When** the app restarts offline, **Then** deck, card, recognition/reverse states, history, and due queue are restored without loss.
4. **Given** the same dataset on iPhone, iPad, and Mac, **When** the semantic flow is performed, **Then** platform behavior is equivalent.

### Edge Cases

- Missing, corrupt, encrypted, ZIP64, traversal, symlink, duplicate-name, archive-bomb, or oversized archive entries.
- Unsupported or malformed schema, model, or template data.
- Notes with reordered/custom fields, HTML, missing translations, or deleted cards.
- Missing, oversized, unsupported, or malicious media entries.
- Re-import after learner edits or accumulated review history.
- App termination or storage failure during import or review commit.
- Two lexical senses sharing a surface form but having different domains or meanings.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST inspect APKG archives read-only and apply documented resource/security limits before extraction or database access.
- **FR-002**: The system MUST preserve legacy `collection.anki2`/`collection.anki21` support and add approved `collection.anki21b` support.
- **FR-003**: The system MUST preview compatibility, metadata, counts, warnings, and expected changes before explicit confirmation.
- **FR-004**: The system MUST map supported decks, notes, cards, fields, templates, tags, images, and audio into LinguaBrain-owned records.
- **FR-005**: The system MUST retain provenance and stable source identities sufficient for deterministic re-import.
- **FR-006**: Re-import MUST classify inserted, updated, unchanged/skipped, and conflicted records while preserving unrelated learner edits and review state.
- **FR-007**: Import commit MUST be transactional and leave no partial learner-visible dataset on failure.
- **FR-008**: Imported cards MUST participate in the offline due queue, reveal flow, four FSRS ratings, session summary, and restart recovery.
- **FR-009**: Recognition and Persian-to-German reverse translation MUST retain independent persisted review states.
- **FR-010**: Imported lexical senses MUST use stable meaning/domain identity rather than surface text alone.
- **FR-011**: Confirmed package removal MUST remove owned records according to the existing contract without deleting the original APKG file.
- **FR-012**: The same semantic journey MUST function on iPhone, iPad, and Mac without AI or network access.
- **FR-013**: Failures MUST provide recoverable feedback and MUST NOT claim success before persistence succeeds.
- **FR-014**: Surface spelling MUST NOT be a uniqueness key; each meaning/domain-specific `LexicalSense` MUST retain an independent identity and review state.
- **FR-015**: Source-owned values, learner overrides, and learner review evidence MUST have separate ownership and re-import MUST NOT silently overwrite learner-owned state.

### Key Entities

- **ImportPackage**: Source fingerprint, metadata, inspection state, provenance, and ownership boundary.
- **ImportRecordIdentity**: Stable source-to-LinguaBrain identifier mapping.
- **Deck / Note / ImportedCard**: LinguaBrain-owned content reconstructed from supported Anki semantics.
- **LexicalSense**: Meaning- and domain-specific learning identity.
- **MediaResource**: Validated local image/audio resource with lifecycle ownership.
- **ReviewUnit / ReviewEvent / FSRSState**: Objective-level scheduling and immutable review evidence.

## Success Criteria

- **SC-001**: Valid legacy and modern golden fixtures import with expected deterministic counts on supported Apple test environments.
- **SC-002**: Re-importing an unchanged fixture produces zero uncontrolled duplicate cards, senses, review units, or media.
- **SC-003**: Every agreed malicious/corrupt fixture is rejected before learner-visible commit with zero partial records.
- **SC-004**: Four-rating fake-clock and restart tests reproduce pinned FSRS results exactly.
- **SC-005**: A representative deck remains fully reviewable offline after its source APKG is unavailable.
- **SC-006**: iOS/iPadOS and macOS builds plus the semantic journey pass without AI credentials.

## Assumptions

- ADR-009 through ADR-012 remain accepted.
- Arbitrary Anki add-on execution is out of scope; unsupported behavior is reported and preserved only where safe.
- Sync, OCR, AI enrichment, and final visual redesign are not required to close this feature.
- Implementation choices in `plan.md` may not weaken these requirements.

## References

- [ADR-012](../../decisions/ADR-012-Anki-Core-First-and-APKG-Import-Boundary.md)
- [Anki Core MVP Specification](../../docs/supporting/Anki_Core_MVP_Specification.md)
- [MVP Definition and Roadmap](../../docs/10_MVP_Definition_and_Roadmap.md)
- [Project Status](../../PROJECT_STATUS.md)
