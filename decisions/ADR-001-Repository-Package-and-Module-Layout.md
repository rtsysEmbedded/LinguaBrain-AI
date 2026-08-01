---
title: "ADR-001: Repository, Package, and Module Layout"
status: superseded
date: 2026-07-19
superseded_by: ADR-010
superseded_date: 2026-07-21
decision_makers:
  - Software Architect
decision_ids:
  - LB-DEC-054
work_items:
  - LB-WI-M0-03
---

> [!IMPORTANT]
> This ADR is historical and was superseded by [ADR-010: Swift Package and Module Layout](ADR-010-Swift-Package-and-Module-Layout.md) on 2026-07-21. Its original decision and rationale are preserved below.

# ADR-001: Repository, Package, and Module Layout

## Context

LinguaBrain currently contains its product and technical specifications plus a small, previously untracked Python/FastAPI vocabulary prototype. M1 requires stable locations for a Flutter client, framework-independent learning logic, SQLite adapters, Language Packages, tests, and CI scope. Later client surfaces and an optional FastAPI sync service must be possible without making the local MVP depend on them.

The repository layout must enforce the existing architectural rules:

- domain and application logic remain independent of Flutter, SQLite, HTTP, AI SDKs, and platform plugins;
- the mobile application is a presentation surface and composition root, not the owner of learning rules;
- infrastructure implements inward-facing ports;
- German and Persian behavior remains outside the universal core;
- a future dedicated device can reuse the same learner identity, KnowledgeItems, LearningEvents, ReviewUnits, and planning contracts;
- specifications, ADRs, implementation, migrations, and tests can change atomically;
- experimental code cannot silently become production architecture.

The layout decision does not select Flutter state management, dependency injection, a SQLite library, an FSRS implementation, or encryption tooling. Those choices belong to later ADRs.

## Decision drivers

- Fast delivery of the M1 offline walking skeleton.
- Compile-time and test-time enforcement of dependency direction.
- One source of truth for specifications and implementation.
- Reuse by a future Flutter/Linux device without premature cross-runtime complexity.
- Independent replacement of SQLite, AI, FSRS, media, and platform adapters.
- Low coordination overhead while the project has one product and one primary implementation team.
- Explicit treatment of the existing vocabulary prototype.

## Decision

LinguaBrain will use one modular, polyglot Git monorepo. Deployable clients live under apps, reusable Dart/Flutter packages under packages, optional server processes under services, external schemas under contracts, non-production spikes under experiments, and repository automation under tooling.

The canonical target topology is:

    LinguaBrain AI/
    ├── apps/
    │   ├── mobile/                         # M1 Flutter reference client
    │   └── device/                         # Future; created only after approval
    ├── packages/
    │   ├── linguabrain_domain/             # Pure Dart domain model and contracts
    │   ├── linguabrain_application/        # Pure Dart use cases, ports, transactions
    │   ├── linguabrain_language_de/        # First-party German Language Package
    │   ├── linguabrain_language_fa/        # First-party Persian Language Package
    │   ├── linguabrain_persistence_sqlite/ # SQLite repositories, migrations, FTS, outbox
    │   ├── linguabrain_ai/                 # AI orchestration and provider adapters
    │   ├── linguabrain_review_fsrs/        # FSRS scheduler adapter and vectors
    │   ├── linguabrain_media/              # Media cache and playback adapters
    │   ├── linguabrain_platform_flutter/   # Secure storage, lifecycle, capabilities
    │   └── linguabrain_test_support/       # Synthetic fixtures, fakes, contract suites
    ├── services/
    │   └── sync_api/                       # Post-MVP FastAPI service
    ├── contracts/                          # Future external API/event schemas
    ├── experiments/
    │   └── vocabulary-mvp/                 # Python/FastAPI/n8n reference experiment
    ├── tooling/                            # Repository checks and developer commands
    ├── docs/
    ├── decisions/
    ├── diagrams/
    ├── assets/
    ├── README.md
    ├── PROJECT_STATUS.md
    ├── CHANGELOG.md
    ├── LICENSE
    └── .gitignore

This is a normative ownership and path map, not an instruction to create empty directories. A path is created when its milestone becomes active. M1 initially creates apps/mobile, linguabrain_domain, linguabrain_application, linguabrain_persistence_sqlite, and the minimum platform/composition adapters. M2 and M3 create their named packages when their contracts and ADRs are ready. Device, service, and external-contract paths remain documented reservations until approved work starts.

### Package granularity

Packages begin coarse-grained and use bounded-module folders internally. A bounded context does not automatically become a package. Extraction requires at least one concrete reason: a distinct dependency boundary, independent contract-test suite, separate platform capability, independently replaceable adapter, or separate release/runtime lifecycle.

The domain package groups pure Dart modules under named folders such as identity, knowledge, language contracts, graph, learning, review, planning, exercises, media contracts, and client context. It owns aggregate repository contracts required by domain semantics. The application package groups commands, queries, services, transactions, typed errors, orchestration, and use-case gateways for AI, media, secure storage, event dispatch, clocks, and external services.

A generic shared or utils package is prohibited. Code must have a named owner and architectural layer.

### Dependency rules

Allowed production dependencies are:

    apps/mobile -> linguabrain_application
    apps/mobile -> concrete adapter packages

    linguabrain_application -> linguabrain_domain

    linguabrain_language_de / linguabrain_language_fa
      -> language contracts and types in linguabrain_domain

    linguabrain_persistence_sqlite
      -> aggregate repository contracts and types in linguabrain_domain
      -> transaction/outbox ports in linguabrain_application

    AI / review / media / platform adapters
      -> use-case gateways in linguabrain_application
      -> types in linguabrain_domain

    linguabrain_domain
      -> Dart standard libraries only

The following dependencies are forbidden:

- domain to Flutter, SQLite, HTTP, provider SDKs, filesystem APIs, or platform plugins;
- application to presentation or concrete infrastructure;
- presentation to direct SQLite, FSRS, AI-provider, or secure-storage calls;
- production packages or release builds to experiments;
- the mobile client to a future backend for core offline learning;
- a future backend to private SQLite implementation details;
- production packages to linguabrain_test_support outside test/dev dependency scope.

Package names use the linguabrain_ prefix and snake_case. Public APIs are explicit; implementation details remain under lib/src. Dependency cycles are not allowed.

### Application and client surfaces

apps/mobile owns Flutter startup, dependency wiring, navigation, presentation, localization, accessibility, and the mobile ClientSurface adapter. It contains no canonical learning, scheduling, mastery, or validation rules.

A future Flutter/Linux device is added at apps/device with device-specific controls, power, audio, and hardware adapters. It imports the same domain and application packages. If later hardware cannot run Dart/Flutter, a separate ADR must decide whether it acts as a thin client or whether a cross-runtime core is justified.

### Future backend and contracts

FastAPI is not required by the MVP. If sync or shared services are approved, they live under services/sync_api and communicate through versioned schemas under contracts. The backend cannot become a prerequisite for local reviews and must not duplicate learning policy without a later accepted architecture decision.

### Testing and fixtures

- Unit and contract tests live beside each package.
- SQLite migration and transaction tests live in linguabrain_persistence_sqlite.
- Flutter widget, golden, and client integration tests live in apps/mobile.
- Cross-package synthetic fakes and fixtures live in linguabrain_test_support.
- Real learner content, API keys, databases, generated media, and unrestricted provider responses are prohibited in fixtures and Git.
- Tests must be able to run domain and application packages without Flutter, SQLite, or network access.

### CI and release scope

CI is path-aware:

- documentation changes run Markdown, link, traceability, and ADR/status checks;
- package changes run formatting, static analysis, unit/contract tests, and tests of affected dependents;
- mobile changes run Flutter analysis plus widget/golden/integration checks as appropriate;
- persistence changes run migration, transaction, restart, and recovery tests;
- experiment changes run a separate, non-release-blocking syntax/security smoke job unless explicitly promoted;
- future services use a separate service job and never become a prerequisite for the offline mobile test suite.

All MVP packages use repository-local workspace dependencies and are versioned together. Independent publishing and separate repositories require a new decision when team ownership or release cadence makes them necessary.

### Vocabulary prototype disposition

The former root vocabulary-mvp directory is classified as a non-production reference experiment and moved to experiments/vocabulary-mvp.

It validates a narrow Telegram/Excel to FastAPI to AI/SQLite to Anki flow. It does not implement the approved KnowledgeItem, LexicalSense, proposal/approval, Language Package, ReviewUnit, FSRS, LearningEvent, Knowledge Graph, Digital Twin, or outbox contracts.

Rules for the experiment:

- production code must not import it or depend on its API or database schema;
- it is excluded from the Dart workspace, application releases, production dependency graph, and default production CI;
- no real environment file, secret, bot token, learner database, log, n8n runtime state, generated import, or cache may be committed;
- generated vocabulary remains private and linguistically unverified;
- its SQLite database is never migrated directly into the production schema;
- reusable behavior is reimplemented behind approved production ports and tests rather than copied as an implementation shortcut;
- only documentation, security, and data-loss fixes are expected while it remains an experiment.

If legacy records must later be retained, a one-way importer is designed after Documents 16 and 18 stabilize. The importer must be idempotent, support a dry-run report, quarantine invalid or ambiguous records with machine-readable reasons, and require learner preview plus linguistic validation before acceptance. A legacy UUID is retained only as a provenance/external identifier; it never becomes a canonical production identifier. Records marked `schema_validated_unverified` may enter only as private, unverified proposals and never as canonical validated content. Import creates no mastery, ReviewUnit, FSRS, or LearningEvent history.

The experiment remains until the M2 production flow covers manual input, optional AI enrichment, approval, deduplication, provenance, and offline persistence. The M2 exit review must also decide the fate of the prototype-only Telegram and Anki integrations: archive them as reference evidence, create explicitly approved future backlog items, or deliberately retire them. The experiment is then archived or removed from the working tree after useful lessons and test cases are captured. Git history remains the permanent record.

The unrelated noji_anki directory remains ignored and outside this repository.

## Alternatives considered

### One Flutter application package

Rejected as the production baseline. It would be quick initially, but imports and tests would not adequately enforce independence from Flutter and concrete infrastructure. Shared-core extraction for a future device would become a risky later rewrite.

### Separate repositories for specifications, core, app, device, and backend

Rejected for the current phase. It creates version coordination, cross-repository changes, release management, and CI overhead without independent teams or release cycles. The option can be revisited when ownership and deployment cadence diverge.

### Cross-runtime native core such as Rust with FFI

Rejected as premature. It adds serialization, FFI, build, debugging, and platform complexity before dedicated-device hardware proves that pure Dart cannot satisfy the runtime constraints.

### Promote the Python prototype into production

Rejected. Its flat modules, automatic AI persistence, German-specific schema, and simple SQLite cache conflict with the approved domain, validation, learning, privacy, and persistence contracts.

### Move the prototype to a separate repository

Rejected for now. The experiment has no independent users, release lifecycle, or maintenance team. Keeping it under experiments preserves discovery evidence and traceability with less governance overhead.

## Consequences

### Positive

- Dependency direction is enforceable through package manifests and tests.
- Pure domain and application tests remain fast and framework-independent.
- Specifications and cross-package changes can be committed atomically.
- Mobile, future device, and future backend boundaries are explicit.
- Adapters remain replaceable without rewriting learning policy.
- The useful prototype is preserved without being mistaken for production code.
- Path-aware CI can avoid running unrelated stacks while protecting affected dependents.

### Negative

- The workspace has more manifests and dependency wiring than a single Flutter package.
- Cross-package refactoring requires deliberate public APIs and coordinated tests.
- Path-aware CI and dependency checks require repository tooling.
- The experiment has a separate technology stack that may need occasional security-only maintenance.
- A monorepo may become inefficient if independent teams and release cycles emerge.

### Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Excessive package count | Start coarse-grained; extract only for a named boundary. |
| Circular dependencies | Enforce the allowed dependency graph in CI. |
| A generic shared package accumulates unrelated code | Prohibit shared/utils catch-all packages. |
| Prototype code leaks into production | Forbid production dependencies on experiments and scan manifests/imports. |
| Future device needs another runtime | Keep contracts surface-neutral and require a later runtime ADR. |
| Monorepo CI becomes slow | Use affected-path/dependency jobs while retaining required integration gates. |

## Acceptance evidence

- ADR-001 is accepted and linked from the Decision Register.
- The canonical tree is identical in ADR-001, Document 11, and the root README.
- experiments/vocabulary-mvp exists with an explicit non-production notice.
- The old root vocabulary-mvp path no longer exists.
- noji_anki remains ignored and untouched.
- LB-DEC-054 is DECIDED and LB-WI-M0-03 is DONE.
- Markdown, local-link, JSON, Python syntax, Git-scope, and decision/backlog consistency checks pass.

## Follow-up actions

- [x] Relocate the vocabulary prototype to experiments/vocabulary-mvp.
- [x] Add experiment governance and a non-production notice.
- [x] Align Document 11, Document 15, the Decision Register, repository indexes, and project status.
- [ ] Create the M1 app and initial package manifests after the platform decision and ADR-002/ADR-003 are accepted.
- [ ] Add dependency-direction and affected-path CI checks with the M1 workspace.
- [ ] Review experiment retirement and the Telegram/Anki disposition at the M2 exit gate.
