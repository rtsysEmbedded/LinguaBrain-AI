---
title: Decision Register
document_id: LB-DEC-REGISTER
version: 0.1.1
status: Active
last_updated: 2026-07-19
---

# Decision Register

## Purpose

This register is the single index of unresolved, decided, deferred, and superseded product and architecture decisions for LinguaBrain AI. It converts every open question in Documents 01–14 into an owned decision with a latest safe decision gate and a required evidence artifact.

The register does not replace an Architecture Decision Record (ADR), product decision, research note, specification, license record, or test report. It points to the artifact that becomes authoritative when the decision is accepted.

## Scope and coverage

This version contains:

- all 53 bullets under the Open questions sections of Documents 02–10 and 12–14;
- no source questions from Documents 01, 11, or 15 because those documents have no Open questions section;
- three supplemental architecture decisions required by Documents 11 and 15;
- 56 stable decision IDs in total.

Source questions remain individually traceable even when several questions share one research package or ADR. IDs are never reused.

The source headings are preserved as historical question inventories, not as live status fields. This register governs current status, so a source question remains verbatim here even after it is decided, deferred, or superseded.

## Classification

Classification describes when an unresolved decision affects the current delivery plan:

| Class | Meaning |
| --- | --- |
| MVP-blocking | Must be resolved or formally ratified before the M0 baseline, M1 start, or first storage of private learner data. |
| MVP-later | Required by a later MVP milestone (M2–M6) but does not block the current M0/M1 preparation gate. |
| post-MVP | Intentionally outside the approved MVP. It must not delay the MVP and is reopened only before its future feature becomes ready. |

Classification is temporal, not a measure of importance. An MVP-later decision becomes blocking when its named due gate is reached.

## Status model

| Status | Meaning |
| --- | --- |
| OPEN | A final decision and its required evidence do not yet exist. |
| IN_RESEARCH | Evidence gathering or a technical/product spike is active. |
| PROPOSED | A preferred option is documented and awaiting acceptance. |
| DECIDED | The MVP answer is already authoritative in a reviewed specification or accepted decision artifact. |
| DEFERRED | Deliberately postponed until the named future gate. |
| SUPERSEDED | The question is tracked by another decision ID; its source trace remains here. |

Only the accountable owner may propose closure. Significant architecture decisions require an accepted ADR and corresponding specification updates.

Each register row names one accountable owner role. Other affected roles review the decision artifact but do not share accountability.

## Register summary

| Dimension | Count |
| --- | ---: |
| Total decision records | 56 |
| MVP-blocking | 13 |
| MVP-later | 31 |
| post-MVP | 12 |
| OPEN | 40 |
| DECIDED | 2 |
| PROPOSED | 2 |
| DEFERRED | 11 |
| SUPERSEDED | 1 |

## Master decision register

| ID | Source | Decision question | Class | Status | Accountable owner role | Latest due gate | Required decision artifact |
| --- | --- | --- | --- | --- | --- | --- | --- |
| LB-DEC-001 | DOC-02 | Which evidence thresholds should move an objective between mastery stages? | MVP-later | OPEN | Learning Science Lead | Before M3 implementation and DOC-17 approval | DOC-17 research note and ADR-005 |
| LB-DEC-002 | DOC-02 | How should speaking and pronunciation be assessed in the MVP versus later releases? | post-MVP | DEFERRED | Product Owner | Reopen before speaking/pronunciation assessment is READY | MVP deferral in DOC-10 and DOC-15; future assessment specification |
| LB-DEC-003 | DOC-02 | Which learner controls should override adaptive recommendations? | MVP-later | OPEN | Product Owner | M4 start | Adaptive-controls product decision |
| LB-DEC-004 | DOC-02 | What validation sources will be used for grammar facts and lexical data? | MVP-later | OPEN | Language Data Lead | M2 start and DOC-18 approval | DOC-18 source and validation register |
| LB-DEC-005 | DOC-03 | Which platform-secure storage APIs are required for the initial Flutter targets? | MVP-blocking | OPEN | Flutter Platform Lead | M1 start | ADR-007 |
| LB-DEC-006 | DOC-03 | Which encryption approach is justified for the local MVP database, given usability and recovery trade-offs? | MVP-blocking | OPEN | Security Lead | Before private learner data in M1 | ADR-007 and recovery evidence |
| LB-DEC-007 | DOC-03 | What operational metrics are acceptable under the final privacy policy? | MVP-later | OPEN | Privacy Lead | Before M6 telemetry or pilot hardening | DOC-19 telemetry allowlist and privacy decision |
| LB-DEC-008 | DOC-03 | At what scale, if any, should a graph database replace relational graph tables? | post-MVP | DEFERRED | Data Architect | Post-MVP scaling review | Graph-scaling research note and ADR only if migration is approved |
| LB-DEC-009 | DOC-03 | What backup mechanism best supports local-only learners before cloud sync exists? | MVP-blocking | OPEN | Security Lead | Before private learner data in M1 | ADR-007 and restore test plan |
| LB-DEC-010 | DOC-04 | What trust and sharing policy should apply if private learner content is offered for future cloud promotion? | post-MVP | DEFERRED | Privacy Lead | Before cloud promotion or sharing | Legal/privacy research note and product decision |
| LB-DEC-011 | DOC-04 | When should a target translation expression be promoted into its own Word/Phrase and LexicalSense? | MVP-later | OPEN | Domain Architect | Before M2 ingestion/enrichment | DOC-16 domain rule and ADR if the entity boundary changes |
| LB-DEC-012 | DOC-04 | What is the minimum validated lexical dataset needed to reduce AI dependency for German? | MVP-later | OPEN | Language Data Lead | M2 start and DOC-18 approval | DOC-18 dataset and license decision |
| LB-DEC-013 | DOC-04 | Which JSON metadata fields need normalization into first-class entities before implementation begins? | MVP-blocking | PROPOSED | Domain Architect | Ratify at M0 exit | DOC-12 normalization rule, formalized by DOC-16/ADR-003 |
| LB-DEC-014 | DOC-05 | What mastery score/confidence thresholds should map to each progression stage? | MVP-later | SUPERSEDED | Learning Science Lead | Same as LB-DEC-001 | Tracked by LB-DEC-001; retain as a source reference |
| LB-DEC-015 | DOC-05 | How should human self-assessment influence AI-evaluated speaking/writing evidence? | post-MVP | DEFERRED | Learning Science Lead | Before speaking/writing assessment | Assessment research note and product decision |
| LB-DEC-016 | DOC-05 | Which error patterns belong to a language package versus a generic exercise evaluator? | MVP-later | PROPOSED | Domain Architect | Ratify before M4 ErrorPattern implementation | Existing DOC-05/DOC-09 boundary, formalized in DOC-16 |
| LB-DEC-017 | DOC-05 | How much behavioral inference is useful before it becomes intrusive? | MVP-later | OPEN | Privacy Lead | Before M4 Digital Twin implementation | DOC-19 inference allowlist and privacy decision |
| LB-DEC-018 | DOC-05 | Should a learner support multiple active missions with conflicting deadlines in the MVP? | MVP-blocking | OPEN | Product Owner | M1 contract freeze | Product decision and DOC-16 contract |
| LB-DEC-019 | DOC-06 | Which trusted lexical data sources can be licensed or used for initial German validation? | MVP-later | OPEN | Language Data Lead | M2 start | Shared DOC-18 dataset/licensing research package |
| LB-DEC-020 | DOC-06 | Which relation types must require human review versus rule-based validation? | MVP-later | OPEN | Knowledge Graph Architect | M5 start | Graph validation ADR and relation matrix |
| LB-DEC-021 | DOC-06 | How should user-created relations be shared, if at all, in future cloud versions? | post-MVP | DEFERRED | Product Owner | Before shared/cloud graph design | Cloud graph product/privacy decision |
| LB-DEC-022 | DOC-06 | Which graph recommendations are useful enough to surface during a short recovery-mode session? | MVP-later | OPEN | Learning Science Lead | M5 start | Research note and M5 product decision |
| LB-DEC-023 | DOC-07 | What default weights provide useful behavior before enough personal data exists? | MVP-later | OPEN | Learning Engine Architect | M4 start | ALE policy ADR and deterministic test vectors |
| LB-DEC-024 | DOC-07 | How should the system balance overdue reviews against urgent mission deadlines? | MVP-later | OPEN | Learning Engine Architect | M4 start | ALE policy ADR and guardrail tests |
| LB-DEC-025 | DOC-07 | What is the minimum session length for introducing new content responsibly? | MVP-later | OPEN | Learning Science Lead | M4 start | Research note and ALE product policy |
| LB-DEC-026 | DOC-07 | How should learner self-rated confidence influence scoring without encouraging gaming? | MVP-later | OPEN | Review Engine Lead | M3 review completion | ADR-005 and evidence test vectors |
| LB-DEC-027 | DOC-07 | Which adaptive behavior must be configurable in the first release? | MVP-later | OPEN | Product Owner | M4 start | Adaptive-controls product decision |
| LB-DEC-028 | DOC-08 | Which structured-output standard should adapters normalize to? | MVP-later | OPEN | AI Platform Architect | M2 enrichment | AI provider/structured-output ADR |
| LB-DEC-029 | DOC-08 | Which German lexical sources can validate AI-generated morphology in the MVP? | MVP-later | OPEN | Language Data Lead | M2 start | Shared DOC-18 dataset/licensing research package |
| LB-DEC-030 | DOC-08 | What quality threshold determines whether a low-cost model can serve a task? | MVP-later | OPEN | AI Evaluation Lead | M2 enrichment | Model evaluation note and routing ADR |
| LB-DEC-031 | DOC-08 | How should user-custom prompts be sandboxed without weakening system safety? | post-MVP | DEFERRED | Security Architect | Before custom-prompt support | Threat research note and security ADR |
| LB-DEC-032 | DOC-09 | Which German and Persian datasets meet quality and licensing requirements? | MVP-later | OPEN | Language Data Lead | M2 start | Shared DOC-18 dataset/licensing research package |
| LB-DEC-033 | DOC-09 | Should packages ship with the app or be independently downloadable? | post-MVP | DECIDED | Language Platform Architect | Reopen before downloadable packages | DOC-09 decision: first-party static packages ship with the MVP |
| LB-DEC-034 | DOC-09 | Which package capabilities are mandatory for “supported” versus “experimental” status? | MVP-later | OPEN | Language Platform Lead | M2 start | DOC-18 capability/support-tier matrix |
| LB-DEC-035 | DOC-09 | How should dialects and regional variants inherit or override base-language behavior? | post-MVP | DEFERRED | Language Platform Architect | Before the first regional package | Language-package inheritance ADR |
| LB-DEC-036 | DOC-09 | Which NLP functions should be deterministic libraries versus optional local models? | MVP-later | OPEN | Language Platform Architect | M2 start | DOC-18 execution-boundary research and ADR |
| LB-DEC-037 | DOC-10 | Which Flutter platforms are included in the first pilot: Android only or Android plus iOS? | MVP-blocking | OPEN | Product Owner | M1 start | Initial-platform product decision |
| LB-DEC-038 | DOC-10 | Which validated German lexical dataset is available under acceptable licensing? | MVP-later | OPEN | Language Data Lead | M2 start | Shared DOC-18 dataset/licensing research package |
| LB-DEC-039 | DOC-10 | What pilot size and duration can provide meaningful retention evidence? | MVP-later | OPEN | Learning Research Lead | Before M6 enrollment | DOC-20 pre-registered pilot protocol |
| LB-DEC-040 | DOC-10 | Which FSRS library/version will be adopted and independently tested? | MVP-later | OPEN | Review Engine Architect | M3 start | ADR-004 and reference-vector test report |
| LB-DEC-041 | DOC-12 | Which Flutter SQLite library and migration framework best satisfy transaction/testing needs? | MVP-blocking | OPEN | Persistence Lead | M1 start | ADR-003 and transaction/migration spike |
| LB-DEC-042 | DOC-12 | Is SQLCipher justified for MVP platforms, and how will key recovery work? | MVP-blocking | OPEN | Security Lead | Before private learner data in M1 | ADR-007 and recovery test plan |
| LB-DEC-043 | DOC-12 | Which deterministic evidence-to-rating thresholds should the ReviewUnit ADR adopt for each MVP exercise type? | MVP-later | OPEN | Learning Science Lead | M3 review completion | ADR-005 and versioned mapping/test vectors |
| LB-DEC-044 | DOC-12 | Which response payloads are necessary for feedback while minimizing sensitive storage? | MVP-later | OPEN | Privacy Lead | M3 start | DOC-19 data-minimization and schema decision |
| LB-DEC-045 | DOC-13 | Which OCR engine provides acceptable German/Persian mixed-text results and licensing? | post-MVP | DEFERRED | OCR/NLP Lead | Before OCR milestone | Technology evaluation and license record |
| LB-DEC-046 | DOC-13 | What batch size keeps approval understandable? | post-MVP | DEFERRED | UX Research Lead | Before batch-import UX | Usability study and UX decision |
| LB-DEC-047 | DOC-13 | Should future enterprise deployments permit an administrator-configured retention window beyond the private MVP default? | post-MVP | DEFERRED | Privacy Lead | Before enterprise release | Enterprise retention-policy ADR |
| LB-DEC-048 | DOC-13 | Which pipeline stages can safely run fully on-device? | post-MVP | DEFERRED | Edge/AI Architect | Before dedicated-device or local-pipeline implementation | Deployment ADR and benchmark |
| LB-DEC-049 | DOC-14 | Should MVP navigation use four tabs plus a central Add action or five equal destinations? | MVP-later | OPEN | UX Lead | Before integrated MVP navigation freeze | Prototype and usability decision |
| LB-DEC-050 | DOC-14 | Which Persian/German font pairing offers best cross-platform readability and licensing? | MVP-blocking | OPEN | Design Systems Lead | M1 start | Typography tokens, readability evidence, and license record |
| LB-DEC-051 | DOC-14 | How much FSRS detail should be visible to advanced users? | MVP-later | OPEN | UX Lead | Before M3 review UI acceptance | Review-UI disclosure policy |
| LB-DEC-052 | DOC-14 | Should the daily check-in appear every day or only when state is missing/stale? | MVP-later | OPEN | Product Owner | M4 start | Daily check-in product/UX policy |
| LB-DEC-053 | DOC-14 | Which first platform defines the golden layout baseline? | MVP-blocking | OPEN | Product Owner | M1 start | Initial-platform decision shared with LB-DEC-037 |
| LB-DEC-054 | DOC-11/DOC-15 supplement | What repository/package/module layout should the project adopt, and how should vocabulary-mvp/ be classified? | MVP-blocking | DECIDED | Software Architect | M1 start | [ADR-001](ADR-001-Repository-Package-and-Module-Layout.md) |
| LB-DEC-055 | DOC-11 supplement | Which Flutter state-management and dependency-injection approach should the MVP adopt? | MVP-blocking | OPEN | Flutter Architecture Lead | M1 start | ADR-002 and testable composition-root example |
| LB-DEC-056 | DOC-11 supplement | Which in-process domain-event and transactional-outbox strategy should the MVP adopt? | MVP-blocking | OPEN | Application Architect | M1 start | ADR-006 and retry/replay contract |

## Existing scope, proposed, and deferred baseline

The following existing specification positions are recorded without losing their remaining approval or future-work gates:

- LB-DEC-002 is DEFERRED: the MVP includes pronunciation availability and baseline playback where content exists, but automatic pronunciation scoring and guided speaking evaluation require a post-MVP specification.
- LB-DEC-013 is PROPOSED: core/query/integrity fields are normalized; genuinely extensible, package-specific payloads remain versioned and validated JSON until measured access patterns justify normalization. ADR-003/DOC-16 must ratify the boundary.
- LB-DEC-016 is PROPOSED: Language Packages own language-specific error rules; generic evaluator, evidence, event, and lifecycle contracts remain in the shared core. DOC-16 must ratify the boundary.
- LB-DEC-033 is DECIDED: German and Persian MVP packages are first-party, statically registered, versioned components shipped with the app; executable third-party/downloaded packages are post-MVP.
- LB-DEC-054 is DECIDED: LinguaBrain uses a modular monorepo with thin client shells and inward dependencies; the Python vocabulary prototype is retained only under `experiments/vocabulary-mvp/`.

Deferred records remain visible and do not become active work until their named gate is approved.

## Decision clusters

Related source questions should share evidence and, where appropriate, one final artifact:

| Cluster | Decision IDs | Shared output |
| --- | --- | --- |
| Mastery and review evidence | LB-DEC-001, LB-DEC-014, LB-DEC-026, LB-DEC-040, LB-DEC-043, LB-DEC-051 | DOC-17, ADR-004, ADR-005, and deterministic vectors |
| Lexical datasets, licensing, and validation | LB-DEC-004, LB-DEC-012, LB-DEC-019, LB-DEC-029, LB-DEC-032, LB-DEC-038 | One DOC-18 data-source/license/validation register |
| Initial client platform and UX baseline | LB-DEC-005, LB-DEC-037, LB-DEC-049, LB-DEC-050, LB-DEC-053 | Platform product decision, M1 UI baseline, and license records |
| Local data protection and privacy | LB-DEC-006, LB-DEC-007, LB-DEC-009, LB-DEC-042, LB-DEC-044, LB-DEC-047 | ADR-007 and DOC-19 |
| Adaptive policy and learner control | LB-DEC-003, LB-DEC-023, LB-DEC-024, LB-DEC-025, LB-DEC-027, LB-DEC-052 | Versioned ALE and UX policy |
| Knowledge Graph policy | LB-DEC-008, LB-DEC-010, LB-DEC-011, LB-DEC-020, LB-DEC-021, LB-DEC-022 | Graph domain/validation decisions and future scaling policy |
| AI and Language Package execution | LB-DEC-028, LB-DEC-030, LB-DEC-031, LB-DEC-034, LB-DEC-036 | Provider contract, evaluation gate, and package capability boundary |

## ADR catalog and planned queue

ADR-001 is accepted. The remaining filenames are reserved and do not represent accepted decisions. The first column is the stable ADR number, not execution priority; the Current decision queue below owns execution order.

| ADR no. | ADR | Status | Decision references | Target and hard gate | Acceptance evidence |
| ---: | --- | --- | --- | --- | --- |
| 1 | [ADR-001-Repository-Package-and-Module-Layout.md](ADR-001-Repository-Package-and-Module-Layout.md) | accepted | LB-DEC-054 | Accepted 2026-07-19; M1 paths stable | Package paths, CI scope, and explicit prototype disposition |
| 2 | ADR-002-Flutter-State-Management-and-DI.md | planned | LB-DEC-055 | M0; hard gate M1 start | Minimal composition root that supports unit and widget tests |
| 3 | ADR-003-SQLite-Query-and-Migration-Stack.md | planned | LB-DEC-013, LB-DEC-041 | M0; hard gate M1 start | Atomic transaction, repository fake, forward migration, and restart spike |
| 4 | ADR-004-FSRS-Implementation-and-Version.md | planned | LB-DEC-040 | Before M3 start | Pinned version, reference vectors, serialization, and upgrade policy |
| 5 | ADR-005-ReviewUnit-Retrieval-and-Evidence-Rating.md | planned | LB-DEC-001, LB-DEC-014, LB-DEC-026, LB-DEC-043 | Before M3 review implementation | Retrieval contracts, raw evidence, derived rating, and deterministic replay |
| 6 | ADR-006-Domain-Events-and-Transactional-Outbox.md | planned | LB-DEC-056 | M0; hard gate M1 start | Transaction boundary, ordering, idempotency, retry, and replay |
| 7 | ADR-007-Local-Database-Protection-and-Recovery.md | planned | LB-DEC-005, LB-DEC-006, LB-DEC-009, LB-DEC-042 | Before private learner data in M1 | Threat assumptions, secure key storage, backup/restore, lost-key behavior, and deletion verification |

## Current decision queue

Resolve in this order unless a dependency changes:

1. LB-DEC-037 with LB-DEC-053: initial Flutter and golden-layout platform.
2. LB-DEC-055 and ADR-002: Flutter state management and dependency injection.
3. LB-DEC-041 and ADR-003: SQLite/query/migration stack.
4. LB-DEC-005, LB-DEC-006, LB-DEC-009, LB-DEC-042, and ADR-007: local data protection and recovery.
5. LB-DEC-056 and ADR-006: domain events and transactional outbox.
6. LB-DEC-018: single versus conflicting active missions for the MVP.
7. LB-DEC-050: Persian/German typography and license baseline.

The M1 backlog cannot be approved until all still-open MVP-blocking entries are decided or an explicit scope change removes the dependency.

## Decision workflow

1. Move the register entry from OPEN to IN_RESEARCH and name an accountable owner.
2. Record options, constraints, evidence, and rejected alternatives in the required artifact.
3. Move the entry to PROPOSED and request review from affected product, learning, security, privacy, accessibility, and technical owners.
4. Accept the artifact; update affected specifications, this register, PROJECT_STATUS.md, and CHANGELOG.md in the same commit.
5. Mark the entry DECIDED and link the accepted artifact and commit.
6. If replaced, keep the original ID and mark it SUPERSEDED with the replacement ID.

## Maintenance checks

At every milestone review:

- every Open questions bullet still appears in this register;
- every OPEN or IN_RESEARCH entry has an owner and due gate;
- no READY work item depends on an unresolved decision at or beyond its gate;
- every DECIDED entry cites its authoritative reviewed artifact, and any architecture decision required by a gate links an accepted ADR before dependent work becomes READY;
- every DEFERRED entry remains outside the active MVP backlog;
- duplicate source questions retain individual IDs and point to one authoritative artifact;
- summary counts match the master table.

## Related documents

- [Project Status and Delivery Checklist](../PROJECT_STATUS.md)
- [Implementation Backlog and Requirements Traceability](../docs/15_Implementation_Backlog_and_Traceability.md)
- [Architecture Decision Record index](README.md)
- [Architecture Decision Record template](ADR_TEMPLATE.md)

## Revision history

| Version | Date | Description |
| --- | --- | --- |
| 0.1.1 | 2026-07-19 | Accepted ADR-001, closed LB-DEC-054, recorded the experiment disposition, and advanced the active decision queue. |
| 0.1.0 | 2026-07-15 | Registered all 53 source open questions and three supplemental architecture decisions; assigned class, status, owner, gate, and required artifact. |
