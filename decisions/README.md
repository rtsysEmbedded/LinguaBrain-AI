# Decision Management

This directory contains the project-wide [Decision Register](DECISION_REGISTER.md) and Architecture Decision Records (ADRs). The register preserves every open product and architecture question, its owner, due gate, classification, status, and required closure artifact.

Use [ADR_TEMPLATE.md](ADR_TEMPLATE.md) as the starting point for new records. Name records using a zero-padded sequence, for example `ADR-001-AI-Enhancement-Layer.md`.

## Rules

- The Decision Register is an index; an accepted ADR remains authoritative for an architectural choice.
- Reserved ADR numbers are not accepted decisions until the corresponding file has status `accepted`.
- Significant decisions update affected specifications, the register, `PROJECT_STATUS.md`, and `CHANGELOG.md` in the same commit.
- Superseded decisions and ADRs remain in Git and point to their replacements.

## Accepted ADRs

- [ADR-009 — Native Apple Client and Platform Baseline](ADR-009-Native-Apple-Client-and-Platform-Baseline.md)
- [ADR-010 — Swift Package and Module Layout](ADR-010-Swift-Package-and-Module-Layout.md)
- [ADR-011 — SwiftUI State, Observation, Navigation, and Dependency Composition](ADR-011-SwiftUI-State-Observation-Navigation-and-Dependency-Composition.md)
- [ADR-012 — Anki Core First and APKG Import Boundary](ADR-012-Anki-Core-First-and-APKG-Import-Boundary.md)
- [ADR-013 — Initial AI Provider Strategy](ADR-013-Initial-AI-Provider-Strategy.md)
- [ADR-004 — FSRS Implementation and Version](ADR-004-FSRS-Implementation-and-Version.md)

## Superseded ADRs

- [ADR-001 — Repository, Package, and Module Layout](ADR-001-Repository-Package-and-Module-Layout.md) — superseded by [ADR-010](ADR-010-Swift-Package-and-Module-Layout.md).
- [ADR-008 — Initial Pilot and Golden Layout Platform](ADR-008-Initial-Pilot-and-Golden-Layout-Platform.md) — superseded by [ADR-009](ADR-009-Native-Apple-Client-and-Platform-Baseline.md).

## Withdrawn ADR reservations

- `ADR-002-Flutter-State-Management-and-DI.md` — withdrawn before proposal when Flutter ceased to be the production client stack; its number is not reused.

## Planned ADR queue

- `ADR-003-Swift-Persistence-and-Migration-Stack.md`
- `ADR-005-ReviewUnit-Retrieval-and-Evidence-Rating.md`
- `ADR-006-Domain-Events-and-Transactional-Outbox.md`
- `ADR-007-Local-Database-Protection-and-Recovery.md`

The live order, owners, gates, and linked decision IDs are maintained in the [Decision Register](DECISION_REGISTER.md).
