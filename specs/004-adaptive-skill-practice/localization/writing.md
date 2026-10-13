# Writing practice localization

The writing story uses the shared `practice.shared.*` copy plus these keys in
the three app catalogs (`fa.json`, `en.json`, and `de.json`):

| Key | Meaning |
| --- | --- |
| `practice.writing.title` | Writing practice |
| `practice.writing.instruction` | Write a sentence with the target word. |
| `practice.writing.description` | Use the word naturally; the evaluator preserves your original response. |
| `practice.writing.targetWord` | Target word |
| `practice.writing.answerLabel` | Your sentence |

All values must be non-empty and localized. The answer editor follows the
target-language direction independently from the interface language.
