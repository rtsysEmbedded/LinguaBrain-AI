# LinguaBrain AI — Technology Stack and Update Register

**Status:** Active reference  
**Last reviewed:** 2026-08-22  
**Review cadence:** Before every release and at least once per quarter  
**Owner:** LinguaBrain maintainers

This file is the single source of truth for technologies used by LinguaBrain AI. A technology must not be upgraded only because a newer version exists. Every upgrade requires a compatibility review, tests, and a recorded result in the change log.

## Current verified beta baseline

| Component | Verified value |
|---|---|
| Host macOS | 27.0 beta (`26A5416b`) |
| Xcode | 27.0 beta (`27A5228h`) |
| Apple Swift | 6.4 (`6.4.0.27.1`) |
| macOS SDK | 27.0 |
| iOS/iPadOS SDK | 27.0 |

This is an operational constraint, not just documentation. Before editing platform-sensitive code, inspect the matching declaration in the installed Xcode SDK and check the current official documentation or release notes. Old examples are not evidence that an API is correct for OS 27. If the installed versions change, update this table first and re-run the affected compatibility checks.

## Current stack

| Area | Technology | Version / policy | Where it is used | Update risk |
|---|---|---|---|---|
| Apple app | Swift | Swift 6 language mode | iOS/iPadOS and macOS app and local packages | High |
| UI | SwiftUI | SDK version supplied by Xcode | Native Apple user interface | Medium |
| Observation | Observation framework | Apple SDK | Observable application state | Medium |
| Apple platform SDK | iOS/iPadOS 27 | Deployment target in app project | iPhone/iPad product | High |
| Apple platform SDK | macOS 27 | Deployment target in app project | Mac product | High |
| IDE/toolchain | Xcode 27 | Pin and verify per release | Build, test, signing, previews | High |
| Package manager | Swift Package Manager | `swift-tools-version: 6.4` | `packages/LinguaBrainKit` | High |
| Persistence | SwiftData | Apple SDK | Local cards, reviews, user learning state | High |
| Cloud sync | CloudKit | Apple SDK | Optional card/account backup and sync | High |
| Review scheduling | FSRS-6 | `FSRS-6.0/default-21` | Spaced repetition scheduling | High |
| Speech, local | SpeechAnalyzer / SpeechTranscriber | Apple SDK | On-device transcription | High |
| Audio capture | AVFoundation / AVCaptureSession | Apple SDK | Microphone capture and input meter | High |
| Audio transcription, cloud | OpenAI Realtime transcription | GA WebSocket protocol | Streaming cloud transcription | High |
| Cloud transcription models | OpenAI transcription models | Selected after `/v1/models` test | `gpt-4o-transcribe`, `gpt-4o-mini-transcribe`, `whisper-1`, diarization where available | High |
| AI text provider | OpenAI-compatible HTTP API | Provider-configured | Card generation, examples, translation | High |
| Networking | URLSession / URLSessionWebSocketTask | Apple SDK | HTTP, SSE, and Realtime WebSocket calls | Medium |
| Security | Keychain Services | Apple SDK | Local API-key storage | High |
| Localization | `.xcstrings` plus JSON catalogs | Project convention | Persian, English, German UI | Medium |
| Testing | XCTest / Swift Testing | Xcode toolchain | Unit, integration, and regression tests | Medium |
| Distribution | App Store Connect / Developer ID | Apple release tooling | iOS/iPadOS and macOS releases | High |

## Repository locations

- App target and platform settings: `apps/learner/LinguaBrain.xcodeproj`
- Swift package manifest: `packages/LinguaBrainKit/Package.swift`
- Swift package source: `packages/LinguaBrainKit/Sources/`
- App source: `apps/learner/App/`
- Entitlements and resources: `apps/learner/Resources/`
- Architecture decisions: `decisions/`
- Product and technical specifications: `docs/`
- Feature specifications and tasks: `specs/`

## Required update process

Run this process before each release and during the quarterly technology review.

### 1. Inventory

Confirm that this table still matches the codebase. Search for imports, package dependencies, SDK deployment targets, model identifiers, and external endpoints.

```bash
rg --glob '*.swift' '^import ' apps packages
rg -n 'swift-tools-version|\.package\(|IPHONEOS_DEPLOYMENT_TARGET|MACOSX_DEPLOYMENT_TARGET|SWIFT_VERSION' \
  packages apps/learner/LinguaBrain.xcodeproj/project.pbxproj
```

### 2. Check official release notes

Check only the primary source for each technology:

- Apple SDKs and Xcode: Apple Developer documentation and Xcode release notes
- Swift and Swift Package Manager: Swift.org release notes
- OpenAI API and Realtime: official OpenAI API documentation
- FSRS: the pinned algorithm reference and implementation changelog
- CloudKit and App Store requirements: Apple Developer documentation

Record any relevant breaking change, deprecation, entitlement change, model change, or minimum OS change before editing code.

### 3. Compatibility branch

Create a branch named:

```text
chore/technology-review-YYYY-MM
```

Apply upgrades one technology family at a time. Do not combine an Xcode/SDK upgrade with a persistence migration or an AI protocol migration unless the change is inseparable.

### 4. Required verification

At minimum, run:

```bash
swift test --package-path packages/LinguaBrainKit
xcodebuild -project apps/learner/LinguaBrain.xcodeproj \
  -scheme LinguaBrain -sdk iphonesimulator -configuration Debug \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project apps/learner/LinguaBrain.xcodeproj \
  -scheme 'LinguaBrain Mac' -sdk macosx -configuration Debug \
  CODE_SIGNING_ALLOWED=NO build
```

For changes involving microphone, SpeechAnalyzer, CloudKit, authentication, or Realtime:

- test on a physical iPhone/iPad where applicable;
- test on the supported Mac target with the built-in microphone;
- test offline behavior;
- test migration of an existing local database;
- test the current and fallback AI provider paths;
- verify that no API key is logged or bundled.

### 5. Record the result

Update this file's `Last reviewed` date and add an entry to `CHANGELOG.md`. The entry must include:

- technology and old/new version;
- reason for the change;
- affected modules;
- migration or compatibility notes;
- tests executed;
- rollback plan if the change is risky.

## Release gates

A technology update is not complete until all applicable answers are “yes”:

- [ ] The official release notes were reviewed.
- [ ] The supported deployment targets remain intentional.
- [ ] Existing data and CloudKit records remain readable.
- [ ] iOS/iPadOS and macOS builds succeed.
- [ ] Unit and integration tests pass.
- [ ] Realtime/audio paths were tested if affected.
- [ ] Localization remains complete in Persian, English, and German.
- [ ] Privacy, entitlement, and signing changes were reviewed.
- [ ] `CHANGELOG.md` and this register were updated.

## Known watch items

### Apple SDK and Xcode

SpeechAnalyzer, AVFoundation audio routing, SwiftUI Observation, CloudKit entitlements, and macOS microphone behavior are platform-sensitive. Treat every major Xcode or OS update as a compatibility change, not a routine dependency bump.

### OpenAI Realtime

The app uses a transcription-only Realtime WebSocket session. Keep the WebSocket session schema, audio format, event names, authentication method, and supported transcription model list aligned with the current official API reference. Never assume that a model returned by a general `/models` endpoint is valid for the selected Realtime session.

### FSRS

The current scheduler is intentionally pinned to `FSRS-6.0/default-21`. An algorithm upgrade requires reference-vector tests and a documented migration strategy for existing memory states.

### CloudKit and local persistence

Schema changes must be additive or include an explicit migration. Existing users must not lose cards, review history, learning states, or account links after an app update.

## Change log template

Copy this section into `CHANGELOG.md` for each review:

```text
Technology review: YYYY-MM-DD
- Reviewed:
- Updated:
- Deferred:
- Compatibility result:
- Tests:
- Follow-up:
```
