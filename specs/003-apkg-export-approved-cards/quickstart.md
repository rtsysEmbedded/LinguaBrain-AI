# APKG Export Quickstart

## Prerequisites

- Xcode 27 beta and the repository's Swift 6.4 toolchain;
- approved-card fixture containing German/Persian text and at least one media asset;
- no network or private credentials.

## Validate a minimal export

1. Select one approved Hermes-generated card and one imported card.
2. Select only the Hermes card for export.
3. Generate an APKG into a temporary destination.
4. Inspect the archive and confirm `collection.anki21`, `media`, and numeric media entries.
5. Validate the manifest checksum and source group.
6. Confirm no partial destination exists after a forced failure.

## Validate RTL/LTR and media

1. Export a German-to-Persian and Persian-to-German selection.
2. Extract the package in a clean temporary directory.
3. Compare normalized fields, direction metadata, tags, and media checksums with the source fixture.

## Validate round trip

1. Import the package through the supported normalized Anki reader fixture.
2. Compare notes, cards, models, templates, decks, tags, examples, media references, and provenance.
3. Report any scheduling fields that use the documented fresh-Anki fallback.

## Suggested commands

```bash
swift test --package-path packages/LinguaBrainKit
xcodebuild -project apps/learner/LinguaBrain.xcodeproj -scheme 'LinguaBrain Mac' -sdk macosx -configuration Debug CODE_SIGNING_ALLOWED=NO build
xcodebuild -project apps/learner/LinguaBrain.xcodeproj -scheme 'LinguaBrain' -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build-for-testing
```

## Evidence

### Package Tests
```
✔ All 61 package tests pass (LinguaBrainApplicationTests, LinguaBrainAnkiExportTests, LinguaBrainAITests)
- AnkiCollectionExportTests: 10 tests pass
- AnkiPackageSafetyTests: 10 tests pass
- AnkiRoundTripTests: 14 tests pass
- ExportFoundationTests: 11 tests pass
- ExportSelectionTests: 9 tests pass
- OfflineIntegrityTests: 7 tests pass
```

### Build Status
- **Package**: ✅ Compiles and tests pass
- **macOS App**: ⚠️ `xcodebuild` reaches the package compile but Xcode 27 beta reports a Swift compiler diagnostic in `AnkiPackageValidator.swift` while returning exit code 0; investigate before release.
- **iOS App**: ⚠️ Not yet re-verified after the export package targets were re-enabled.

### Known Issue
The package implementation is complete and all package tests pass. App-level verification remains open because the Xcode 27 beta build currently emits a compiler diagnostic during package compilation and the iOS simulator build has not yet been re-run.
