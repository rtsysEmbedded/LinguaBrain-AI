---
title: "ADR-010: Swift Package and Module Layout"
status: accepted
date: 2026-07-21
decision_makers:
  - Software Architect
  - Apple Client Architect
decision_ids:
  - LB-DEC-054
supersedes: ADR-001
work_items:
  - LB-WI-M0-14
---

# ADR-010: Swift Package and Module Layout

## Context

LinguaBrain has adopted a native Swift and SwiftUI client for iOS, iPadOS, and macOS. The modular-monorepo intent of [ADR-001](ADR-001-Repository-Package-and-Module-Layout.md) remains valuable, but its Flutter application shell, Dart packages, and Flutter platform adapter no longer describe the production architecture.

M1 needs stable locations and enforceable dependency boundaries for:

- native application targets for iOS, iPadOS, and macOS;
- UI-independent domain and application logic;
- German and Persian language behavior;
- replaceable persistence, review, AI, media, and Apple-platform adapters;
- tests that can run without SwiftUI, SQLite, network access, or provider SDKs;
- the existing non-production vocabulary experiment;
- optional future services and interoperability contracts without making the offline app depend on a backend.

The repository must also preserve the future dedicated-device idea without claiming that a non-Apple device can directly reuse SwiftUI or Apple-only frameworks.

## Decision drivers

- Native SwiftUI delivery across the approved Apple platforms.
- Compile-time enforcement of inward dependency direction.
- Fast local builds and coherent cross-module refactoring during the MVP.
- One source of truth for specifications, ADRs, application code, migrations, tests, and tooling.
- Pure, deterministic domain and application tests.
- Replaceable infrastructure and provider integrations.
- Explicit separation between production code and experiments.
- A documented interoperability gate for any future non-Apple client or dedicated device.

## Decision

LinguaBrain remains one modular, polyglot Git monorepo. The native learner application lives under `apps/learner/`. Reusable production logic lives in one local Swift Package Manager package at `packages/LinguaBrainKit/`, with multiple named library targets that enforce the architectural boundaries. Optional server processes, external interoperability schemas, experiments, and repository tooling retain separate top-level ownership.

### Canonical target topology

```text
LinguaBrain AI/
├── apps/
│   └── learner/
│       ├── LinguaBrain.xcworkspace/          # Native workspace; generated user state is ignored
│       ├── LinguaBrain.xcodeproj/            # iOS/iPadOS and macOS app targets
│       ├── App/                              # SwiftUI app entry, scenes, navigation, presentation
│       ├── Resources/                        # Localizations, assets, privacy manifests, entitlements
│       ├── Tests/                            # App composition and platform integration tests
│       └── UITests/                          # Critical Apple-platform journeys
├── packages/
│   └── LinguaBrainKit/
│       ├── Package.swift
│       ├── Sources/
│       │   ├── LinguaBrainDomain/
│       │   ├── LinguaBrainApplication/
│       │   ├── LinguaBrainPresentation/
│       │   ├── LinguaBrainLanguageDE/
│       │   ├── LinguaBrainLanguageFA/
│       │   ├── LinguaBrainPersistence/
│       │   ├── LinguaBrainReviewFSRS/
│       │   ├── LinguaBrainAI/
│       │   ├── LinguaBrainMedia/
│       │   ├── LinguaBrainPlatformApple/
│       │   └── LinguaBrainTestSupport/
│       └── Tests/
│           ├── LinguaBrainDomainTests/
│           ├── LinguaBrainApplicationTests/
│           ├── LinguaBrainPresentationTests/
│           ├── LinguaBrainLanguageDETests/
│           ├── LinguaBrainLanguageFATests/
│           ├── LinguaBrainPersistenceTests/
│           ├── LinguaBrainReviewFSRSTests/
│           ├── LinguaBrainAITests/
│           ├── LinguaBrainMediaTests/
│           └── LinguaBrainPlatformAppleTests/
├── services/
│   └── sync_api/                             # Future; cannot be required for offline learning
├── contracts/                                # Future versioned external schemas
├── experiments/
│   └── vocabulary-mvp/                       # Reference-only Python/FastAPI/n8n spike
├── tooling/                                  # Repository validation, generation, and CI helpers
├── docs/
├── decisions/
├── diagrams/
├── assets/
├── README.md
├── PROJECT_STATUS.md
├── CHANGELOG.md
├── LICENSE
└── .gitignore
```

This tree is a normative ownership map, not an instruction to create empty directories. Paths are created only when their approved milestone begins.

### One Swift package, multiple targets

`LinguaBrainKit` is one local SwiftPM package during the MVP. Its targets are architectural modules, not separate repositories or independently versioned products. This keeps dependency rules visible while avoiding premature package, release, and workspace fragmentation.

A target may be extracted into a separate package only when measured evidence demonstrates a distinct release lifecycle, platform boundary, build-cost problem, independently consumed API, or separate ownership requirement. Extraction requires a new ADR.

### Module ownership

| Target or area | Owns | Must not own |
| --- | --- | --- |
| `LinguaBrainDomain` | Entities, value types, invariants, deterministic policies, domain errors, and domain repository contracts required by aggregate semantics | SwiftUI, Observation, SQLite, networking, filesystem APIs, AI/provider SDKs, Apple security APIs |
| `LinguaBrainApplication` | Commands, queries, use-case orchestration, transaction boundaries, application ports, clocks, event/outbox contracts, and capability-aware workflows | SwiftUI views, concrete databases, concrete provider SDKs, platform UI state |
| `LinguaBrainPresentation` | UI-facing state contracts, formatting-independent presentation models, navigation intents, and presentation coordination shared by Apple app targets | Persistence/provider implementations, canonical learning policy, direct platform service access |
| `LinguaBrainLanguageDE` / `FA` | First-party language rules, normalization, morphology, evaluation, and language-specific validation | Generic learning policy, persistence implementation, presentation navigation |
| `LinguaBrainPersistence` | The selected local persistence schema, migrations, repository adapters, transactions, indexing, and recovery primitives behind application/domain contracts | Canonical learning policy or UI behavior; commitment to a concrete stack before ADR-003 |
| `LinguaBrainReviewFSRS` | The selected review-scheduler adapter and serialization behind application/domain contracts | Presentation, learner-profile ownership, direct database mutation outside application transactions |
| `LinguaBrainAI` | Provider-independent AI adapter implementation, structured-output validation plumbing, routing, caching, and provider clients | Canonical fact promotion, mastery mutation, learning-plan decisions |
| `LinguaBrainMedia` | Media cache, playback/recording service adapters, and lifecycle implementation | Consent policy ownership or learning decisions |
| `LinguaBrainPlatformApple` | Keychain/security, lifecycle, capability, notifications, filesystem, and Apple-platform service adapters | Domain rules, app navigation, canonical learner data ownership |
| `LinguaBrainTestSupport` | Deterministic clocks, builders, fixtures, fakes, reference vectors, and contract-test helpers for test targets | Production behavior, mutable global test state, application-only secrets or private learner fixtures |
| `apps/learner` | SwiftUI scenes and views, platform-adaptive navigation, app state composition, dependency wiring, resources, entitlements, and app targets | Canonical learning, scheduling, validation, or persistence rules |

### Dependency direction

Allowed production dependencies point inward:

```text
apps/learner
    ├──> LinguaBrainApplication ──> LinguaBrainDomain
    ├──> LinguaBrainPresentation ─> LinguaBrainApplication + LinguaBrainDomain
    ├──> LinguaBrainLanguageDE ───> LinguaBrainDomain
    ├──> LinguaBrainLanguageFA ───> LinguaBrainDomain
    ├──> LinguaBrainPersistence ────────> application/domain contracts
    ├──> LinguaBrainReviewFSRS ─────────> application/domain contracts
    ├──> LinguaBrainAI ─────────────────> application ports + domain types
    ├──> LinguaBrainMedia ──────────────> application ports + domain types
    └──> LinguaBrainPlatformApple ──────> application ports + domain types

test targets ──> LinguaBrainTestSupport + the production target under test
```

Forbidden dependencies include:

- `LinguaBrainDomain` importing SwiftUI, Observation, SQLite libraries, URL-loading/provider SDKs, filesystem APIs, or Apple platform services;
- `LinguaBrainApplication` importing SwiftUI, concrete SQLite/provider implementations, or application-target types;
- any package target importing from `apps/learner`;
- production code importing from `experiments/`;
- direct adapter-to-adapter imports that bypass an application or domain contract;
- cyclic SwiftPM target dependencies;
- platform-specific conditionals inside domain rules.

Domain and application targets use pure Swift language and standard-library capabilities wherever possible. Foundation use must remain narrow, deterministic, and portable enough for package tests; Apple-only frameworks are forbidden in those two targets.

### Native application targets

`apps/learner` owns native app targets for iOS/iPadOS and macOS. Shared SwiftUI presentation may be reused when behavior is genuinely common, while scenes, commands, windowing, navigation, entitlements, permissions, and platform adaptations remain explicit at the application boundary.

The app target is the composition root. It selects concrete adapters and injects them through application ports. Views do not access SQLite, AI providers, secure storage, FSRS state, or canonical graph state directly.

### Persistence and transactions

Persistence remains behind repository and transaction ports. The application layer defines atomic use-case boundaries; the selected persistence adapter implements them. A UI action is not reported as successful until its required local transaction commits. The precise native Swift persistence/query/migration stack remains governed by the revised ADR-003; the target name does not preselect SQLite, SwiftData, Core Data, GRDB, or another implementation.

### AI and external services

AI remains an optional enhancement. Provider SDKs and network clients are confined to `LinguaBrainAI` or a future service adapter. AI output remains a proposal until deterministic validation and learner/system policy approve it. No provider or backend is required for core offline creation, browsing, planning, or review.

### Tests and CI scope

- Domain and application tests run without SwiftUI, SQLite, network access, provider SDKs, entitlements, or an Apple simulator.
- Each adapter target has contract tests against its inward-facing port.
- Persistence tests cover atomic transactions, migrations, restart durability, and recovery fixtures.
- Application-target tests cover dependency composition, SwiftUI state restoration, platform capabilities, localization, accessibility, and critical journeys.
- CI changes are path-aware but always run package-manifest and forbidden-import validation when dependency boundaries may change.
- Release workflows build and test every Apple platform promised by the accepted platform ADR.

### Experiments and excluded local projects

`experiments/vocabulary-mvp/` remains a non-production reference spike. It cannot define production schemas, module APIs, prompt contracts, migration history, or release behavior. Any useful lesson is re-specified and reimplemented behind current contracts rather than copied into production unchecked.

`noji_anki/` remains outside this repository's scope and ignored at the repository root. It is not moved, imported, or treated as a LinguaBrain package.

### Future services and interoperability

An optional `services/sync_api/` may be introduced only after its contracts and security model are approved. Offline learning remains complete without it. Cross-process schemas, when needed, live under `contracts/`, are versioned, and never become an excuse for UI-to-service coupling.

### Dedicated non-Apple device boundary

The domain concepts `ClientSurface`, `ClientContext`, and `CapabilitySnapshot` remain valid. However, this ADR does not promise that a future non-Apple device can import SwiftUI, Apple-platform adapters, or the Swift package directly.

Before implementing a non-Apple dedicated device, a future interoperability ADR must select and validate one of these strategies:

- a thin client consuming versioned local or remote contracts;
- a portable Swift subset with demonstrated toolchain/runtime support;
- a separately implemented core that conforms to shared schemas and deterministic reference vectors;
- another evidenced cross-runtime approach.

Whichever strategy is selected must preserve learner identity, KnowledgeItem semantics, LearningEvents, ReviewUnits, scheduling history, export/import compatibility, and deterministic policy vectors. It must not silently fork the learning model.

## Alternatives considered

### Keep the Flutter/Dart topology from ADR-001

Rejected because Flutter is no longer the selected production client stack. Retaining Dart package names and a Flutter platform adapter would make the repository map misleading and create dead production boundaries.

### Put all Swift code in one application target

Rejected. It would allow SwiftUI, persistence, AI, and platform APIs to leak into learning rules and would make deterministic package tests and future interoperability substantially harder.

### Create one Swift package per module immediately

Rejected for the MVP. It adds manifest, dependency-resolution, release, and coordination overhead before independent package lifecycles exist. One package with multiple targets enforces the required boundaries.

### Split iOS/iPadOS and macOS into separate repositories

Rejected. The products share one learner model, application use cases, language behavior, migrations, and release baseline. A monorepo allows specifications, code, tests, and migrations to change atomically.

### Introduce a cross-runtime core now for the dedicated device

Rejected as premature. The dedicated device is post-MVP, and no hardware/runtime evidence yet justifies serialization, FFI, RPC, or a second core implementation.

## Consequences

### Positive

- The repository reflects the accepted native Apple implementation stack.
- Pure Swift domain/application targets remain isolated from UI and infrastructure.
- iOS/iPadOS and macOS share one tested learning core and explicit composition root.
- Adapters can be replaced without changing canonical learning policy.
- Experimental and excluded projects cannot silently become production dependencies.
- A future device path remains possible without making an unsupported direct-reuse promise.

### Negative

- The workspace contains multiple targets and explicit dependency wiring.
- Engineers must maintain package-boundary tests and avoid convenience imports.
- Apple-native code does not automatically provide an Android or embedded client.
- A future non-Apple device requires an additional interoperability decision and evidence.

### Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| SwiftUI or Apple frameworks leak into learning logic | Forbidden-import checks and pure domain/application test jobs |
| Adapter targets become mutually coupled | Application-owned ports, dependency graph validation, and contract tests |
| One SwiftPM package becomes a monolith | Named bounded targets and evidence-based extraction rule |
| Platform differences are hidden behind unsafe conditionals | Explicit app-target adaptations and capability contracts |
| Future device work forks learner state | Versioned contracts, deterministic vectors, and mandatory interoperability ADR |
| Experiment code becomes an accidental baseline | Production import ban and one-way, validated reimplementation policy |

## Acceptance evidence

- LB-DEC-054 is `DECIDED` and links to this ADR.
- ADR-001 is marked `superseded` and links here without losing its original rationale.
- The canonical topology is reproduced consistently in the technical architecture and repository index.
- Production dependency rules prohibit SwiftUI, SQLite, and provider SDKs in domain/application targets.
- The vocabulary experiment and `noji_anki/` disposition remain explicit.
- Future non-Apple device implementation is gated by an interoperability ADR.

## Follow-up actions

- [ ] Create the workspace, native application targets, and local Swift package only when M1 begins.
- [ ] Add forbidden-import and SwiftPM dependency-cycle checks to CI.
- [x] Replace the active Flutter/Dart topology in the technical architecture and repository index.
- [ ] Accept ADR-011 before implementing SwiftUI state and dependency composition.
- [ ] Accept the revised ADR-003 before implementing persistence.
- [ ] Create a dedicated-device interoperability ADR before any non-Apple device implementation.

## References

- [ADR-001: Repository, Package, and Module Layout](ADR-001-Repository-Package-and-Module-Layout.md)
- [ADR-009: Native Apple Client and Platform Baseline](ADR-009-Native-Apple-Client-and-Platform-Baseline.md)
- [Decision Register](DECISION_REGISTER.md)
