# Pronunciation capability research — 2026-09-07

## Decision

No production pronunciation-assessment provider is approved for Feature 004 yet. Speech-to-text or transcript similarity alone is not a pronunciation score and must not be presented as one. Therefore the product exposes no numeric speaking score and keeps T030–T032 pending.

## Evidence and constraints

- Apple documents `AVAudioRecorder` as a file-based recorder with metering, explicit stop, and duration-based recording; iOS recording requires a configured record/play-and-record session. The current Xcode 27 SDK and [Apple AVAudioRecorder documentation](https://developer.apple.com/documentation/avfaudio/avaudiorecorder) were checked.
- Apple marks `AVAudioSession.recordPermission` deprecated and directs new permission handling to `AVAudioApplication`; [Apple permission documentation](https://developer.apple.com/documentation/avfaudio/avaudioapplication/recordpermission-swift.enum) was checked.
- Any remote assessment needs separate consent, clear provider/model/version disclosure, a retention policy, a reviewed German benchmark, and an explicit cost/latency review before activation.

## Benchmark gate for later approval

Before a provider is enabled, a licensed/reviewed German benchmark must include: correct readings, targeted phoneme/word errors, silence, noise, clipped recordings, and varied speakers. The provider must accept actual audio plus the immutable reference sentence revision, report a versioned score in 0...1 and confidence in 0...1, and return no grade below 0.75 confidence. Target acceptance is >= 90% correct classification on reviewed clean samples, >= 80% detection of targeted errors, and no score for silence/noise/clipping. These thresholds are a product gate, not evidence that any provider currently meets them.
