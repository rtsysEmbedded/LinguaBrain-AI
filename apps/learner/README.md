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
- Adaptive layouts for iPhone, iPad, and Mac

All vocabulary, progress, and recommendations are mock data. The prototype has
no persistence, AI-provider calls, synchronization, recording, or production
learning logic.

## Run in Xcode

1. Open `LinguaBrain.xcworkspace` in Xcode 27 or newer.
2. Select the `LinguaBrain` scheme for an iPhone or iPad simulator, or select
   `LinguaBrain Mac` for macOS.
3. Press **Run** (`Command-R`).

The production walking skeleton remains tracked separately in
`PROJECT_STATUS.md`; completion of this prototype does not complete milestone
M1 or its persistence and domain-contract requirements.
