# Spec Kit Workflow for LinguaBrain AI

This repository uses GitHub Spec Kit as the execution layer for feature work. Existing product documents and ADRs remain authoritative; Spec Kit converts them into bounded, testable feature slices that can be handed to Codex, Claude, Gemini, or another compatible agent.

## Source-of-truth order

1. [Project constitution](.specify/memory/constitution.md)
2. Accepted [architecture decisions](decisions/DECISION_REGISTER.md)
3. Baseline [product and engineering documents](docs/)
4. Feature `spec.md` — required behavior and acceptance outcomes
5. Feature `plan.md` — approved technical approach
6. Feature `tasks.md` — executable work packages

An agent must report a conflict rather than silently override a higher-level source.

## Feature lifecycle

Each feature lives at `specs/NNN-feature-name/` and normally contains:

```text
spec.md          # User value, scenarios, requirements, success criteria
plan.md          # Architecture, boundaries, files, tests, risks
research.md      # Optional decisions and evidence
data-model.md    # Optional feature data model
contracts/       # Optional external or internal contracts
quickstart.md    # Optional verification/demo path
tasks.md         # Ordered, independently assignable tasks
checklists/      # Optional requirement-quality checks
```

Run the workflow in this order: specify → clarify when needed → plan → checklist when useful → tasks → analyze → implement → converge. Update `PROJECT_STATUS.md` and `CHANGELOG.md` when verified work changes project state.

## Configured AI integrations

- Codex: `.agents/skills/`; use `$speckit-specify`, `$speckit-plan`, and `$speckit-implement`.
- Claude Code: `.claude/skills/` with corresponding Spec Kit workflow names.
- Gemini CLI: `.gemini/commands/`; use `/speckit.specify`, `/speckit.plan`, and `/speckit.implement`.

The shared `.specify/` directory and feature artifacts are agent-neutral. Do not maintain separate specifications for each AI.

Codex CLI and Claude Code are available on the current development machine. Gemini's repository commands are ready, but its CLI must be installed and authenticated before they can run locally.

## Multi-agent assignment contract

Every assignment should include:

```text
Feature: 001-anki-core-modern-import
Tasks: T005, T006
Allowed write scope: exact files/directories
Required evidence: named tests/builds
Do not change: architecture, unrelated files, accepted requirements
Handoff: changed files, results, risks, commit SHA
```

Tasks marked `[P]` may run in parallel only when their file scopes do not overlap. If two tasks need the same file, serialize them or create an explicit integration task. Never ask two agents to independently rewrite the same feature artifact.

## Completion rules

A task is complete only when acceptance criteria pass, required tests/builds succeed, documentation/status is updated, staged files contain no secrets or unrelated changes, and the handoff includes evidence.

## Current feature

[001 — Anki Core Modern Import](specs/001-anki-core-modern-import/spec.md) is the first Spec Kit feature. It closes the current product gate before broader AI enrichment and final visual design.
