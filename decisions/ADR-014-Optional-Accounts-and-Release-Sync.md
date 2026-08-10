---
title: Optional Accounts and Release Sync
adr_id: ADR-014
status: accepted
date: 2026-08-10
decision_owners: Product and Architecture
---

# ADR-014 — Optional Accounts and Release Sync

## Context

LinguaBrain is local-first, but learners reasonably expect selected information to survive device loss and remain available across their Apple devices. Release 1.0 must support an optional account without turning authentication or network availability into a prerequisite for learning.

Google Sign-In is a third-party login service. App Store Review Guideline 4.8 therefore requires an equivalent privacy-preserving login option; Sign in with Apple is offered at the same prominence. An app that creates accounts must also let every learner initiate permanent account and associated-data deletion inside the app.

## Decision

This decision supersedes only ADR-009's statement that accounts and cross-device synchronization are post-MVP/local-only release exclusions. ADR-009 remains authoritative for the native Apple platform, capability, layout, and stable-toolchain baseline.

Release 1.0 will provide three entry modes:

1. **Continue without an account** — full local Anki Core and review functionality.
2. **Sign in with Apple** — native AuthenticationServices flow.
3. **Sign in with Google** — equivalent optional identity flow.

An internal `LearnerAccount` is the canonical identity. Apple and Google identities are external credentials linked to that account; neither provider identifier becomes a domain aggregate identifier.

Signing in after local use performs an explicit, transactional merge. It must not replace or silently discard local cards, review history, or settings. Signing out leaves a usable local snapshot and clearly explains which later changes will not synchronize.

## Initial synchronization scope

The first release may synchronize:

- learner profile, native/target language, goals, and preferences;
- decks, cards, lexical senses, examples, tags, and import provenance;
- immutable learning/review events and current FSRS projections;
- daily-plan preferences and non-sensitive progress summaries;
- tombstones required to propagate deletions.

The following never synchronize through the learner-data service:

- OpenRouter or other BYOK API keys;
- Keychain secrets, provider refresh tokens, or raw authentication credentials;
- transient AI request bodies or provider responses unless the learner explicitly approves them as card content;
- microphone recordings, meeting transcripts, or private notes until a separate retention/encryption decision is accepted.

## Security and lifecycle requirements

- Provider credentials are verified server-side and exchanged for short-lived, revocable application sessions.
- Refresh credentials use platform-secure storage and are never stored in the learner database.
- Every server operation enforces ownership by canonical account ID.
- Network transport uses TLS; server-side storage protection, backup, audit, incident response, and field-level encryption require a dedicated security design before launch.
- Account linking requires recent authentication and prevents one external identity from silently attaching to two accounts.
- The app exposes export, sign-out, unlink-provider, and permanent account deletion in Account Settings.
- Deletion removes cloud data and revokes Sign in with Apple tokens where applicable. Local data deletion is a separate explicit choice so its effect is understandable.
- Privacy Policy and App Privacy disclosures cover both identity providers and the synchronization service.

## Conflict and offline behavior

- Local writes commit before synchronization and remain available offline.
- Stable UUIDs, versioned events, idempotency keys, and tombstones are mandatory.
- Learning events are merged rather than resolved by last-write-wins.
- User edits outrank unapproved AI enrichment; conflicts that cannot be resolved deterministically are surfaced rather than discarded.
- The server does not independently recalculate or mutate learning state without a versioned application command and auditable event.

## Deferred implementation choices

This ADR does not select the backend hosting vendor, database, Google SDK versus standards-based OIDC adapter, token format, encrypted backup design, or detailed conflict algorithm. Those choices require a sync/security ADR and threat model before implementation becomes release-ready.

## Consequences

- Account and sync are now Release 1.0 scope, but remain optional for the learner.
- A secure backend, identity verification, merge/migration tests, account deletion, privacy disclosures, and operational monitoring become release blockers.
- The local-first Learning Engine and Anki review path remain usable when signed out or offline.
- Release scope grows materially; deferring accounts again requires an explicit product decision rather than silent removal.

## Acceptance evidence

- Local-only onboarding and review work with no network or account.
- A learner with local history signs in with Apple or Google and retains all local data.
- A second device receives the same approved cards and review history without duplication.
- Concurrent reviews preserve all learning events and produce a documented deterministic projection.
- Sign-out, reauthentication, provider linking, revoked credentials, and offline recovery pass tests.
- In-app deletion revokes applicable credentials and removes server data within the disclosed period.

## References

- [App Review Guidelines — Login Services](https://developer.apple.com/app-store/review/guidelines/)
- [Authentication Services](https://developer.apple.com/documentation/authenticationservices/)
- [Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [TN3194 — Handling account deletions and revoking tokens for Sign in with Apple](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple)
