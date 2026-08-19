# Research: Hermes Content and Anki Generation

## Decision: Swift-first orchestration with language-agnostic agents

**Rationale**: Hermes is a native Apple, local-first application. Keeping orchestration, validation, approval, persistence, media, and export in Swift minimizes runtime and privacy complexity. External agents remain possible through a stable contract.

**Alternatives considered**: Python-only service (more deployment overhead), provider-specific app integration (lock-in), unrestricted agent database access (unsafe and non-auditable).

## Decision: Versioned structured proposals

**Rationale**: JSON Schema-style contracts make model output testable and allow provider or implementation-language changes without domain changes.

**Alternatives considered**: Free-form text parsing (fragile), provider-native response types (not portable).

## Decision: Hermes is canonical; TSV precedes APKG

**Rationale**: The domain model must support review, senses, media, and future exercises. TSV is lower risk; APKG requires collection, template, media, and round-trip guarantees.

## Decision: Explicit approval and text-only fallback

**Rationale**: AI output is a proposal under the constitution. Media providers can be unavailable or over quota without making text content unusable.

