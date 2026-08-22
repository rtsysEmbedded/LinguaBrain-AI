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
- OpenAI Realtime is implemented as a transcription-only WebSocket session with explicit 24 kHz mono Int16 conversion, buffered audio appends, explicit client commits, cancellation, and provider-specific error handling. Physical-device runtime verification remains required before T035 is complete.
- Captured text is copyable on iOS/iPadOS and macOS.
- Translation targets are the three supported app languages: Persian, German, and English. Translation uses the configured text Provider and never runs silently.

## Consequences

Utilities can evolve without coupling meeting notes or transcription state to card review. Cloud transcription never sends audio until the learner explicitly chooses it. The Apple on-device path remains the intended privacy-preserving local option, but physical macOS testing has not yet produced usable transcript text and it must not be described as functional until that runtime gate passes.

The OS 27 beta audio stack has produced route-specific `AUIOBase` initialization failures with `AVAudioEngine` and non-actionable `CMIO`/dialogue-enhancement diagnostics. The shared `AVCaptureSession` path avoids forcing an Audio Unit configuration and tolerates microphone-format or route changes by rebuilding the converter from the next buffer's declared format. This beta workaround must be revalidated against the final Xcode 27 and OS 27 SDKs.

## Current model-validation evidence

Physical testing on 2026-08-22 established `gpt-4o-transcribe` as a partially working baseline: audio reaches OpenAI and text eventually appears, but partial/final text has excessive latency. Other selectable models were not yet working reliably. This is recorded as progress, not completion.

A later `gpt-live-transcribe` test reached OpenAI but the server rejected the session's automatic detection configuration as unsupported for this transcription mode. The implementation now follows the current dedicated-transcription examples: `turn_detection` is `null`, audio is appended continuously, live deltas are rendered as they arrive, and Stop explicitly commits the buffered turn before closing the socket. The accompanying `HALC`/`AQMEIO` messages are treated as secondary OS 27 beta audio-route cleanup diagnostics unless a capture failure occurs independently of the server error.

Physical macOS retesting after that correction found the OpenAI cloud path acceptable for the current prototype. The Apple on-device/local mode still captures input activity but does not produce transcript text, so its implementation remains incomplete. The Utilities transcription UI also requires a dedicated visual-design pass; that work is tracked separately from transcription correctness so a cosmetic change cannot hide an unresolved provider failure.

Audio-provider configuration uses separate model roles. The speech/TTS model generates pronunciation audio for cards; the transcript model handles completed or explicitly committed audio; and the live-stream model handles low-latency microphone text. Utilities exposes Transcript and Live Stream modes and resolves their model IDs directly from these persisted settings. A feature must request a role rather than reading one generic audio model ID.

OpenAI's current transcription contract distinguishes the models:

- `gpt-live-transcribe` is the preferred low-latency caption model and must receive `languages` (not legacy `language`) plus an explicit delay profile;
- `gpt-realtime-whisper` is retained as a streaming comparison candidate;
- `gpt-transcribe` is intentionally turn-based and begins after an audio turn is committed, so silence/commit latency is expected;
- `gpt-realtime` is a bidirectional voice-agent model and belongs to a separate Utilities mode rather than the pure transcript selector.

T037 owns the physical model/latency matrix. T038 owns the later Voice Agent experiment.
