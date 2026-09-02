# Research Decisions: APKG Export

## Supported package baseline

**Decision**: MVP targets a legacy-compatible SQLite collection named `collection.anki21` inside a standard `.apkg` ZIP, with an explicit compatibility matrix and no arbitrary template JavaScript execution.

**Rationale**: The existing importer already has a safe legacy boundary and fixtures. A single pinned writer baseline is safer than attempting all Anki formats at once.

**Alternatives considered**: `collection.anki21b`/schema 18 generation (deferred until a separate modern-format contract exists), replacing a full Anki collection (out of scope), and invoking Anki itself (not portable or safe).

## SQLite implementation

**Decision**: Use the repository's existing SQLite/GRDB boundary and an exporter-specific schema builder with deterministic IDs and SQL fixtures.

**Rationale**: It preserves the native Swift/local-first architecture and allows schema inspection and round-trip tests without an external service.

## ZIP implementation

**Decision**: Use a bounded, deterministic ZIP writer behind an application port. Entries are staged in an app-owned temporary directory and the final output is atomically moved only after validation.

**Rationale**: Export must never expose a partial package and must reject traversal, duplicate normalized names, symlinks, oversized entries, and unsupported compression behavior.

## Scheduling compatibility

**Decision**: Export scheduling only where the target Anki schema can represent it exactly. Otherwise, export fresh Anki scheduling and record the limitation in the manifest and UI.

**Rationale**: Hermes FSRS/mastery semantics must not be falsely represented as preserved when Anki cannot encode them losslessly.

## Media ownership

**Decision**: Every packaged media asset gets a normalized numeric Anki media index, SHA-256 checksum, MIME/type metadata, source asset ID, and export manifest entry.

