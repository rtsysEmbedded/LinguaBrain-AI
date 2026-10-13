# Writing evaluation contract — `writing-evaluation-v1`

This contract defines a provider-neutral proposal for evaluating a learner's
sentence-writing attempt. It is a rubric and wire-shape boundary for T012;
the production decoder/adapter belongs to T013. Fixtures are synthetic and
must never be treated as learner history or canonical content.

## Input context

Every request contains:

| Field | Contract |
| --- | --- |
| `learnerID` | Non-empty opaque local identifier. It is carried for correlation only and must not be logged. |
| `sourceLanguage`, `targetLanguage` | BCP-47 language tags. T012 fixtures use the supported `fa`, `de`, and `en` tags. |
| `cefrLevel` | One of `A1`, `A2`, `B1`, `B2`, `C1`, `C2`. |
| `targetWord` | The target lexical item or lemma, 1–120 Unicode scalar characters. |
| `partOfSpeech` | One of `noun`, `verb`, `adjective`, `adverb`, `preposition`, `conjunction`, `pronoun`, `article`, `phrase`, or `other`. |
| `exerciseObjective` | Versioned objective; T012 uses `write_sentence_with_target_word`. |
| `sentenceRevision` | Positive integer identifying the immutable sentence revision. |
| `allowedContext` | Bounded exercise context, at most 500 Unicode scalar characters. It may describe register, topic, and intended sense, but must not disclose a hidden answer unnecessarily. |
| `learnerSentence` | The exact original learner response, at most 500 Unicode scalar characters. It is immutable evidence and must be copied byte-for-byte into the output. |

The evaluator may use the target word, part of speech, CEFR level, sentence
revision, and allowed context to assess the response. It must not infer an
unstated learner intention from a short or ambiguous sentence.

## Output shape

The versioned JSON object contains `schemaVersion`, `fixtureID` (fixtures only),
`input`, and `output`. A production response keeps the same `input`/`output`
shape but does not use fixture identity as learner evidence.

`output` contains:

```json
{
  "outcome": "correct | partial | incorrect | unavailable",
  "meaningAssessment": {
    "status": "preserved | partiallyPreserved | changed | uncertain",
    "confidence": 0.0
  },
  "originalLearnerSentence": "exact input learnerSentence",
  "minimalCorrection": "string or null",
  "naturalVariant": "string or null",
  "explanation": { "language": "fa", "text": "..." },
  "feedback": [{ "type": "grammar | vocabulary | meaning | style | targetWord", "message": "...", "severity": "info | warning | error" }],
  "ruleReferences": [{ "id": "de.word_order.verb_final", "category": "grammar | vocabulary | meaning | style" }],
  "affectedSpans": [{ "start": 0, "end": 4, "text": "...", "category": "grammar | vocabulary | meaning | style", "ruleID": "..." }],
  "score": 0.0,
  "confidence": 0.0,
  "unavailableReason": "uncertainIntent | unsupportedLanguage | lowConfidence | malformedOutput | providerUnavailable | cancelled | null",
  "provenance": {
    "provider": "...",
    "model": "...",
    "evaluatorVersion": "...",
    "schemaVersion": "writing-evaluation-v1",
    "promptVersion": "writing-rubric-v1",
    "validatorVersion": "..."
  },
  "approvalPolicy": "autoApproveAllowed | humanReviewRequired",
  "canonicalContentAction": "none",
  "masterySchedulingMutation": false
}
```

For `correct`, `partial`, and `incorrect`, `score` and `confidence` are
required finite numbers in `[0, 1]`, with confidence at least `0.70`.
`unavailable` is ungraded: score and confidence are `null`, and
`unavailableReason` is required. Transport failure, cancellation, unsupported
language, malformed output, low confidence, and uncertain intent all remain
unavailable; none may be converted to `incorrect`.

`originalLearnerSentence` is required and must equal the input exactly.
`minimalCorrection` is only a grammatical/lexical correction that preserves
the likely meaning. It must be `null` for a correct response unless a separate
`naturalVariant` is useful. `naturalVariant` is optional, everyday phrasing;
it is never a required correction and never canonical learning content.

## Rubric distinctions

- Grammatical error: word order, agreement, inflection, case, article, or
  separable-verb placement. Return the smallest meaning-preserving correction.
- Vocabulary error: a missing, unrelated, or wrong target word. Do not invent a
  replacement sentence when the intended meaning is unknown; use partial,
  incorrect, or unavailable as justified by evidence.
- Meaning-changing correction: a proposed correction changes the learner's
  actor, event, polarity, modality, time, or other likely intent. Set meaning
  status to `changed`, use `humanReviewRequired`, and never auto-approve it.
- Style-only suggestion: optional naturalness, register, or word-order polish
  that leaves grammar and meaning valid. Keep the outcome correct, leave
  `minimalCorrection` null, and place the suggestion in `naturalVariant` or a
  style feedback item.
- Inflectionally valid or separable alternatives: accept valid inflections and
  separated forms of the target verb. The lemma need not appear literally.

## Uncertainty and safety

Return `unavailable` with `uncertainIntent` when context is insufficient,
multiple meanings remain plausible, text is too fragmentary to assess, or a
correction would require guessing. Return `unsupportedLanguage` when either
language tag is outside the configured support set. A provider must not emit a
confident-looking answer merely to fill a field.

The evaluator returns a proposal only. It cannot create a `Sentence` revision,
approve canonical learning content, append an attempt, change mastery, or
change an FSRS schedule. The application layer validates the proposal and the
review service alone decides whether independent evidence is eligible.

## Limits and validation rules

- Maximum learner/context/correction/variant/explanation text: 500 Unicode
  scalar characters; a feedback message: 240.
- Maximum feedback items: 8; maximum rule references: 8; maximum spans: 8.
- A span is a half-open Unicode-scalar range `[start, end)` within the original
  learner sentence, with `start >= 0`, `end > start`, and `text` exactly equal
  to that range. Spans cannot overlap unless they have distinct rule IDs.
- Rule IDs are non-empty, lowercase dotted identifiers and must be in the
  reviewed allowlist: `de.word_order.verb_final`, `de.verb.separable`,
  `de.verb.inflection`, `de.lexical.target_missing`, `de.lexical.unrelated`,
  `meaning.intent_uncertain`, or `style.naturalness`.
- Language tags are non-empty BCP-47 primary tags and must be supported by the
  configured writing evaluator; this fixture corpus intentionally uses only
  `fa`, `de`, and `en`.
- Scores and confidences are finite and bounded. Values outside `[0, 1]`, NaN,
  infinity, or confidence below `0.70` are rejected or normalized to
  unavailable by the later adapter.
- `canonicalContentAction` must be `none` and `masterySchedulingMutation`
  must be `false` for every provider proposal.
- `approvalPolicy` is `humanReviewRequired` for changed meaning, uncertain
  intent, or any output that proposes content beyond a minimal correction.

## Synthetic corpus

`packages/LinguaBrainKit/Tests/LinguaBrainAITests/Fixtures/practice-writing.json`
contains accepted examples for correct/no correction, verb position,
separable/inflectionally valid forms, missing or unrelated target vocabulary,
partial meaning-preserving response, meaning-changing correction, ambiguity,
and style-only improvement. It also contains rejected/normalized examples for
malformed payloads, unsupported language, low confidence, provider unavailable,
and cancellation. No fixture contains private learner data or credentials.
