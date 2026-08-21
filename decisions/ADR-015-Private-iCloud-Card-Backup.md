---
title: Private iCloud Card Backup
adr_id: ADR-015
status: accepted
date: 2026-08-21
decision_owners: Product and Architecture
---

# ADR-015 — Private iCloud Card Backup

## Context

Learners need their approved cards to survive app deletion and reinstallation before the full optional-account synchronization service in ADR-014 is ready. The native Apple client already has a local-first SwiftData store and must remain usable without a network or account.

## Decision

Add an opt-in CloudKit private-database backup for learner-created and Anki-imported cards. A versioned full snapshot is restored and merged into the local store, then the combined local snapshot is saved back to the learner's private iCloud database.

- Built-in demonstration and multilingual test cards are excluded.
- Local commits remain authoritative and do not wait for iCloud.
- Backup runs at launch/foreground when enabled and may be started manually in Privacy & Data.
- Card UUID and semantic identity prevent duplicate restoration.
- The CloudKit container is shared by the iOS/iPadOS and macOS targets.

## Explicit boundary

This is recovery-oriented card backup, not the complete Release 1.0 synchronization design. It does not yet synchronize FSRS/review events, profiles, settings, tombstones, account linking, or simultaneous multi-device edits. Those require the event/conflict/security work accepted by ADR-014.

## Consequences

Deleting and reinstalling the app can recover approved learner cards when the same iCloud account is available and backup had completed. Runtime verification requires a signed build whose Apple Developer profile contains the `iCloud.ai.linguabrain.prototype` CloudKit container.

The current local Xcode team is a Personal Development Team, which cannot provision iCloud. The entitlement file remains in the repository but is intentionally detached from the current targets until a paid Apple Developer Team registers the App ID and CloudKit container.
