# Quickstart Validation

## Prerequisites

- Xcode and the supported iOS/macOS SDKs;
- repository checkout with no provider credential required;
- deterministic fake text and media providers enabled for tests.

## Validate generation and approval

1. Submit a 20-card German-to-Persian A1 request using the fake provider.
2. Confirm structured preview, validation warnings, and provenance.
3. Edit one card, reject one card, and approve the remainder.
4. Restart with networking disabled.
5. Confirm only approved cards are available for review.

## Validate senses and media

1. Generate `Bank` with two senses.
2. Approve one sense with fake audio and one with media disabled.
3. Confirm separate identities, playable cached audio, and explicit text-only fallback.

## Validate export

1. Export approved cards as TSV.
2. Inspect language, direction, examples, Unicode, tags, and provenance.
3. After APKG exporter completion, import the package into a clean fixture and compare normalized fields and media.

## Suggested commands

```bash
xcodebuild -project apps/learner/LinguaBrain.xcodeproj -scheme 'LinguaBrain Mac' -sdk macosx -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

The feature is not complete until the relevant XCTest targets, iOS build, macOS build, offline restart path, and export fixtures pass.

