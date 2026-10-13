# Shared practice localization and surface QA

The shared Feature 004 scaffold uses the repository's JSON localization
workflow (`apps/learner/Resources/Localization/*.json`). The String Catalog is
not a second source for these keys. The `practice.shared.*` namespace contains
61 keys and has matching, non-empty, non-key values in `fa.json`, `en.json`,
and `de.json`.

Validation from the repository root:

```sh
ruby -rjson -e 'paths=%w[fa en de].map{|x| "apps/learner/Resources/Localization/#{x}.json"}; docs=paths.map{|p| JSON.parse(File.read(p))}; keys=docs.map{|d| d.keys.grep(/\Apractice\.shared\./)}; abort "key sets differ" unless keys.uniq.length==1; keys[0].sort.each{|k| docs.each_with_index{|d,i| v=d[k]; abort "missing #{k} in #{paths[i]}" unless v.is_a?(String)&&!v.empty?&&v!=k}}; puts "practice.shared localization: #{keys[0].length} keys present and non-fallback in fa/en/de"'
jq empty apps/learner/Resources/Localization/fa.json apps/learner/Resources/Localization/en.json apps/learner/Resources/Localization/de.json
```

The answer editor and answer-language feedback use the BCP-47 primary tag:
`fa`, `ar`, `he`, `ur`, `ps`, `ku`, `dv`, and `yi` are RTL; German, English,
and unknown tags are LTR. This is applied only to answer content. The app
interface continues to receive its own `layoutDirection` from
`PrototypeLocalization`, so Persian UI with a German answer remains RTL UI and
LTR answer text.

## Repeatable automated evidence

- `PracticeSessionModelTests.testAnswerTextDirectionFollowsAnswerLanguageNotInterfaceLanguage`
  checks `fa`, `fa-IR`, `de-DE`, and `en_US` under an RTL interface.
- `PracticeSessionModelTests.testScaffoldRendersNarrowLargeTextSurfaceWithoutExposingAnswerBeforeReveal`
  renders the answering surface at 280 points with `.accessibility5`, Persian
  interface direction, and a German answer language. `ImageRenderer` succeeds;
  the reference-answer visibility policy remains false before reveal.
- `PracticeSessionModelTests.testScaffoldRendersEverySharedStateAtSupportedSmokeWidths`
  renders answering, evaluating, feedback, revealed, unavailable, finished,
  empty, and recoverable-failure at 280, 320, and 744 points with
  `.accessibility5`. Loading is verified as a transient state by the existing
  delayed-operation/cancellation test and is never treated as an endless state.
- All action labels and hints are separate localized values for hint, reveal,
  skip, retry, continue, resume, copy-answer, and submit. Header, prompt,
  answer, feedback, progress, state panels, and the answer control have
  explicit accessibility grouping/order or label/value semantics. The model
  answer closure is not evaluated in answering/evaluating states, so hidden
  answer text is absent from those rendered trees.

## Manual accessibility procedure and limits

The repository currently has a unit-test target with no ViewInspector or
XCUI/VoiceOver assertion target. Use the following repeatable procedure for
manual sign-off:

1. Boot the iPhone 17 iOS 27.0 Simulator (`774C6821-2D4D-4A8A-8F8E-B902FECF2C0D`)
   and install the Debug app built by the T011 verification command. The
   current production route intentionally has no exercise factory and therefore
   shows the honest empty state; use a QA-only synthetic fixture/preview to
   expose the remaining states.
2. Set the interface to Persian, enable VoiceOver, and open the shared practice
   route with that injected synthetic exercise. Traverse loading, answering,
   evaluating, feedback, revealed, unavailable, finished, and recoverable
   failure states with swipe navigation. Confirm the order is header/progress,
   instruction, prompt, answer, feedback/help, then actions; confirm the model
   answer is not announced before reveal.
3. Repeat with English and German interface settings, German and Persian answer
   tags, and the Dynamic Type Accessibility 5 setting. Confirm answer text
   direction follows the answer tag rather than the interface direction.
4. Repeat at iPhone narrow width, iPad split/narrow width, and a narrow Mac
   window. Use Tab/Return/arrow-key navigation where the platform provides it;
   confirm actions remain reachable and the ScrollView prevents clipping.

Automated evidence observed the expected non-zero rendered surfaces on the
iPhone 17 Simulator and passed 14 model/scaffold tests. Runtime VoiceOver
traversal of synthetic non-empty states was not executable because the current
app route has no QA fixture injection and the test target has no XCUI/VoiceOver
assertion harness; the available empty production state was covered by the
render smoke. A physical-device pass was not executable, so this record makes
no physical-device claim and retains the manual procedure as the release QA
limitation. Mac Dynamic Type is
also platform-limited by SwiftUI and is covered here by semantic fonts and the
macOS Debug build, not by a false runtime Dynamic Type claim.

The implementation follows the current Xcode 27 declarations for
`accessibilityLabel`, `accessibilityHint`, `accessibilitySortPriority`,
`dynamicTypeSize`, `layoutDirection`, `ViewThatFits`, `keyboardShortcut`, and
`onDisappear`. The relevant official references are Apple's
[DynamicTypeSize](https://developer.apple.com/documentation/swiftui/dynamictypesize),
[layoutDirection](https://developer.apple.com/documentation/swiftui/environmentvalues/layoutdirection),
[accessibility sort priority](https://developer.apple.com/documentation/swiftui/view/accessibility%28sortpriority%3A%29),
and [Environment](https://developer.apple.com/documentation/swiftui/environment).
