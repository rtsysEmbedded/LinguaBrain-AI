---
title: "ADR-008: Initial Pilot and Golden Layout Platform"
status: accepted
date: 2026-07-20
decision_makers:
  - Product Owner
  - Flutter Architecture Lead
  - UX Lead
decision_ids:
  - LB-DEC-037
  - LB-DEC-053
work_items:
  - LB-WI-M0-12
---

# ADR-008: Initial Pilot and Golden Layout Platform

## Context

The MVP must choose whether its controlled learning pilot supports Android only or Android and iOS together. It must also name one deterministic rendering baseline for Flutter golden tests before M1 creates the application shell and bilingual UI fixtures.

The pilot exists to test the learning loop, not cross-store parity. Supporting two mobile platforms would add signing, distribution, permission, secure-storage, backup/recovery, accessibility, device, and release-policy matrices before the core hypothesis has evidence. At the same time, an Android-first release must not leak Android APIs into the domain/application core or prevent a later iOS client or dedicated device.

Golden images are sensitive to viewport, fonts, host operating system, and Flutter version. A single canonical fixture is therefore required, while responsive, accessibility, and real-device tests must still cover conditions that one bitmap cannot prove.

## Decision drivers

- Minimize the pilot matrix while preserving production-quality privacy, recovery, accessibility, and offline behavior.
- Reach the first delayed-recall pilot without duplicating platform work before the learning hypothesis is validated.
- Define a reproducible mixed Persian/German layout baseline before M1 UI implementation.
- Keep shared Flutter, domain, and application code portable to iOS and future client surfaces.
- Separate pixel-regression evidence from responsive, semantic, accessibility, and real-device acceptance.
- Avoid treating one screen size or one golden image as the supported-device contract.

## Decision

### Pilot platform

The controlled MVP pilot and M1–M6 mobile release gates target **Android phones only**.

- `apps/mobile` initially contains the Android Flutter host and shared Flutter presentation code.
- iOS is not an MVP build, distribution, CI, QA, or support commitment.
- The domain and application packages remain pure Dart and platform-neutral.
- Android-specific APIs and plugins remain inside the application shell or `linguabrain_platform_flutter` adapters behind application ports.
- No requirement, persistence schema, LearningEvent, ReviewUnit, or learner identity may encode Android-only semantics.
- The M1 toolchain baseline is Flutter `3.44.0`, Android `minSdk = 24`, `compileSdk = 36`, and `targetSdk = 36`.
- ADR-007 may raise the `minSdk` for an evidenced security or recovery requirement but may not lower it below the pinned Flutter release's supported floor.
- `compileSdk` and `targetSdk` are versioned build/release inputs, not Flutter deployment-support limits. They are reviewed before every distribution milestone; `targetSdk` must satisfy the then-current Google Play policy.

This decision does not promise iOS support after a particular date. It preserves a feasible path without adding an unverified release target to the MVP.

### Golden layout baseline

The canonical Flutter widget-golden fixture is:

| Property | Baseline |
| --- | --- |
| Platform behavior | `TargetPlatform.android`; selects Flutter adaptive behavior, not native-runtime fidelity |
| Design language | Material 3 |
| Surface | Android phone, portrait |
| Logical viewport | `360 × 800` logical pixels |
| Device-pixel ratio | `1.0` for deterministic widget goldens |
| Interface locale/direction | Persian (`fa`), RTL |
| Target-language content | German (`de-DE`) in explicit LTR/bidi-isolated spans |
| Theme | Light; deterministic theme tokens |
| Text scaling | `TextScaler.noScaling` for the canonical pixel image |
| Motion/time/data | Animations disabled or settled; fixed clock and synthetic fixtures |
| Insets | Versioned, fixed `MediaQuery` values supplied by the test harness |
| Fonts | Repository-bundled, explicitly loaded, license-approved font assets |

The Flutter SDK/engine artifacts, golden runner image, comparator configuration, font files and hashes, locale data, and fixture version are pinned in repository tooling before the first authoritative golden is accepted. Golden files are generated or updated only in that reference environment and reviewed as intentional visual changes.

Pixel-authoritative bilingual goldens remain **provisional** until LB-DEC-050 selects and licenses the Persian/German font pairing. M1 may establish the harness, layout tests, semantics tests, and non-authoritative snapshots before that decision.

### Required layout and accessibility matrix

The `360 × 800` baseline is not the only supported layout. M1 establishes the harness and applies it to the shell, onboarding, and first-item states available in that milestone. Every later critical MVP screen must pass the same matrix in the milestone that owns that screen.

| Fixture | Logical viewport | Required evidence |
| --- | ---: | --- |
| Compact floor | `320 × 568` | No clipped essential action or answer; scroll/focus remains usable |
| Canonical portrait | `360 × 800` | Reviewed golden plus widget and semantics assertions |
| Common larger phone | `412 × 915` | Responsive layout and mixed-direction assertions |
| Phone landscape | `800 × 360` | No orientation lock assumption; reachable controls and readable content |

Critical bilingual states must additionally test:

- Persian RTL page direction with German LTR words, forms, punctuation, numerals, and text fields;
- the versioned `normal` (`TextScaler.noScaling`) and `accessibility-2x` (`TextScaler.linear(2.0)`) widget fixtures;
- light and dark themes once theme tokens are stable;
- loading, empty, offline, error, validation-warning, and long-content states;
- semantics, logical focus order, non-color status cues, and touch-target constraints.

Goldens detect unintended rendering changes. They do not replace semantic assertions, accessibility checks, layout/property tests, or Android emulator/physical-device integration tests.

The application does not cap the learner's system text scaling. Android device QA separately tests the largest platform setting available in the pinned pilot-device matrix; the `accessibility-2x` widget fixture is a deterministic regression input, not a declared system maximum.

### Orientation and adaptive behavior

The canonical image is portrait, but the app is not hard-locked to portrait. Layout decisions use the available logical window size rather than a device-name check. The Android pilot remains phone-focused; tablet, foldable, and desktop-specific optimized experiences are not MVP release claims.

### iOS re-entry gate

iOS may enter an approved milestone only after a new decision confirms demand, ownership, and release scope. Before an iOS pilot or support claim, the project must add and verify:

- an iOS application host, signing, distribution, and supported-OS matrix;
- iOS secure-storage, database protection, backup/restore, lost-key, and deletion behavior;
- platform-specific permissions, privacy disclosures, and lifecycle behavior;
- mixed-direction typography, VoiceOver, dynamic text, focus/navigation, and device QA;
- pinned iOS widget/golden/integration fixtures and migration/restart tests;
- parity exceptions documented as product decisions rather than hidden implementation differences.

Android pilot data must remain portable through domain-level export/import contracts; no direct Android database copy is treated as the future iOS migration contract.

## Not decided here

This ADR does not close:

- LB-DEC-005: platform-secure storage APIs;
- LB-DEC-049: final navigation pattern;
- LB-DEC-050: Persian/German fonts and licenses;
- ADR-002: Flutter state management and dependency injection;
- ADR-003: SQLite/query/migration stack;
- ADR-007: local database protection, backup, recovery, key handling, and final Android SDK/security floor.

This ADR satisfies only the platform portion of LB-WI-M0-12. That work item remains `PROPOSED` until the font/license baseline, remaining M1-blocking decisions, approved specifications, and M1 issues are complete.

## Alternatives considered

### Android and iOS in the first pilot

Rejected for the MVP. It would measure the same learning hypothesis while doubling important platform-specific release and verification work. Cross-platform presentation code remains desirable, but release parity is not evidence needed for the first pilot.

### iOS-only pilot

Rejected. It offers no learning-validation advantage over Android while still requiring an Apple-only signing/distribution path and does not match the chosen Android-first delivery sequence.

### Platform-neutral goldens with no declared target platform

Rejected. Flutter adapts behavior and rendering by platform, so an unspecified target would create ambiguous snapshots and hide the product convention being tested.

### One screenshot size as the complete UI acceptance contract

Rejected. A single bitmap cannot verify responsive behavior, text scaling, semantics, focus order, screen readers, system insets, or real-device platform behavior.

### Device screenshots as the only golden source

Rejected as the default. They are valuable integration evidence but are less deterministic and slower than widget goldens. The project uses pinned widget goldens plus selected Android emulator/physical-device checks.

## Consequences

### Positive

- The MVP has one explicit release, security, accessibility, and recovery platform matrix.
- M1 can establish a deterministic visual test harness and shared bilingual fixtures.
- Android-specific concerns remain isolated behind ports and adapters.
- iOS can be added later without rewriting learner/domain state.
- Golden reviews have a named baseline and cannot silently vary by developer machine.

### Negative

- The first pilot does not include iPhone users.
- iOS-specific defects remain undiscovered until the re-entry gate is funded.
- Maintaining portable shared code requires discipline even when only Android ships.
- Additional layout and accessibility tests are still required beyond the canonical golden.

### Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Android-only shortcuts leak into shared code | Enforce package dependencies and adapter contract tests from ADR-001. |
| Golden files differ across hosts or SDK upgrades | Pin runner, Flutter SDK, fonts, locale, fixture, and rendering configuration. |
| Canonical viewport becomes a fixed-layout assumption | Require the companion viewport matrix and available-width layout logic. |
| Persian/German text snapshots churn before fonts are selected | Treat bilingual pixel goldens as provisional until LB-DEC-050 closes. |
| iOS is implied by Flutter even though it is untested | Make iOS explicitly unsupported for the MVP and require the re-entry gate. |
| Accessibility is mistaken for pixel similarity | Keep semantic, text-scale, contrast, focus, TalkBack, and device checks separate and mandatory. |

## Acceptance evidence

- LB-DEC-037 and LB-DEC-053 are `DECIDED` and link to this ADR.
- Documents 10 and 14 state the Android-only pilot and canonical golden fixture.
- Document 15 marks the platform gate resolved and ADR-002 work `READY`.
- `PROJECT_STATUS.md`, repository indexes, and `CHANGELOG.md` identify ADR-008 and the next decision gate.
- No iOS support claim or Android-specific core dependency is introduced.

## Follow-up actions

- [ ] Install and enforce Flutter `3.44.0`, Android `minSdk 24`, `compileSdk 36`, and `targetSdk 36` in the M1 workspace and CI.
- [ ] Implement the golden harness after ADR-002 establishes the composition/test boundary.
- [ ] Select and license bilingual fonts under LB-DEC-050 before accepting authoritative text goldens.
- [ ] Define Android protection, backup/recovery, and supported SDK/device constraints in ADR-007.
- [ ] Record an iOS re-entry decision before creating an iOS release target.

## References

- [Flutter supported deployment platforms](https://docs.flutter.dev/reference/supported-platforms)
- [Flutter Android development setup](https://docs.flutter.dev/platform-integration/android/setup)
- [Flutter adaptive and responsive layout guidance](https://docs.flutter.dev/ui/adaptive-responsive/general)
- [Flutter `matchesGoldenFile` API](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html)
- [Flutter `defaultTargetPlatform` API](https://api.flutter.dev/flutter/foundation/defaultTargetPlatform.html)
- [Flutter `TextScaler` API](https://api.flutter.dev/flutter/painting/TextScaler-class.html)
- [Flutter automatic platform adaptations](https://docs.flutter.dev/ui/adaptive-responsive/platform-adaptations)
- [Google Play target API requirements](https://developer.android.com/google/play/requirements/target-sdk)
