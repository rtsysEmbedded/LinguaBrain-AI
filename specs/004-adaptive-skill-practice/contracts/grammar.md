# Grammar practice contract — `grammar-practice-v1`

This contract defines a small, curated grammar bank. A template contains learner/source/target languages, CEFR level, one objective, one target rule, one prompt, a traceable reference answer and explanation, clean-source metadata, and optional demonstration, cloze scaffolding, and up to three progressive hints.

The initial rule allow-list is `de.word_order.verb_final`, `de.verb.inflection`, `de.article.case`, `de.conjunction.weil`, and `de.preposition.case`. Conjunction and preposition roles are explicit (`subordinate_conjunction` and `preposition_case`); a role mismatch is rejected. A prompt must contain exactly one issue and must not be ambiguous. Unsupported languages, dirty/generated sources, empty content, duplicate or excessive hints, unknown rules, and multiple issues never enter the exercise queue.

`explainError` and `explainUsage` both require the learner to explain the rule. A correction or cloze is scaffolding only and never substitutes for that explanation. The reference answer and explanation remain traceable through the rule code, contract version, and curated provenance. The factory creates a stable grammar ReviewUnit identity and deterministic exercise identity from learner, objective, rule, mode, and prompt.

The factory is pure application logic. It does not call a provider, create canonical learner content, persist attempts, or change mastery/FSRS. Evaluation and scheduling remain behind their existing ports.
