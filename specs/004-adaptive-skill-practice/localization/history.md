# Sentence-learning history localization

The `practice.history.*` keys are maintained in the established Persian, English, and German JSON catalogs:

- `apps/learner/Resources/Localization/fa.json`
- `apps/learner/Resources/Localization/en.json`
- `apps/learner/Resources/Localization/de.json`

The history surface uses localized labels for original response, correction, natural variant, rules, selection reason, next exercise, mastery, unknown state, and accept/decline/edit actions. Planner reason codes are rendered through localized `practice.history.reason.*` keys; they are not shown as raw enum values.
