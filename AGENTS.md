# LinguaBrain Agent Instructions

These instructions apply to every AI or human contributor working anywhere in this repository.

## Mandatory Apple Platform Baseline

The active development baseline is provisional beta software:

- macOS 27.0 beta, currently verified on build `26A5416b`;
- Xcode 27.0 beta, currently verified on build `27A5228h`;
- Apple Swift 6.4, currently verified as `6.4.0.27.1`;
- iOS/iPadOS/macOS 27.0 SDKs;
- native SwiftUI applications for iPhone, iPad, and Mac.

Do not replace OS 27 APIs with legacy implementations merely because older examples are more common. Do not assume an API contract from memory, an old Stack Overflow answer, or a pre-27 sample.

Before changing code that touches Apple frameworks, concurrency, availability, audio, Speech, Translation, Foundation Models, SwiftData, CloudKit, authentication, permissions, signing, or platform lifecycle, the contributor MUST:

1. read the relevant current repository specification, accepted ADR, and task;
2. inspect the API declaration in the locally installed Xcode 27 SDK/Swift interface;
3. check the current official Apple documentation or Xcode/OS release notes when behavior may have changed;
4. distinguish stable API behavior from beta-only behavior and document any workaround;
5. build every affected Apple target and run proportionate tests;
6. revalidate beta workarounds after every Xcode/OS beta update and again on GM/final SDKs.

If the local toolchain differs from the baseline above, stop implementation, report the difference, and update `docs/TECHNOLOGY_STACK.md` before relying on the new behavior.

## Repository Workflow

- Follow `.specify/memory/constitution.md` and the active feature artifacts under `specs/`.
- Treat `PROJECT_STATUS.md` as the project-wide progress source.
- Preserve unrelated user changes and inspect `git status` before editing.
- Keep AI providers replaceable and deterministic learning logic independent from AI output.
- Record material platform/API decisions in the relevant ADR and `CHANGELOG.md`.

