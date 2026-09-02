# Feature Specification: Hermes APKG Export for Approved Cards

**Feature Branch**: `003-apkg-export-approved-cards`

**Created**: 2026-08-24

**Status**: Ready for implementation planning

**Input**: Create a native APKG export feature for approved Hermes cards, including SQLite collection generation, notes, cards, models, templates, decks, tags, owned media packaging, safe ZIP creation, and round-trip import verification.

## User Scenarios & Testing *(mandatory)*

As a learner, I can export my approved Hermes content to Anki, preserving the cards I reviewed and approved for offline study.

### User Story 1 - Export approved cards with media and provenance (Priority: P1)

As a learner, I can export my approved Hermes cards, including text, notes, templates, and cached media, to a native Anki package format (APKG) for offline study.

**Why this priority**: Export makes Hermes-generated content reusable in standard Anki clients while keeping Hermes as the canonical source. This enables offline learning and integration with existing Anki decks.

**Independent Test**: Approve a multilingual deck with RTL and LTR text, media, and diverse sense presentations, then export, inspect the package structure, and import into a clean Anki fixture to verify all fields, tags, and media are preserved.

**Acceptance Scenarios**:

1. **Given** approved cards with text, notes, templates, and media assets, **When** the learner initiates APKG export, **Then** the system creates a valid Anki package with `collection.anki21`, `notes`, `cards`, `models`, `templates`, `decks`, `tags`, and `media` directories.
2. **Given** exported cards with media, **When** the package is imported into Anki, **Then** the imported cards preserve all text content, sense identities, tags, and cached media with their provenance metadata; scheduling is preserved only where the target schema represents it losslessly.
3. **Given** approved cards with RTL/LTR content, **When** exported and re-imported, **Then** the text direction and Unicode content are preserved correctly across the export/import cycle.
4. **Given** exported package with owned media, **When** inspected before ZIP creation, **Then** each media file has a checksum and ownership record in the export manifest for security verification.

### User Story 2 - Selective export with source grouping (Priority: P1)

As a learner, I can choose which approved cards to export, separating those generated in Hermes from imported cards, ensuring clean content boundaries.

**Why this priority**: Learners need control over export scope to avoid mixing Hermes-generated content with imported cards, maintaining clear provenance and preventing unintended content mixing.

**Independent Test**: Create a collection with both Hermes-generated and imported cards, select only Hermes cards for export, verify the export contains only the selected cards with appropriate source tags, and confirm imported cards are excluded.

**Acceptance Scenarios**:

1. **Given** a collection containing both Hermes-generated and imported cards, **When** the learner opens the export selection UI, **Then** cards are clearly grouped by source with visual distinction between Hermes and imported origins.
2. **Given** cards grouped by source, **When** the learner selects cards from both groups and exports them, **Then** the export maintains source group separation through provenance tags in the exported metadata.
3. **Given** the export manifest is generated, **When** inspected before ZIP creation, **Then** each card entry includes source identification (hermes vs imported) for audit trail purposes.

### User Story 3 - Offline access and integrity verification (Priority: P2)

As a learner, I can trust that exported APKG files are secure, complete, and will render correctly in Anki without Hermes dependencies.

**Why this priority**: Export integrity is critical for offline learning and long-term accessibility. Learners need assurance that exported content is complete, secure, and will function independently of Hermes.

**Independent Test**: Generate an APKG export, verify all checksums, media ownership, and package structure, then extract to a clean directory and validate that Anki can open and render the package without Hermes installed.

**Acceptance Scenarios**:

1. **Given** an exported APKG file, **When** validated before delivery, **Then** the file contains all required files (`collection.anki21`, `media` directory) with correct SQLite schema and UTF-8 encoding.
2. **Given** media files in the export, **When** integrity-checked against checksums in the manifest, **Then** all files are present, uncorrupted, and properly referenced in the package.
3. **Given** exported package extracted to a clean environment, **When** opened in Anki client, **Then** the package loads successfully and all cards display correctly with media, tags, and review scheduling intact.

### User Story 4 - Round-trip verification and validation (Priority: P2)

As a learner, I can verify that exported and imported content is equivalent, with clear audit trails for compliance and quality assurance.

**Why this priority**: Round-trip verification ensures export/import fidelity, preventing data loss or corruption during the process. This is essential for quality assurance and user confidence.

**Independent Test**: Export an approved deck, import it into Anki, then export the imported deck back to TSV, and compare the normalized fields to verify 100% data preservation with clear provenance tracking.

**Acceptance Scenarios**:

1. **Given** exported APKG file, **When** imported into Anki, **Then** all card fields, templates, and scheduling information are preserved exactly as exported.
2. **Given** exported and re-exported content, **When** compared using a normalized comparison algorithm, **Then** the results show 100% field equality for text content and media references with clear provenance tracking.
3. **Given** exported package integrity, **When** validated against export contract specifications, **Then** the package meets all security, completeness, and format requirements specified in the APKG export contract.

## Edge Cases

- What happens when no approved cards exist for export?
- How does system handle export with missing media files?
- What happens when export selection includes no cards?
- How does system handle export cancellation during ZIP creation?
- What happens when media checksum validation fails?
- How does system handle corrupted or malformed cards during export?
- What happens when export selection includes cards from different language directions?
- How does system handle memory constraints during large export operations?
- What happens when export ZIP creation fails partway through?
- How does system handle export with duplicate card identities?

## Requirements

### Functional Requirements

- **FR-001**: System MUST support APKG export only for learner-selected approved cards, with clear source grouping (Hermes vs imported) for audit trail purposes.
- **FR-002**: System MUST generate valid `collection.anki21` SQLite database containing notes, cards, models, templates, decks, and tags compatible with Anki clients.
- **FR-003**: System MUST create owned media packaging with checksum verification and provenance tracking for all media assets.
- **FR-004**: System MUST implement safe ZIP creation with atomic write operations to prevent partial/corrupted exports.
- **FR-005**: System MUST preserve text content including RTL/LTR Unicode, pronunciation media, and sense identity across export/import cycles.
- **FR-006**: System MUST document scheduling compatibility and preserve review scheduling and due dates only where the target Anki schema represents them losslessly; otherwise it MUST use the documented fresh-Anki fallback and report the limitation.
- **FR-007**: System MUST include provenance metadata tagging exported cards with source, generation date, and approval status.
- **FR-008**: System MUST provide validation and verification before export completion, including checksum verification and package integrity checks.
- **FR-009**: System MUST support selective export with per-card selection, allowing learners to choose which approved cards to include.
- **FR-010**: System MUST implement round-trip verification capability, comparing exported/imported content for equivalence.

### Key Entities

- **ExportSelection**: User-defined subset of approved cards for export, including source grouping and selection criteria.
- **APKGPackage**: Complete export artifact containing SQLite database, media files, and manifest with ownership records.
- **MediaAsset**: Exported media resource with checksum, ownership proof, and provenance metadata.
- **ExportManifest**: Record of all exported cards, media files, checksums, and source attribution for audit trail.
- **RoundTripValidator**: Tool to verify equivalence between exported and imported content.

## Success Criteria

### Measurable Outcomes

- **SC-001**: At least 95% of exported cards preserve all text content, media, and scheduling information after complete export/import cycle.
- **SC-002**: 100% of exported packages pass integrity validation with all checksums matching before delivery to learner.
- **SC-003**: Export process completes successfully within 5 minutes for collections up to 500 cards with media.
- **SC-004**: 100% of exported APKG packages can be imported and rendered in standard Anki clients without Hermes dependencies.
- **SC-005**: Export selection interface clearly distinguishes between Hermes-generated and imported cards for user control.
- **SC-006**: Round-trip export/import verification detects and reports any data loss or corruption with 100% accuracy.
- **SC-007**: Media ownership records are preserved and verifiable throughout the export process.
- **SC-008**: Export process handles edge cases (no approved cards, missing media, cancellation) gracefully without data corruption.

## Assumptions

- All media assets required for exported cards are available and accessible during export process.
- Exported APKG files will be imported using compatible Anki client versions that support `collection.anki21` format.
- Export process has sufficient system resources (memory, disk space) for packages up to 500MB.
- Learners have read/write access to their export destination directories.
- Export validation MUST NOT require network access or private credentials.
- Exported cards have valid SQLite schema compatibility with Anki's data model.
- All approved cards have complete metadata including text content, media references, and review scheduling.
- Export process maintains backward compatibility with existing Anki collection formats where possible.
- Security constraints permit ZIP file creation and media asset packaging for export purposes.
