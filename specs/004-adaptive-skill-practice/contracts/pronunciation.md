# Pronunciation assessment contract — `pronunciation-evidence-v1`

Input is a consented, temporary audio recording plus immutable reference sentence ID, revision, language, and audio checksum. Transcript-only input is invalid. A proposal contains provider/model/algorithm versions, a score and confidence in `0...1`, optional word/sound spans, typed feedback, and explicit unavailable reasons for silence, noise, clipping, cancellation, unsupported language, or low confidence.

No provider may write attempts, mastery, FSRS state, or sentence content. Below the approved confidence threshold, or without an approved audio-based provider, the outcome is `unavailable` and no mastery/scheduling handoff occurs. Recordings are temporary by default; retention/export requires a separate opt-in.
