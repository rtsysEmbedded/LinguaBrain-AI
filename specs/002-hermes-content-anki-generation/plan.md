# Implementation Plan: Hermes Content and Anki Generation

**Feature**: `002-hermes-content-anki-generation`
**Status**: Draft
**Specification**: [spec.md](spec.md)

## Summary

Implement a Swift-first, provider-agnostic content-generation vertical slice for Hermes. Swift owns orchestration, validation, approval, persistence, media ownership, and export boundaries. Agents may be in-process Swift or external services in another language behind a versioned JSON contract.

## Technical Context

- Swift 6.4, SwiftUI, iOS/iPadOS 27, and macOS 27.
- Existing `LinguaBrainKit` boundaries from ADR-010 and AI provider strategy from ADR-013.
- Existing domain concepts: `KnowledgeItem`, `LexicalSense`, `Sentence`, `MediaAsset`, `ReviewUnit`, and provenance.
- Local-first operation with Keychain credentials and optional cloud/local/on-device providers.
- GRDB 7/system SQLite is the production persistence direction; current prototype seams must remain migratable.
- TSV is the first export target; APKG export requires a separate round-trip gate.

## Constitution Check

| Gate | Result | Evidence / action |
| --- | --- | --- |
| Anki Core before expansion | Pass with dependency | This feature depends on the offline review gate and cannot weaken it. |
| Deterministic learning, optional AI | Pass | Providers create proposals only; Swift application validates and commits approved content. |
| Local-first privacy | Pass | Credentials use Keychain; text-only/no-AI fallback remains available. |
| Stable domain identity | Pass | Sense- and direction-aware identity is required. |
| Native Apple architecture | Pass | Swift-first app and application boundaries; external agents use contracts. |
| Evidence before completion | Planned | XCTest fixtures, iOS/macOS builds, and export round-trip checks are required. |

## Architecture and boundaries

```text
SwiftUI → Application Use Case → Generation Orchestrator (Swift)
                              → Provider Adapter / Versioned Contract
                              → Structured Proposal
                              → Validation + Duplicate Check
                              → Approval Transaction
                              → Domain/Persistence → Review and Export
```

The provider boundary is replaceable. No provider may access canonical storage or scheduling directly.

## Phase 0 — Research decisions

Resolve structured-output compatibility, provider error normalization, media cache ownership, TSV field conventions, and APKG export limitations. Record decisions in `research.md`.

## Phase 1 — Design artifacts

Create `data-model.md`, `contracts/generation-contract.md`, `contracts/export-contract.md`, and `quickstart.md`. Keep contracts versioned and implementation-language neutral.

## Phase 2 — Foundational implementation

Build domain/application ports, schema validation, identity/deduplication, job idempotency, provenance, secure credential access, and deterministic fake providers before UI integration.

## Phase 3 — User Story 1: Generate and approve

Implement request entry, proposal preview, per-card editing/rejection/approval, transactional persistence, and offline restart behavior.

## Phase 4 — User Story 2: Senses and media

Implement sense-aware card bundles, audio/image adapters, cache lifecycle, missing-media fallback, and offline playback.

## Phase 5 — User Story 3: Export

Implement provenance-aware TSV selection and export. Add APKG export only when collection/templates/media round-trip fixtures pass.

## Phase 6 — User Story 4: Provider interchangeability

Implement provider configuration, health checks, consent, retries, cancellation, remote contract fixture, and no-direct-mutation tests.

## Verification strategy

- Unit tests for schemas, normalization, identity, validation, duplicate detection, and provenance.
- Application tests using deterministic fake providers and failure fixtures.
- Persistence/restart tests with network disabled.
- SwiftUI preview and approval UI tests on iOS and macOS.
- TSV/APKG fixture round trips and RTL/LTR assertions.
- `xcodebuild` for the supported iOS and macOS schemes without private credentials.

## Risks and mitigations

- **Model output variance**: strict versioned schema, validator, and deterministic fixtures.
- **Provider lock-in**: adapter boundary and normalized proposal contract.
- **Incorrect polysemy**: stable `sense_key`, separate review identities, approval preview.
- **Media availability/cost**: independent media providers, cache, quota visibility, text-only fallback.
- **APKG fidelity**: TSV-first delivery and a separate round-trip acceptance gate.

