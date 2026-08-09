# Changelog

All notable changes to this documentation repository are recorded in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- A 50-word German–Persian functional-test dataset and shared resettable prototype state across Today, Library, Review, and Progress.
- ADR-012 and the Anki Core MVP specification, establishing secure APKG import and durable offline review as the validation gate before AI card generation and final visual approval.
- MVP card inventory and interactive SwiftUI gallery covering word, noun, verb, recognition, reverse translation, cloze, listening, feedback, daily-plan, and skill-mastery surfaces.
- Buildable native SwiftUI visual prototype for iPhone, iPad, and Mac, covering onboarding, daily check-in, dashboard, library, mock word generation, review, progress, and settings.
- Xcode workspace with separate `LinguaBrain` and `LinguaBrain Mac` schemes plus prototype run instructions.
- Initial Git-ready documentation repository structure.
- Central `PROJECT_STATUS.md` checklist for completed work, remaining work, milestone gates, and maintenance rules.
- Document 15 implementation backlog with stable requirement/work-item identifiers, milestone dependencies, acceptance evidence, test catalog, and requirements traceability matrix.
- Decision Register covering all 53 source open questions plus six supplemental architecture decisions (59 stable IDs), with classifications, statuses, owners, due gates, decision clusters, and the planned ADR queue.
- ADR-001 preserving the now-superseded Dart/Flutter monorepo topology and the still-valid vocabulary-prototype boundary.
- ADR-008 preserving the now-superseded Android-phone pilot and golden-layout decision as historical evidence.
- ADR-009 replacing ADR-008 with a native Swift/SwiftUI client baseline for iOS/iPadOS 27 and macOS 27 Golden Gate.
- ADR-010 replacing ADR-001's Dart/Flutter topology with an Xcode and Swift Package Manager module layout.
- ADR-011 defining native Observation state, typed scene-owned navigation, initializer injection, and the SwiftUI application composition root.
- Experiment governance for non-production research spikes.
- Product Vision specification.
- Complete product and technical specifications for documents 02 through 14.
- Domain contracts for LexicalSense, ReviewUnit, revisions, proposals, learning plans, and pipeline jobs.

### Changed

- Replaced fixed prototype button intervals with deterministic FSRS-6 scheduling using persisted stability, difficulty, phase, elapsed time, algorithm version, and official reference vectors.
- Persisted prototype review history and due dates with SwiftData so ratings, progress, and the review queue survive app restarts; review success is now shown only after the transaction is saved.
- Added prototype due dates and a time-aware review queue: Again and Hard cards return only when their displayed interval becomes due, while the session waits and resumes automatically when no other card is available.
- Review ratings now update word strength, reviewed/weak/due counts, and progress summaries across the running prototype; Progress includes an explicit reset action.
- Made the visual prototype review session interactive: answer reveal now enables rating actions, each rating advances the queue, and session completion shows a rating summary with restart support.
- Redesigned the SwiftUI settings experience as a clear Apple-style control center with a profile summary, learning-path overview, grouped navigation, and focused detail screens.
- Hardened `.gitignore` for excluded local projects, environment secrets, Python artifacts, local databases, generated output, and runtime files.
- Reviewed all specifications for cross-document consistency and implementation readiness.
- Clarified that media and exercises are resources/activities rather than KnowledgeItems.
- Resolved FSRS scheduling at the learner/objective ReviewUnit level.
- Defined authoritative validation versus learner-accepted private content.
- Aligned MVP scope, no-AI fallback, daily check-in defaults, privacy, and pilot metrics.
- Added minimal ClientSurface, CapabilitySnapshot, and consent-gated audio-pipeline extension points for future dedicated hardware while keeping hardware outside the app MVP.
- Aligned architecture-decision timing: M1-blocking ADRs remain M0 gates, while FSRS and ReviewUnit evidence-mapping ADRs are hard-gated before M3.
- Marked `LB-DEC-054` as `DECIDED` and `LB-WI-M0-03` as `DONE`; aligned DOC-11, DOC-15, the project checklist, and repository indexes with ADR-001.
- Relocated the untracked `vocabulary-mvp/` prototype to `experiments/vocabulary-mvp/` and marked it reference-only.
- Excluded experiment-local spreadsheet inputs and generated CSV exports from Git.
- Hardened the reference experiment by binding n8n to loopback, disabling persisted execution payloads, documenting Telegram-token exposure risks, and defining a safe one-way import/retirement contract.
- Marked `LB-DEC-037` and `LB-DEC-053` as `DECIDED`, made `LB-WI-M0-04` ready for ADR-002, and aligned Documents 10, 14, and 15 with the Android-first platform decision.
- Superseded the Android/Flutter platform choice and Dart package topology while preserving ADR-001 and ADR-008 as historical records.
- Reframed the MVP as native Swift 6.4 and SwiftUI on iOS/iPadOS 27 and macOS 27, with iPhone as the primary pilot and local-only iPad/Mac surfaces.
- Added capability-gated Foundation Models, SpeechAnalyzer, Translation, Keychain, Swift concurrency, VoiceOver, Dynamic Type, and Apple release/toolchain boundaries to the active specifications.
- Replaced Flutter work items and decision gates with SwiftUI state/composition and native Swift persistence decisions; Xcode 27 beta work remains provisional until stable OS/toolchain verification.
- Replaced Flutter/Dart generated-file ignores with SwiftPM/Xcode/DerivedData/archive ignores while keeping source projects and resolved dependencies trackable.
- Recorded the local Apple-toolchain audit: macOS 27 on Apple silicon and Swift 6.4 are available, but full Xcode 27 is not yet the active developer directory.
- Activated and verified Xcode 27.0 build `27A5228h` with Swift 6.4 and version 27 iPhoneOS, iPhone Simulator, and macOS SDKs.
- Closed LB-DEC-058 and advanced the active architecture queue to ADR-003 for the native Swift persistence stack.
