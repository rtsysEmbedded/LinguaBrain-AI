# LinguaBrain Visual Prototype

This directory contains a buildable, native SwiftUI visual prototype for the
LinguaBrain learner application. It is intended to validate navigation,
information hierarchy, Persian right-to-left presentation, and the overall
Apple-platform experience before production architecture is implemented.

## What is included

- Today dashboard and daily energy/time check-in
- Vocabulary library
- Mock AI-assisted word creation and generated-card preview
- Review-session interface
- Progress dashboard
- Settings and onboarding
- Persisted interface-language switching for the shell/settings surface (`en`, `de`, `fa`) with automatic LTR/RTL direction
- Independent persisted explanation/source and learning/target language roles
- Runtime-generated sanitized APKG smoke fixtures for `fa→de`, `en→de`, and `de→en`
- Adaptive layouts for iPhone, iPad, and Mac

The prototype includes local persistence and selected functional Anki/OpenRouter
validation paths, but it is not the production architecture. Vocabulary,
progress, recommendations, and untranslated feature copy remain prototype data.

## Run in Xcode

1. Open `LinguaBrain.xcworkspace` in Xcode 27 or newer.
2. Select the `LinguaBrain` scheme for an iPhone or iPad simulator, or select
   `LinguaBrain Mac` for macOS.
3. Press **Run** (`Command-R`).
4. Open **Settings → Languages and level** to switch the interface independently
   from the explanation and learning languages.

The production walking skeleton remains tracked separately in
`PROJECT_STATUS.md`; completion of this prototype does not complete milestone
M1 or its persistence and domain-contract requirements.
