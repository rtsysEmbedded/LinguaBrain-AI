# Project Audit — 2026-10-13

**Date:** 2026-10-13
**Baseline commit:** `5162ef5` (`main` and `claude/trusting-galileo-wsfglh` were identical at audit start)
**Scope:** Repository hygiene, `packages/LinguaBrainKit`, the native learner app in `apps/learner`, Spec Kit configuration, and project-status documentation.
**Purpose:** Separate verified defects and incomplete work from the claims in `PROJECT_STATUS.md`, and record the evidence behind every finding.

## 1. Method

1. Static review of every tracked source, configuration, specification, ADR, and status document.
2. Structural validation of every tracked JSON, YAML, and String Catalog file.
3. Compilation and test execution of `LinguaBrainKit` with the official **Swift 6.4.1** toolchain for Ubuntu 24.04 (`swift-6.4.1-RELEASE`), on a scratch copy of the package. The repository itself was not modified for this step.

### 1.1 Linux verification shims

The package is designed for Apple platforms. To compile it on Linux, the scratch copy received the following **Linux-only** shims. They are not defects in the repository:

| Shim | Reason |
| --- | --- |
| `@_exported import FoundationNetworking` in `LinguaBrainAI` | `URLRequest`/`HTTPURLResponse` live in `FoundationNetworking` on Linux. |
| `CryptoKit` module backed by `swift-crypto` | `CryptoKit` is Apple-only. |
| `SQLite3` system-library module map | Apple SDKs provide `SQLite3`; Linux does not. |
| `autoreleasepool` no-op in `LinguaBrainAnkiExportTests` | The Objective-C runtime is Apple-only. |

Two further patches were needed because of **repository defects** (findings A4 and A5 below).

### 1.2 Result

With the shims and the two defect patches, the package built and **194 XCTest cases passed with 0 failures**:

| Test target | Tests |
| --- | ---: |
| `LinguaBrainDomainTests` | 20 |
| `LinguaBrainApplicationTests` | 69 |
| `LinguaBrainAnkiExportTests` | 64 |
| `LinguaBrainAITests` | 41 |
| **Total** | **194** |

### 1.3 Not verified

The SwiftUI app targets (`LinguaBrain`, `LinguaBrain Mac`, `LinguaBrainTests`) depend on SwiftUI, SwiftData, AVFoundation, Speech, CloudKit, and Security. They can only be built with Xcode 27 on macOS and were **not** built during this audit.

## 2. Findings

### A. Functional and build defects

| ID | Finding | Location | Evidence |
| --- | --- | --- | --- |
| A1 | `.specify/extensions.yml` is invalid YAML. Commit `5162ef5` prefixed every line from line 3 onward with one space, so the Spec Kit Git hooks cannot be loaded. | `.specify/extensions.yml` | `yaml.scanner.ScannerError: mapping values are not allowed here (line 3, column 10)`. Removing the leading space reproduces the previous revision byte for byte. |
| A2 | The Feature 004 practice engine is unreachable from the UI. Today always passes `exercise: nil`, so `PracticeSessionBoundaryView` always renders the legacy `SkillPracticeView`. `WritingPracticeView`, `GrammarPracticeView`, `ListeningPracticeView`, and `SentenceLearningHistoryView` are referenced only by tests. | `apps/learner/App/TodayPrototypeView.swift:261-263`, `apps/learner/App/Practice/PracticeComposition.swift:98-106` | Code inspection; corresponds to open task T033. |
| A3 | A stored OpenRouter text endpoint is overwritten with the OpenAI endpoint on every launch. This contradicts the CHANGELOG ("OpenRouter remains selectable through its endpoint URL") and accepted ADR-013. | `apps/learner/App/SettingsPrototypeView.swift:565-567` | Code inspection. |
| A4 | The Application layer depends on a Darwin type: `ProviderError.keychain(OSStatus)`. The README states that the application core is independent of Apple SDKs. | `packages/LinguaBrainKit/Sources/LinguaBrainApplication/LinguaBrainApplication.swift:33` | `error: cannot find type 'OSStatus' in scope` on Swift 6.4.1/Linux. |
| A5 | `ExportCancellation` is a non-`Sendable` class captured by a `@Sendable` Dispatch closure. | `packages/LinguaBrainKit/Sources/LinguaBrainAnkiExport/AnkiExportTypes.swift:84-101` | `error: capture of 'self' with non-Sendable type 'ExportCancellation' in a '@Sendable' closure` on Swift 6.4.1/Linux. Not re-checked on Xcode 27. |
| A6 | The APKG media fixtures are plain-text placeholders, so signature-based media detection is never exercised with real MP3/JPEG bytes. | `packages/LinguaBrainKit/Tests/Fixtures/APKG/media/test-audio.mp3`, `test-image.jpg` | File contents: `placeholder audio content for testing`. |

### B. Project and repository hygiene

| ID | Finding | Location | Evidence |
| --- | --- | --- | --- |
| B1 | Four Swift files are not members of any Xcode target. `AnkiExportDocument.swift` duplicates the type declared in `LibraryPrototypeView.swift:1200`. `AnkiExportIntegrationTests.swift` imports a non-existent module (`LinguaBrainApp`) and contains two `XCTAssertTrue(true)` placeholder tests. The two `UITests/` files have no UI-test target; the project contains only three targets. | `apps/learner/App/AnkiExportDocument.swift`, `apps/learner/Tests/AnkiExportIntegrationTests.swift`, `apps/learner/UITests/*.swift` | `project.pbxproj` contains no file reference for these files. |
| B2 | `.gitignore` ignores `.swiftpm/` and `*.xcodeproj/`, which contradicts its own comment and prevents shared schemes and test plans from being tracked. It also contains duplicated rules and a stray `-Xcc/` entry. | `.gitignore:81-82` | `git check-ignore -v apps/learner/LinguaBrain.xcodeproj/xcshareddata/xcschemes/LinguaBrain.xcscheme` matches `*.xcodeproj/`. |
| B3 | Package platforms (`iOS 17`, `macOS 14`, `tvOS 17`, `watchOS 10`) do not match ADR-009 and the app deployment targets (`27.0`). tvOS and watchOS are outside the approved scope. `PackageDescription` 6.4 accepts `.v27`. | `packages/LinguaBrainKit/Package.swift:6-11` | `swift package dump-package` with `.iOS(.v27), .macOS(.v27)` succeeds. |
| B4 | `TestConstants.swift` belongs to no target and is never compiled. | `packages/LinguaBrainKit/Tests/LinguaBrainTestSupport/TestConstants.swift` | Not listed in `Package.swift`. |
| B5 | A 95.7 MiB third-party deck was committed. It is unreferenced, above GitHub's 50 MiB warning threshold, and of unknown redistribution license. | `assets/German_Top_4000_vocabulary.apkg` | 100,360,064 bytes. |
| B6 | Commit `5162ef5` ("no idee") bundles 126 files (+13,813/−501) and was authored as `pershan@MacBook-Pro-von-Saeid.local`, which indicates that `git config user.email` is not set on that machine. | Git history | `git show --stat 5162ef5`. |

### C. Hardcoded configuration and text

The project rule is that settings and user-facing text live in JSON resources, not in source code.

| ID | Finding | Location |
| --- | --- | --- |
| C1 | About 409 Swift source lines contain Persian text. Most are UI copy or error messages; the rest are seed vocabulary and persisted identity strings. Distribution: `PrototypeModels.swift` 100, `SettingsPrototypeView.swift` 86, `LibraryPrototypeView.swift` 84, `AddWordPrototypeView.swift` 67, `ProgressPrototypeView.swift` 28, `TodayPrototypeView.swift` 22, `OnboardingPrototypeView.swift` 11, others 11. | `apps/learner/App/*.swift` |
| C2 | English UI copy and errors are also hardcoded, including placeholder identity text (`"Saeid"`, `"Deutsch · B1"`, `"Guten Morgen 👋"`). | `PrototypeRootView.swift:94-95, 164-172`, `TodayPrototypeView.swift:128`, `UtilitiesPrototypeView.swift`, `LegacyPracticeMigration.swift`, `ProviderError.localizedDescription` |
| C3 | Provider endpoints, model identifiers, and voices are hardcoded. The realtime transcription URL ignores the configured endpoint. | `SettingsPrototypeView.swift:566-636, 1039-1045, 1263-1265`, `UtilitiesPrototypeView.swift:330, 364-370`, `LinguaBrainApplication.swift:240-242` |
| C4 | Localization JSON key parity is correct (628 keys in each of `fa`, `en`, `de`), but 9 `en` and 9 `de` values are still Persian, and 275 keys are Persian sentences instead of stable identifiers. Info.plist permission texts are English-only build settings. | `apps/learner/Resources/Localization/*.json`, `project.pbxproj` |

### D. Documentation drift

| ID | Finding | Location |
| --- | --- | --- |
| D1 | `last_updated` is 2026-09-06 while the file contains 2026-09-07/08 notes; "Active Git branch" and "Configure a Git remote" are stale although `origin` exists; M1 "Create the local multi-target `LinguaBrainKit` Swift package" is unchecked although the package exists; the revision table is out of order; progress notes are appended after the revision table; the latest test count (169) is stale. | `PROJECT_STATUS.md` |
| D2 | The README reproduces the normative ADR-010 target layout without stating which modules exist today. Five listed modules are not created yet (`LinguaBrainPresentation`, `LinguaBrainLanguageDE`, `LinguaBrainLanguageFA`, `LinguaBrainReviewFSRS`, `LinguaBrainPlatformApple`), and the existing `LinguaBrainAnkiExport` target is defined in neither ADR-010 nor the README (only in `docs/apkg-export/README.md`). The README's status section still names the Anki Core feature as active. | `README.md`, `decisions/ADR-010-Swift-Package-and-Module-Layout.md` |
| D3 | ADR-013 still names OpenRouter as the first cloud adapter, while the CHANGELOG records the move to a generic OpenAI-compatible boundary with OpenAI defaults. | `decisions/ADR-013-Initial-AI-Provider-Strategy.md` |
| D4 | Cross-feature trackers disagree: Feature 002 T043 and Feature 001 T023/T024 remain open although Feature 003 delivered APKG export. | `specs/001-…/tasks.md`, `specs/002-…/tasks.md` |

## 3. Incomplete work

| Area | Status |
| --- | --- |
| Feature 004 — Adaptive skill practice | 27 of 36 tasks complete. Open: T027 (listening tests; needs licensed audio), T029 (recorder; needs physical device), T030–T032 (speaking; blocked by the negative pronunciation-provider decision), **T033 (UI integration; see A2)**, T034 (production GRDB ownership adapter, export/delete), T035 (final QA; `AdaptivePracticeJourneyTests.swift` does not exist), T036 (traceability close-out). |
| Feature 001 — Anki Core | 16 complete, 14 open, 13 deferred: modern `collection.anki21b` import (T006–T013), cross-device journey (T016), security review and handoff (T019), localization QA (T004E), transcription (T034–T039). |
| Feature 002 | T043 open (superseded in practice by Feature 003; see D4). |
| Feature 003 | T040 open: 500-card export performance measurement. |
| Milestones | M1, Anki Core release gate, M2, M5, and M6 are largely unchecked; Documents 16–20 and all six canonical diagrams do not exist. |

## 4. Remediation plan

| Group | Items | Notes |
| --- | --- | --- |
| 1. Safe code fixes | A1, A3, A4, A5, B1–B4 | Low risk; package tests can verify A4/A5. |
| 2. Hardcoding removal | C1–C4 | App-side; requires an Xcode 27 build after the change. |
| 3. Documentation | D1–D4, this report | — |
| 4. Feature 004 integration | A2 / T033 | Requires product decisions before implementation. |
| Repository size | B5 | Remove from the working tree; history rewrite only with explicit approval. |

The remediation status of each group is recorded in Section 5.

## 5. Remediation status

This section is updated by the commits that address the findings.

| Group | Status |
| --- | --- |
| 1. Safe code fixes | Open — not selected for this round. |
| 2. Hardcoding removal | Provider configuration and prompts moved to `Resources/Configuration` (C3). Interface copy moved to `fa/en/de.json` with stable keys and a localized `InfoPlist.xcstrings` (C1, C2, C4). Seed cards and content rules moved to `seed-cards.json` and `content-rules.json`. Remaining by design: SwiftData schema defaults, protocol and file-format identifiers. Remaining open: package-level defaults in `ProviderConfiguration` and `LinguaBrainAI` request parameters. |
| 3. Documentation | In progress. |
| 4. Feature 004 integration | Design pending approval. |
| B5 | Removed from the working tree and ignored; history unchanged. |
