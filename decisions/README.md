# Decision Management

This directory contains the project-wide [Decision Register](DECISION_REGISTER.md) and Architecture Decision Records (ADRs). The register preserves every open product and architecture question, its owner, due gate, classification, status, and required closure artifact.

Use [ADR_TEMPLATE.md](ADR_TEMPLATE.md) as the starting point for new records. Name records using a zero-padded sequence, for example `ADR-001-AI-Enhancement-Layer.md`.

## Rules

- The Decision Register is an index; an accepted ADR remains authoritative for an architectural choice.
- Reserved ADR numbers are not accepted decisions until the corresponding file has status `accepted`.
- Significant decisions update affected specifications, the register, `PROJECT_STATUS.md`, and `CHANGELOG.md` in the same commit.
- Superseded decisions and ADRs remain in Git and point to their replacements.

## Accepted ADRs

- [ADR-001 — Repository, Package, and Module Layout](ADR-001-Repository-Package-and-Module-Layout.md)
- [ADR-008 — Initial Pilot and Golden Layout Platform](ADR-008-Initial-Pilot-and-Golden-Layout-Platform.md)

## Planned ADR queue

- `ADR-002-Flutter-State-Management-and-DI.md`
- `ADR-003-SQLite-Query-and-Migration-Stack.md`
- `ADR-004-FSRS-Implementation-and-Version.md`
- `ADR-005-ReviewUnit-Retrieval-and-Evidence-Rating.md`
- `ADR-006-Domain-Events-and-Transactional-Outbox.md`
- `ADR-007-Local-Database-Protection-and-Recovery.md`

The live order, owners, gates, and linked decision IDs are maintained in the [Decision Register](DECISION_REGISTER.md).
