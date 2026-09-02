# Implementation Plan: Hermes APKG Export for Approved Cards

**Branch**: `003-apkg-export-approved-cards`  
**Date**: 2026-08-22  
**Spec**: [spec.md](spec.md)

## Summary

Implement a native, local-first APKG export pipeline for learner-selected approved cards. Hermes remains the canonical store. The exporter creates a bounded SQLite Anki collection, deterministic notes/cards/models/templates/decks/tags, owned media entries, a manifest, and an atomically packaged ZIP. A normalized round-trip validator compares the exported representation with a clean Hermes/Anki fixture.

## Technical Context

**Language/Version**: Swift 6.4

**Primary Dependencies**: System SQLite/GRDB boundary already selected by ADR-003, Foundation file APIs, and a bounded ZIP implementation selected during research. No Anki add-on execution.

**Storage**: Temporary app-owned SQLite database and media staging directory; final `.apkg` delivered through a user-selected file URL.

**Testing**: XCTest, package tests, app integration tests, sanitized Anki fixtures, and macOS/iOS build verification.

**Target Platform**: iOS/iPadOS 27 and macOS 27, local-first and offline-capable.

**Project Type**: Native Apple mobile/desktop application with a shared Swift package.

**Performance Goals**: Complete a 500-card export within 5 minutes and avoid loading all media bytes into memory at once.

**Constraints**: Approved cards only; bounded card/media counts and sizes; no partial destination file; no network requirement; no direct provider or scheduler mutation; preserve Unicode and RTL/LTR text.

**Scale/Scope**: One learner export up to 500 cards and 500 MB staged media in the MVP.

## Constitution Check

| Gate | Result | Evidence / action |
| --- | --- | --- |
| Anki Core before expansion | Pass with dependency | Export consumes approved cards and must not weaken offline review/import. |
| Deterministic learning, optional AI | Pass | Export is deterministic and does not call AI providers. |
| Local-first privacy | Pass | All staging is local; source grouping and provenance are explicit. |
| Stable domain identity | Pass | Export identity derives from approved card/sense/direction identity. |
| Native Apple architecture | Pass | Implementation belongs in the shared Swift package with thin SwiftUI UI. |
| Security and evidence | Planned | Archive limits, checksum validation, atomic output, hostile fixtures, and round-trip tests are required. |

## Architecture

```text
Export Selection UI
        ↓
ExportApplicationService
        ↓
Selection + Provenance Normalizer
        ↓
Anki Collection Builder (SQLite)
        ↓
Media Manifest + Owned Staging
        ↓
Integrity Validator
        ↓
Atomic ZIP/APKG Writer
        ↓
Round-trip Validator / Export Report
```

The exporter must use application ports for approved-card reads and file delivery. It must not write to canonical learner storage, review state, or external Anki databases.

## Project Structure

```text
packages/LinguaBrainKit/
├── Sources/
│   ├── LinguaBrainDomain/          # ExportSelection, ExportManifest, identities
│   ├── LinguaBrainApplication/     # export use case, TSV/APKG orchestration
│   ├── LinguaBrainPersistence/     # approved-card read ports and SQLite boundary
│   ├── LinguaBrainMedia/           # owned media resolution and checksums
│   └── LinguaBrainAnkiExport/      # collection builder, ZIP writer, validator
└── Tests/
    ├── LinguaBrainAnkiExportTests/
    ├── LinguaBrainApplicationTests/
    └── Fixtures/

apps/learner/
├── App/LibraryPrototypeView.swift  # export selection and file delivery integration
├── App/AnkiExportDocument.swift    # user-facing file document wrapper
└── Tests/AnkiExportIntegrationTests.swift
```

## Phase 0 — Research

Resolve the supported Anki SQLite schema/version, note/card/template mapping, media index rules, ZIP constraints, scheduling compatibility, and system/library choice. Record decisions in `research.md`.

## Phase 1 — Design and contracts

Create `data-model.md`, `contracts/apkg-contract.md`, `contracts/manifest-contract.md`, and `quickstart.md`. Define normalized records before writing SQLite or ZIP code.

## Phase 2 — Foundational implementation

Implement selection, provenance normalization, bounded export configuration, checksum service, temporary workspace lifecycle, and deterministic fixture builders.

## Phase 3 — User Story 1: Collection and media export

Build the SQLite collection, media manifest, templates, tags, decks, and atomic APKG writer. Add integrity validation and failure cleanup.

## Phase 4 — User Story 2: Selective source-grouped export

Add source-grouped selection UI and ensure only selected approved records are exported with provenance tags.

## Phase 5 — User Story 3: Offline integrity

Add hostile media/archive fixtures, checksum verification, cancellation, bounded resource handling, and offline package validation.

## Phase 6 — User Story 4: Round trip

Add normalized reader/validator fixtures, export/import comparison, Unicode/RTL/LTR assertions, and evidence reporting.

## Verification Strategy

- Unit tests for mapping, identity, tags, templates, checksums, limits, and atomicity.
- SQLite schema and query tests using sanitized fixtures.
- ZIP traversal, duplicate entry, oversize, checksum, cancellation, and partial-write tests.
- Round-trip comparison for text, senses, examples, media references, directions, and provenance.
- macOS and iOS builds; app-level file export test on a simulator where supported.
- No private credentials or network access required.

## Risks and Mitigations

- **Anki schema drift**: pin one supported collection schema and keep a compatibility matrix.
- **Scheduling mismatch**: document the exact mapping; never claim Hermes FSRS/mastery is preserved unless the target Anki fields can represent it losslessly.
- **ZIP/archive abuse**: bounded staging, normalized names, no traversal, atomic destination replacement.
- **Media loss**: checksum before packaging and after extraction; text-only fallback remains explicit.
- **Memory pressure**: stream media and build in an app-owned temporary directory.

## Complexity Tracking

No constitution violation is requested. The dedicated export target is justified because SQLite schema generation, media ownership, ZIP safety, and round-trip validation have independent security and compatibility gates.

