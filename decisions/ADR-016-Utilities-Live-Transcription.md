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
- Microphone capture uses `AVCaptureSession` for both Apple on-device and OpenAI cloud paths. `CMSampleBuffer` audio is interpreted from its declared `AudioStreamBasicDescription`; raw bytes must never be assumed to be interleaved Int16 PCM.
- Microphone and Speech permissions are requested only when the tool starts.
- Cloud providers use a replaceable provider boundary and explicit consent.
- OpenAI Realtime is implemented as a transcription-only WebSocket session with explicit 24 kHz mono Int16 conversion, buffered audio appends, server turn detection, cancellation, and provider-specific error handling. Physical-device runtime verification remains required before T035 is complete.
- Captured text is copyable on iOS/iPadOS and macOS.
- Translation targets are the three supported app languages: Persian, German, and English. Translation uses the configured text Provider and never runs silently.

## Consequences

Utilities can evolve without coupling meeting notes or transcription state to card review. The current prototype provides a privacy-preserving local path immediately. Cloud transcription never sends audio until the learner explicitly chooses it.

The OS 27 beta audio stack has produced route-specific `AUIOBase` initialization failures with `AVAudioEngine` and non-actionable `CMIO`/dialogue-enhancement diagnostics. The shared `AVCaptureSession` path avoids forcing an Audio Unit configuration and tolerates microphone-format or route changes by rebuilding the converter from the next buffer's declared format. This beta workaround must be revalidated against the final Xcode 27 and OS 27 SDKs.

## Current model-validation evidence

Physical testing on 2026-08-22 established `gpt-4o-transcribe` as a partially working baseline: audio reaches OpenAI and text eventually appears, but partial/final text has excessive latency. Other selectable models were not yet working reliably. This is recorded as progress, not completion.

OpenAI's current transcription contract distinguishes the models:

- `gpt-live-transcribe` is the preferred low-latency caption model and must receive `languages` (not legacy `language`) plus an explicit delay profile;
- `gpt-realtime-whisper` is retained as a streaming comparison candidate;
- `gpt-transcribe` is intentionally turn-based and begins after an audio turn is committed, so silence/commit latency is expected;
- `gpt-realtime` is a bidirectional voice-agent model and belongs to a separate Utilities mode rather than the pure transcript selector.

T037 owns the physical model/latency matrix. T038 owns the later Voice Agent experiment.
