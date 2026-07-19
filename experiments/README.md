# Experiments

This directory contains non-production prototypes and research spikes. Experiments preserve evidence and test ideas, but they are not product modules.

## Rules

- Production applications, packages, services, and release builds must not depend on experiment code, APIs, or schemas.
- Experiments are excluded from the production dependency graph and default release CI.
- No secrets, real environment files, learner databases, logs, generated media, caches, or private source material may be committed.
- Useful behavior is promoted through an approved requirement, production interface, implementation, and test; experiment code is not copied blindly.
- Each experiment documents its purpose, limitations, owner role, and retirement gate.
- Security and data-loss fixes are allowed without implying product support.

## Catalog

| Experiment | Purpose | Status | Retirement gate |
| --- | --- | --- | --- |
| [Vocabulary MVP](vocabulary-mvp/README.md) | Telegram/Excel vocabulary ingestion, AI enrichment, SQLite cache, and Anki export | Reference only; non-production | M2 exit review |

Repository and experiment boundaries are governed by [ADR-001](../decisions/ADR-001-Repository-Package-and-Module-Layout.md).
