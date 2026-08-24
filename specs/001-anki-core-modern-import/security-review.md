# Security Review — T017–T019 Handoff

**Review date:** 2026-08-24  
**Scope:** changes and verification produced while closing the Anki Core convergence tasks

## Review result

No staged files contained credentials, private APKG data, raw learner content, or new executable network logging. The documentation-only changes add no runtime attack surface.

The working tree still contains unrelated user changes in `.specify/extensions.yml`, `apps/learner/Resources/Localizable.xcstrings`, `README-APKG-EXPORT-IMPLEMENTATION-NOTES.md`, and `specs/003-apkg-export-approved-cards/`; these were not staged, modified, or included in the convergence commit.

## Verification evidence

- `swift test --package-path packages/LinguaBrainKit`: 38 tests passed, zero failures, no API key or network required.
- macOS build with signing disabled: passed.
- iOS Simulator build with signing disabled: passed.
- iPhone/iPad app tests: not clean; two regression failures were reported and the simulator runner did not return a final result.
- macOS app tests: unavailable because the `LinguaBrain Mac` scheme has no Test Action.

## Risk disposition

The review is acceptable for documentation handoff, but not for declaring the offline review gate complete. The unresolved test failures and missing macOS Test Action remain release-blocking risks for T016.
