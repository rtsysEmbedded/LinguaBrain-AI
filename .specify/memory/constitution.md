# LinguaBrain AI Constitution

## Core Principles

### I. Specifications Are the Shared Contract

Every implementation change MUST be traceable to an approved feature specification and task. The authority order is: this constitution, accepted ADRs, baseline product documents, the feature `spec.md`, the feature `plan.md`, and finally `tasks.md`. An AI agent MUST report a conflict instead of silently choosing a lower-authority instruction. Material architecture or product-scope changes require an ADR and matching documentation updates.

### II. Anki Core Before Expansion

Release work MUST first preserve a reliable, offline Anki-compatible learning loop: safe import, durable cards and lexical senses, due-queue review, four FSRS ratings, reverse translation, restart persistence, and deterministic re-import. AI generation, account sync, final visual polish, OCR, and dedicated-device work MUST NOT weaken or bypass this gate. Each vertical slice MUST remain independently demonstrable on supported Apple platforms.

### III. Deterministic Learning, Optional AI

The Learning Engine owns scheduling, mastery, session construction, and educational decisions. AI providers may propose content, classification, feedback, or relations, but MUST NOT directly mutate canonical knowledge, review history, mastery, or schedules. AI output MUST use validated structured contracts, retain provider/model/prompt provenance, require approval where specified, and have a usable offline or no-AI fallback for core learning.

### IV. Local-First Privacy and Learner Ownership

The signed-out app MUST provide the complete local learning loop. Learner data belongs to the learner and MUST support export and verified deletion. Secrets belong in Keychain or equivalent secure platform storage and MUST never enter Git, logs, prompts, fixtures, or plain local configuration. Cloud AI, speech capture, accounts, and synchronization require explicit consent, least-data disclosure, clear failure behavior, and revocable access.

### V. Stable Domain Identity and Auditable State

Identity MUST represent meaning, not only spelling: separate lexical senses such as work and medical meanings of the same surface form may coexist. Review state belongs to a stable learner/objective ReviewUnit. LearningEvents and import provenance MUST make schedule and mastery changes reproducible. Re-imports, retries, and migrations MUST be idempotent or explicitly reconciled; exposure alone MUST NOT advance mastery.

### VI. Native Apple Architecture with Portable Semantics

The active client baseline is Swift 6.4 and SwiftUI for iOS/iPadOS 27 and macOS 27. Domain and application logic MUST remain independent of SwiftUI, storage frameworks, and individual AI providers through explicit interfaces and adapters. Apple-specific capabilities MUST be availability- and locale-gated. Portable, versioned domain semantics MUST be retained for a future dedicated device or non-Apple client without expanding the current MVP.

### VII. Evidence Before Completion

Tests and verification are part of every task, not follow-up work. Changes to scheduling, import, persistence, identity, security, or migrations require automated tests and relevant fixtures. A task is complete only when its acceptance criteria pass, affected Apple targets build, documentation/status are updated, and no secrets or unrelated generated files are staged. Failures MUST be reported with reproducible evidence.

## Multi-Agent Delivery Rules

- One feature is developed in one `specs/NNN-feature-name/` directory.
- Every coding assignment references one or more stable task IDs from that feature's `tasks.md`.
- Agents MUST inspect current Git status before editing, preserve user changes, and avoid files owned by another active task unless coordination is explicit.
- Parallel tasks MUST have non-overlapping write scopes or an explicit integration task.
- Each handoff records changed files, tests/builds run, unresolved risks, and the commit SHA when committed.
- Agents MUST NOT mark checklist items complete without verification evidence.
- Generated AI output is a proposal; repository files and accepted decisions remain the source of truth.

## Quality and Security Gates

- Use Swift concurrency safely and keep UI-facing mutable state on `@MainActor`.
- Keep UI, application, domain, persistence, review, language, media, and AI-provider boundaries explicit.
- APKG import MUST be read-only during inspection, bounded against hostile archives, transactional on commit, and covered by corrupt/traversal/archive-bomb/duplicate fixtures.
- FSRS behavior MUST remain pinned, versioned, deterministic under a fake clock, and independently persisted per review objective.
- Accessibility MUST cover Dynamic Type, VoiceOver, keyboard operation where applicable, and mixed Persian/German RTL/LTR content.
- Build and test commands MUST be repeatable from a clean checkout without private credentials.

## Spec Kit Workflow

New feature work follows: constitution → specify → clarify when needed → plan → checklist when useful → tasks → analyze → implement → converge. Existing reviewed documents are not duplicated into every feature; feature artifacts link to the relevant clauses and ADRs. The current project-wide progress source remains `PROJECT_STATUS.md`, while feature execution state lives in each `tasks.md`.

## Governance

This constitution governs all human and AI contributors. Amendments require a documented reason, review of affected specs/templates, a migration note for active features, and a semantic version change. Accepted ADRs may specialize this constitution but may not contradict it; a contradiction requires a constitution amendment first. Pull requests and direct commits MUST verify constitution compliance. Complexity beyond the approved plan requires a written justification in the feature plan.

**Version**: 1.0.0 | **Ratified**: 2026-08-16 | **Last Amended**: 2026-08-16
