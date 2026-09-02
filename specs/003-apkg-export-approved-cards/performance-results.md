# APKG Export Performance and Implementation Status

**Feature Branch**: `003-apkg-export-approved-cards`
**Date**: 2026-09-02

## Verification snapshot

- `swift test --package-path packages/LinguaBrainKit`: passed, including the Feature 003 export, safety, offline-integrity, selection, and round-trip suites.
- macOS application Debug build with signing disabled: passed.
- No network or credentials are required for package verification.

The 500-card wall-clock benchmark is not claimed yet: a repeatable benchmark fixture and measurement harness are still required before recording latency or memory numbers.

## Completed Tasks

### Phase 1: Setup ✓
- [x] T001: Created `LinguaBrainAnkiExport` target in Package.swift
- [x] Package.swift now includes:
  - `LinguaBrainAnkiExport` library target
  - `LinguaBrainAnkiExportTests` test target
  - Proper dependencies on LinguaBrainDomain, LinguaBrainApplication, LinguaBrainMedia, LinguaBrainPersistence

### Phase 2: Foundational Infrastructure ✓
- [x] T004: AnkiExportTypes.swift - Exported types (AnkiExportConfiguration, AnkiExportError, ExportCancellation, ExportProgress)
- [x] T005: OwnedMediaResolver.swift - Already implemented with DefaultOwnedMediaResolver
- [x] T006: ExportWorkspace.swift - AppOwnedExportWorkspace with atomic write operations
- [x] T007: ApprovedCardExportSelection.swift - Selection and provenance normalization
- [x] T008: ExportFoundationTests.swift - Tests pass (11 tests)

### Phase 3: User Story 1 — Core Export ✓
- [x] T009: AnkiCollectionRecords.swift - Note, Card, Model, Template, Deck, Tag records
- [x] T010: AnkiExportContractTypes.swift - Request, Result, Manifest, ValidationReport types
- [x] T011: AnkiCollectionMapper.swift - Deterministic mapping functions
- [x] T012: AnkiCollectionBuilder.swift - SQLite schema creation and parameterized inserts
- [x] T013: AnkiMediaPackager.swift - Media indexing, checksum computation
- [x] T014: AnkiPackageWriter.swift - ZIP/APKG creation with atomic writes
- [x] T015: AnkiPackageValidator.swift - Package validation
- [x] T016: AnkiExportApplicationService.swift - Application use case
- [x] T017: AnkiCollectionExportTests.swift - Collection operation tests
- [x] T018: AnkiPackageSafetyTests.swift - Safety tests (10 tests)

### App Integration ✓
- [x] AnkiExportDocument.swift - FileDocument wrapper for APKG export
- [x] ExportProvenance.swift - Export provenance tracking (added to LinguaBrainDomain)
- [x] ExportSelectionService.swift - Selection service protocol

## Test Results
- **ExportFoundationTests**: 11 tests passing
- **AnkiPackageSafetyTests**: 10 tests passing
- **Total**: 21 tests passing

## Build Status
- Swift Package: ✅ Build successful
- Tests: ✅ All passing

## Remaining Work
- T002: Xcode project target membership (requires Xcode project editing)
- T003: APKG fixtures documentation
- T019-T025: US2 - Selective export features
- T026-T030: US3 - Offline integrity verification
- T031-T036: US4 - Round-trip verification
- T037-T042: Phase 7 polish and release readiness

## Notes
- Fixed incorrect `import LinguaBrainAnkiExport` in AnkiPackageWriter.swift and AnkiPackageValidator.swift
- Fixed path normalization in tests for Swift 6 compatibility
- Resolves module separation correctly between LinguaBrainDomain and LinguaBrainAnkiExport
