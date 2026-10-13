# Interface Localization

All learner-facing interface text lives in `fa.json`, `en.json`, and `de.json` in this directory. Swift source must not contain interface copy; it references keys.

## Files

| File | Language | Layout |
| --- | --- | --- |
| `fa.json` | Persian | Right-to-left |
| `en.json` | English | Left-to-right; also the fallback for missing keys |
| `de.json` | German | Left-to-right |

Each file is a flat JSON object of `"key": "value"` pairs. All three files must contain exactly the same keys.

Two related resources are separate on purpose:

- `../InfoPlist.xcstrings` holds the system permission prompts (`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`), because iOS and macOS read those strings from the Info.plist localization, not from app code.
- `../Localizable.xcstrings` keeps only the few entries that Xcode extracts automatically from string interpolations and language-code pickers. It is not a source of interface copy.

## Keys

- Use stable, dotted, ASCII identifiers grouped by screen or feature, for example `today.startReview`, `library.cards.deleteTitle`, `apkg.error.unsafePath`.
- Shared words use the `common.` prefix (`common.cancel`, `common.ok`, `common.delete`).
- Never use a sentence in any language as a key.
- Keys built from enum raw values are allowed when every case has an entry, for example `addWord.section.<AddSection>` or `cutover.recovery.<PracticeCutoverFailure>`.

## Placeholders

| Marker | Meaning |
| --- | --- |
| `%@` | Next argument, in order |
| `%1$@`, `%2$@`, … | Argument by position; use these when languages need a different order |

All three languages must use the same set of markers for a key. Numbers are passed as already-formatted strings.

## Lookup in code

| API | Use |
| --- | --- |
| `localization.localized("key")` | Views. Reads the injected `PrototypeLocalization`, so a language change re-renders the view. |
| `localization.formatted("key", arg1, arg2)` | Views, with placeholder substitution. |
| `localization.minutesLong(20)` | "20 minutes" with digits in the interface language's numbering system (for example ۲۰ in Persian). |
| `PrototypeLocalization.current("key", args…)` | Code outside the SwiftUI environment, such as models and `LocalizedError` descriptions. Uses the persisted interface language. |

Lookup order: the selected language, then English, then the key itself. A key that appears unchanged in the UI therefore indicates a missing entry.

Substitution works on Unicode scalars. A placeholder followed by a zero-width non-joiner (common in Persian, as in `%@‌ها`) is still replaced; substituted text is never scanned again.

## Content that is not interface copy

These stay out of the localization files:

- Learner and card content (words, meanings, examples) — imported, generated, or seeded data.
- Stored identifiers such as deck names and the default domain, whose values must not change with the interface language.
- File-format field names (TSV header, Anki note fields) and protocol identifiers.

## Checks before committing

1. All three files parse as JSON and have identical key sets.
2. Every key has the same placeholder markers in all languages.
3. No `en` or `de` value contains Persian script, except language endonyms such as `language.nativeName.fa`.
4. Every literal key used in Swift exists in the files.
