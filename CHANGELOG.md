# Changelog

All notable changes to this documentation repository are recorded in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Initial Git-ready documentation repository structure.
- Central `PROJECT_STATUS.md` checklist for completed work, remaining work, milestone gates, and maintenance rules.
- Document 15 implementation backlog with stable requirement/work-item identifiers, milestone dependencies, acceptance evidence, test catalog, and requirements traceability matrix.
- Decision Register covering all 53 source open questions plus three supplemental architecture decisions, with stable IDs, classifications, statuses, owners, due gates, decision clusters, and the planned ADR queue.
- ADR-001 defining the accepted monorepo, package/module dependencies, path-aware CI scope, and vocabulary-prototype boundary.
- ADR-008 defining the Android-phone-only controlled pilot, deterministic golden-layout fixture/matrix, portable platform boundary, and iOS re-entry gate.
- Experiment governance for non-production research spikes.
- Product Vision specification.
- Complete product and technical specifications for documents 02 through 14.
- Domain contracts for LexicalSense, ReviewUnit, revisions, proposals, learning plans, and pipeline jobs.

### Changed

- Hardened `.gitignore` for excluded local projects, environment secrets, Python artifacts, local databases, Flutter output, and runtime files.
- Reviewed all specifications for cross-document consistency and implementation readiness.
- Clarified that media and exercises are resources/activities rather than KnowledgeItems.
- Resolved FSRS scheduling at the learner/objective ReviewUnit level.
- Defined authoritative validation versus learner-accepted private content.
- Aligned MVP scope, no-AI fallback, daily check-in defaults, privacy, and pilot metrics.
- Added minimal ClientSurface, CapabilitySnapshot, and consent-gated audio-pipeline extension points for future dedicated hardware while keeping hardware outside the app MVP.
- Aligned architecture-decision timing: M1-blocking ADRs remain M0 gates, while FSRS and ReviewUnit evidence-mapping ADRs are hard-gated before M3.
- Marked `LB-DEC-054` as `DECIDED` and `LB-WI-M0-03` as `DONE`; aligned DOC-11, DOC-15, the project checklist, and repository indexes with ADR-001.
- Relocated the untracked `vocabulary-mvp/` prototype to `experiments/vocabulary-mvp/` and marked it reference-only.
- Excluded experiment-local spreadsheet inputs and generated CSV exports from Git.
- Hardened the reference experiment by binding n8n to loopback, disabling persisted execution payloads, documenting Telegram-token exposure risks, and defining a safe one-way import/retirement contract.
- Marked `LB-DEC-037` and `LB-DEC-053` as `DECIDED`, made `LB-WI-M0-04` ready for ADR-002, and aligned Documents 10, 14, and 15 with the Android-first platform decision.
