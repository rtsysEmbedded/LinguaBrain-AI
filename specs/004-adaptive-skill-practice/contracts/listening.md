# Listening practice contract — `listening-evidence-v1`

Listening evaluates meaning recalled from the exact sentence revision that was played. The input includes sentence ID/revision, source and learner language, locale, audio checksum, transcript/translation held behind the reveal boundary, and the learner's paraphrase. A valid result distinguishes preserved meaning, changed meaning, and uncertain meaning; negation, tense, participants, and modality are semantic slots and must not be silently dropped.

The evaluator compares semantic slots rather than spelling in the learner
language. Agent, patient, action, negation, number, time/tense and modality are
scored independently. A paraphrase that preserves all material slots is
`correct`; one that preserves the main event but omits a material secondary
slot is `partial`; reversing negation, replacing the agent/action, or changing a
material number/time is `incorrect`. Orthographic or punctuation differences
in the learner-language response do not reduce comprehension unless they make
the intended meaning genuinely ambiguous.

Only the exact sentence revision may be assessed. A missing sentence, missing audio, checksum mismatch, unsupported locale, transport failure, cancellation, malformed output, or low confidence produces unavailable/ungraded evidence. The provider returns a proposal with bounded score/confidence, typed feedback, affected semantic slots, and provenance; it never writes sentences, mastery, history, or schedules. Audio replay and rate changes do not change the evaluated revision.

The application supplies sentence/audio context through an injected resolver;
the provider may not reconstruct a transcript from the visible prompt or use a
word card's accepted meanings. The resolver must return the same sentence ID
and revision as the `ReviewUnit`, a nonempty reviewed sentence translation, and
a nonempty checksum for the audio that was actually played. A mismatch is
malformed/unavailable evidence and is never graded as wrong.
