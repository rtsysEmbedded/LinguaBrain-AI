# Codebase Reality Audit

**Date:** 2026-08-25  
**Scope:** Native Apple learner app and `LinguaBrainKit`  
**Purpose:** Keep implementation status separate from aspirational specifications.

## Confirmed implemented

- Legacy APKG inspection/import preview.
- Prototype offline review with direct/reverse directions and four FSRS ratings.
- SwiftData review persistence and restart restoration in the current prototype.
- Structured card proposal decoding/validation and provider boundaries.
- OpenAI-compatible provider configuration, separate text/audio/transcript/live-stream settings.
- Basic multi-sense preview/approval, multilingual interface resources, mixed practice, and card-only CloudKit backup.

## Confirmed incomplete or problematic

1. Feature 003 APKG export is not isolated cleanly from the main package build. Its package resources/target configuration can break `swift test`; export selection still contains placeholder source-group and deck filters.
2. Production persistence is not implemented. `LinguaBrainPersistence` currently exposes a deferred `PersistencePort` seam while the app uses the SwiftData `PrototypeStore`; GRDB/SQLite repositories and migrations are not wired into the app.
3. Runtime learning state is primarily card/mode/FSRS state. Independent `LearningObjective`, `SkillMastery`, immutable `LearningEvent`, and per-skill mastery are not yet implemented end-to-end.
4. Adaptive planning is incomplete. Daily energy/time UI exists, but deterministic candidate ranking, weak-skill targeting, explainable recommendations, and an auditable Digital Twin are not complete.
5. The language package layer is not a full German/Persian morphology/grammar engine; many language facts remain card fields or provider output.
6. CloudKit currently backs up cards, not review events, FSRS state, tombstones, or concurrent multi-device conflicts.
7. `ProposalDecoder` constructs senses without carrying source/target language tags; language context is repaired later and must be made part of the contract.

## Release impact

The current product is an offline Anki/review prototype with AI-assisted card generation. It is not yet the final personalized learning engine. Apple Developer account-dependent work (signed device QA, Sign in with Apple, production iCloud entitlements, and App Store release) is explicitly deferred.

## Next implementation sequence

1. Keep Feature 003 out of the default build/test path until its fixtures and target boundary are complete.
2. Stabilize the local persistence/review boundary and preserve restart semantics.
3. Implement objective-level learning events and skill mastery.
4. Build deterministic adaptive card/exercise selection from those events.
