---
title: Utilities and Live Transcription
adr_id: ADR-016
status: accepted
date: 2026-08-21
decision_owners: Product and Architecture
---

# ADR-016 — Utilities and Live Transcription

## Decision

Add a top-level `Utilities` surface beside Today, Library, Add, Progress, and Settings. Utilities is an extensible home for meeting notes, translation, OCR, audio tools, and personal-device workflows that are useful but not part of the Anki review loop.

The first tool is live speech-to-text:

- Apple on-device Speech recognition is the first working provider.
- Audio is captured with `AVAudioEngine` and partial results are rendered continuously.
- Microphone and Speech permissions are requested only when the tool starts.
- Cloud providers use a replaceable provider boundary and explicit consent.
- OpenAI Realtime is the next cloud implementation; it requires a short-lived client session, 24 kHz PCM transport, turn detection, cancellation, and provider-specific error handling.
- Captured text is copyable on iOS/iPadOS and macOS.
- Translation targets are the three supported app languages: Persian, German, and English. Translation uses the configured text Provider and never runs silently.

## Consequences

Utilities can evolve without coupling meeting notes or transcription state to card review. The current prototype provides a privacy-preserving local path immediately. Cloud transcription remains a separate implementation task and must not send audio until the learner explicitly chooses it.
