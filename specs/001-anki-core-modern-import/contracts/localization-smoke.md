# Contract: Pre-T005 Interface Language and Language-Pair Smoke Gate

**Task**: T004A

**Status**: Complete

**Date**: 2026-08-17

## Purpose

Prove before modern-fixture work that interface language and learning direction are independent, persisted concepts. This prevents APKG fixtures and future Language Packages from inheriting a hidden German–Persian-only UI assumption.

## Accepted behavior

- The learner can change the application shell/settings language between English (`en`), German (`de`), and Persian (`fa`).
- English and German use left-to-right layout; Persian uses right-to-left layout.
- The selected interface language persists through reconstruction/restart.
- Explanation/source and learning/target language tags are selected independently from interface language.
- Source and target must differ; invalid equality is surfaced in settings.
- Switching interface language never mutates the selected learning pair.
- APKG fixture records carry explicit BCP 47 source and target tags.

## Fixture matrix

The owned synthetic fixture catalog generates real legacy APKG archives at test runtime:

| Fixture | Source | Target | Example |
| --- | --- | --- | --- |
| `sanitized-fa-de.apkg` | `fa` | `de` | کتاب → das Buch |
| `sanitized-en-de.apkg` | `en` | `de` | appointment → der Termin |
| `sanitized-de-en.apkg` | `de` | `en` | die Entscheidung → decision |

The catalog contains no personal learner data or third-party deck content. Generated archives are temporary test artifacts; the canonical, reviewable source is `Tests/Fixtures/multilingual-language-pairs.json` plus `APKGFixtureFactory.swift`.

## Scope boundary

This is a smoke gate for the application shell, language-settings surface, persistence, directionality, and import metadata. It does not claim that every prototype sentence has final professional English/German translation. Complete copy localization, accessibility review, and Language Package conformance remain DOC-18/M2 work.

## Evidence

- Five XCTest cases passed on iPhone 17 / iOS 27, including interface persistence/independence and all three generated APKG directions.
- The native macOS 27 target built successfully.
- No network or AI provider was used.
