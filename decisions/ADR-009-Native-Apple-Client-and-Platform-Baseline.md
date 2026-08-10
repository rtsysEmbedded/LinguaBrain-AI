---
title: "ADR-009: Native Apple Client and Platform Baseline"
status: accepted
date: 2026-07-21
decision_makers:
  - Product Owner
  - Apple Platform Architecture Lead
  - UX Lead
  - Privacy and Security Lead
decision_ids:
  - LB-DEC-053
  - LB-DEC-057
work_items:
  - LB-WI-M0-13
supersedes:
  - ADR-008-Initial-Pilot-and-Golden-Layout-Platform
---

# ADR-009: Native Apple Client and Platform Baseline

> **Scope amendment (2026-08-10):** [ADR-014](ADR-014-Optional-Accounts-and-Release-Sync.md) supersedes this record's local-only Release 1.0 account/synchronization exclusion. This ADR remains authoritative for native Apple platforms, capabilities, layout, and stable-toolchain gates.

## Context

LinguaBrain's MVP direction has changed from an Android-first Flutter client to a native Apple-platform product. The learning hypothesis is now tested first on iPhone, while iPad and Mac are first-class MVP surfaces for the same local learning experience. The product is intentionally optimized for Apple platform capabilities such as SwiftUI, SpeechAnalyzer, Foundation Models, native accessibility, platform audio lifecycles, and future App Intents or watchOS extensions.

This change invalidates the operative platform, framework, deployment, and Flutter-golden decisions in ADR-008. It does not erase ADR-008 from history; ADR-008 remains evidence of the earlier decision and is superseded in full by this ADR.

The decision is being recorded while Xcode 27 and the version 27 operating systems are beta software. As of 2026-07-21, Apple's published toolchain baseline is Xcode 27 beta 4, Swift 6.4, the iOS/iPadOS 27 SDK, and the macOS 27 SDK. Apple officially names macOS 27 **Golden Gate**. A provisional development baseline is therefore necessary, but beta screenshots, API behavior, availability, and release assumptions cannot become final release authority.

The first language pair is German and Persian. This creates an important capability constraint: German is currently listed as an Apple Intelligence language, but Persian is not. Apple speech, translation, and foundation-model capabilities must consequently be selected through runtime checks and must have explicit fallbacks. No feature may infer language support solely from the device running OS 27.

## Decision drivers

- Deliver the best native iPhone learning and capture experience with Apple platform conventions.
- Treat iPad and Mac as deliberate MVP products rather than stretched phone screens or implied ports.
- Preserve deterministic learning behavior when speech, translation, or generative-model capabilities are unavailable.
- Keep meeting capture and transcription local-first, consent-driven, and resilient to audio interruptions.
- Establish a reproducible visual and accessibility baseline for Persian RTL and German LTR content.
- Avoid shipping against a beta toolchain or treating beta snapshots as final product evidence.
- Avoid implying cross-device sync merely because the same app is available on multiple Apple devices.
- Remove the maintenance and design cost of Flutter, Dart, Android, and Web targets from the current product scope.
- Leave any future non-Apple client as an explicit product and architecture decision, not a hidden compatibility promise.

## Decision

### Native implementation baseline

The client is implemented natively with **Swift 6.4 and SwiftUI**.

- The Swift 6 language mode is the default for new production targets and packages.
- Swift concurrency, actors, `Sendable` boundaries, and structured cancellation are used for mutable services such as audio capture, transcription, and AI sessions.
- SwiftUI is the presentation framework for iPhone, iPad, and Mac.
- Shared domain and application behavior lives in one or more local Swift packages with no dependency on a concrete view, microphone, model provider, or persistence implementation.
- Platform services are exposed to the application layer through Swift protocols and injected adapters.
- Local persistence is accessed only through repository and transaction protocols. ADR-003 selects the concrete native Swift persistence stack after evaluating SwiftData, Core Data, direct SQLite, GRDB, and other viable adapters; this platform ADR does not preselect one.
- No Flutter or Dart runtime, package, source target, test harness, asset convention, or CI job is part of the accepted architecture.
- Android and Web are not build, release, CI, QA, or support targets.

This ADR does not authorize a mechanical translation of Flutter widgets into SwiftUI. Navigation, layout, commands, menus, window behavior, input, and accessibility are designed for each Apple surface.

### Supported operating systems

The MVP deployment minima are:

| Surface | Minimum deployment target | MVP role |
| --- | --- | --- |
| iPhone | iOS 27.0 | Primary pilot and primary product baseline |
| iPad | iPadOS 27.0 | First-class MVP learning, review, capture, and note surface |
| Mac | macOS 27.0 Golden Gate | First-class MVP learning, review, capture, note, and keyboard-driven surface |

The OS 27 minimum is intentional. The project does not carry compatibility code, test matrices, or release claims for iOS/iPadOS 26 or macOS 26. Xcode 27 can technically deploy to older systems, but that toolchain capability is not the product support contract.

An iOS/iPadOS/macOS SwiftUI multiplatform app target may share settings, resources, and an app lifecycle where that reduces duplication without flattening platform behavior. Platform-specific source, commands, scenes, entitlements, and adapters remain permitted. watchOS, if approved later, uses a separate target as required by Apple's target model.

### MVP surface priority and data boundary

The iPhone is the primary controlled-pilot surface. It owns the canonical first-run, daily check-in, review-session, capture, and recovery acceptance flows.

iPad and Mac are nevertheless first-class MVP surfaces. For every MVP capability declared available on them, they require complete navigation, usable responsive layouts, appropriate input behavior, permissions, local persistence, restart recovery, accessibility evidence, and release validation. They are not allowed to ship as unreviewed scaled variants.

**First-class does not imply synchronization.** The MVP is local-only:

- Each installation has an independent local learner state, review history, notes, recordings, transcripts, settings, and generated content.
- The project does not add an iCloud or CloudKit capability for learner-data sync in the MVP.
- The selected local persistence adapter must not infer or enable CloudKit synchronization.
- Keychain items are nonsynchronizable by default.
- A user signing into the same Apple Account on multiple devices does not imply data parity.
- Marketing, onboarding, settings, support text, and acceptance criteria must state this honestly.
- Cross-device merge, conflict resolution, record identity, account changes, quotas, deletion propagation, and encrypted-field behavior require a later sync ADR before any implementation or claim.

Manual export/import is not created by this decision. If it enters MVP scope, it requires a versioned data contract and privacy review.

### Provisional toolchain and build host

Until Apple ships the stable version 27 toolchain, the development baseline is:

| Input | Provisional baseline |
| --- | --- |
| IDE and SDK | Xcode 27 beta 4 |
| Compiler | Swift 6.4 |
| Host OS | macOS Tahoe 26.4 or later, as required by Xcode 27 beta 4 |
| Host hardware | Apple silicon Mac |
| App SDKs | iOS/iPadOS 27 and macOS 27 |

Xcode 27 is Apple-silicon-only. CI, local setup, and any snapshot authority must therefore run on Apple silicon.

The beta baseline is suitable for implementation, exploration, automated tests, and provisional previews. It is not the golden or release authority. The release baseline changes only after all of the following are true:

1. Apple publishes stable Xcode 27 and final iOS, iPadOS, and macOS 27 releases.
2. App Store Connect accepts the stable toolchain and relevant SDK uploads.
3. The project pins the exact Xcode build, SDK builds, simulator runtimes, Swift version, dependency resolutions, and CI image.
4. All beta API usage is recompiled and retested against final SDK documentation and release notes.
5. The full functional, migration, privacy, accessibility, layout, performance, power, and device matrix passes again.

Until that gate closes, version-27 screenshots and snapshot diffs are advisory and replaceable.

### Canonical native snapshot baseline

LB-DEC-053 is revised from the Flutter/Android fixture in ADR-008 to the following native baseline.

The provisional canonical snapshot surface is an **iPhone 17 Pro simulator running iOS 27 in portrait**. The final simulator runtime and build are pinned only after the iOS 27 GM and stable Xcode 27 are available.

| Property | Canonical native baseline |
| --- | --- |
| Device | iPhone 17 Pro simulator |
| Runtime | Final iOS 27 runtime, exact build pinned after GM |
| Toolchain | Stable Xcode 27, exact build pinned after release |
| Orientation | Portrait |
| Interface locale and direction | Persian (`fa`), RTL |
| Learning-language content | German (`de-DE`) in explicit LTR and bidi-isolated runs |
| Appearance | Light, using versioned design tokens |
| Content size | Default Dynamic Type for the canonical pixel fixture |
| Contrast and motion | Standard contrast; deterministic reduced or settled motion in the harness |
| Clock and data | Fixed clock, stable identifiers, synthetic privacy-safe fixtures |
| Network and AI | Disabled or replaced with deterministic fakes |
| Fonts | Repository-pinned, license-approved fonts with recorded hashes |
| Host | Pinned Apple-silicon CI image |

The canonical snapshot is one regression artifact, not the supported-device contract. Snapshot updates require human review and an intentional change description. A successful pixel comparison cannot replace layout, semantics, VoiceOver, Dynamic Type, input, or real-device tests.

No pre-GM snapshot is authoritative. The project may build the harness and collect provisional baselines during beta development, but it regenerates and reviews all accepted baselines after the release gate.

### Required iPhone, iPad, and Mac matrices

Every critical MVP flow is exercised in the matrix appropriate to its surface. Exact device and OS build identifiers are pinned in test configuration after GM.

#### iPhone matrix

| Fixture | Required evidence |
| --- | --- |
| iPhone 17 Pro portrait | Canonical reviewed snapshots, functional UI tests, mixed-direction assertions |
| Supported compact-width iPhone | No clipped primary action, answer, consent, or recording control; scrolling and focus remain usable |
| iPhone 17 Pro landscape | Reachable controls, readable bilingual content, correct safe-area behavior |
| Physical supported iPhone | Microphone permission, audio route/interruption, background/lock recording policy, SpeechAnalyzer assets, power, and performance |

#### iPad matrix

| Fixture | Required evidence |
| --- | --- |
| 11-inch iPad portrait and landscape | Purposeful navigation and information hierarchy, no phone-width assumptions |
| 13-inch iPad portrait and landscape | Sensible use of space and bounded readable measures |
| Narrow and wide resizable windows | No size-class-only assumption; controls remain reachable at supported window sizes |
| Hardware keyboard and pointer | Complete focus traversal, visible focus, expected shortcuts, hover/context behavior where applicable |
| Physical supported iPad | Microphone, audio route/interruption, background behavior, local persistence, and performance |

#### macOS matrix

| Fixture | Required evidence |
| --- | --- |
| Minimum supported window | No clipped critical content; scrolling, focus, and commands remain available |
| Default window | Reviewed native layout and toolbar/sidebar behavior |
| Wide/full-screen window | Content does not stretch without hierarchy or readable-width limits |
| Keyboard-only operation | Complete traversal, commands, menus, default/cancel behavior, and focus restoration |
| Pointer/trackpad operation | Hover, context menus, selection, drag behavior, and hit regions behave as Mac controls |
| Physical Apple-silicon Mac | Microphone permission, sandbox/hardened-runtime entitlements, audio interruption, local files, restart recovery, and performance |

Critical bilingual states across all surfaces test Persian RTL containers with German LTR words, punctuation, numerals, text fields, selections, and accessibility labels.

### Accessibility acceptance

Accessibility evidence is mandatory and separate from screenshots.

- VoiceOver tests cover onboarding, permission explanations, daily check-in, review, answer feedback, note capture, recording state, transcript editing, error recovery, and deletion.
- Dynamic Type tests include default, the largest standard size, and the largest accessibility size relevant to each critical iPhone and iPad flow. Essential controls and meaning may reflow or scroll but may not disappear.
- macOS supports system text and accessibility settings appropriate to the platform and is verified with VoiceOver and keyboard-only operation.
- Focus order follows reading and task order in both RTL and mixed-direction content.
- Recording, sync absence, offline state, AI availability, errors, and learning feedback are not communicated by color alone.
- All actionable controls have meaningful labels, values, traits, and adequately sized interaction regions.
- iPad and Mac tests include keyboard and pointer paths; touch is never the only way to invoke an essential action on those surfaces.

### Speech and transcription capability policy

SpeechAnalyzer with SpeechTranscriber is the primary Apple-native transcription path. Its use is isolated behind a `SpeechTranscriptionProvider`-style application protocol.

Before offering transcription, the adapter must:

1. Check `SpeechTranscriber.isAvailable` for the actual device.
2. Resolve the requested locale through `supportedLocale(equivalentTo:)` rather than assuming an identifier is supported.
3. Distinguish supported, installed, and downloadable locale assets.
4. Request and monitor asset installation through `AssetInventory` when appropriate and explain downloads before beginning them.
5. Configure the accepted audio format and handle resource, cancellation, interruption, and partial-result behavior.
6. Preserve the original recording independently of volatile transcription results until the user-approved retention policy removes it.

If a requested language or device is unsupported, the app provides an explicit unavailable state. It may offer a separately approved provider or permit recording without transcription; it does not silently upload meeting audio or switch to a server recognizer.

Legacy `SFSpeechRecognizer` is not the default long-form meeting path because Apple documents network requirements for some locales, throttling, and an approximately one-minute recognition-task limit. Any future legacy fallback needs its own permission, privacy, duration, and UX acceptance criteria.

The June 2026 Speech input-provider and converter APIs are beta until the final OS 27 SDK. Their signatures and behavior are revalidated at the release gate.

### Foundation Models and translation capability policy

Foundation Models is an optional enhancement layer, not the learning engine and not a required runtime dependency.

- The application depends on a provider protocol, not directly on `SystemLanguageModel` in domain or learning-rule code.
- Before opening an Apple-model feature, the adapter checks model availability, device eligibility, readiness, region, `supportsLocale(_:)`, and `supportedLanguages`.
- Unsupported-language, unavailable-model, context-limit, safety, cancellation, and resource errors are normal product states with deterministic fallbacks.
- German support does not imply Persian support. Apple's current Apple Intelligence language list includes German but not Persian, so German–Persian card generation, explanation, translation, or summarization cannot rely exclusively on `SystemLanguageModel`.
- The native Translation framework also requires a runtime `LanguageAvailability` check for the actual source/target pair and installed model state.
- A local deterministic template, cached approved content, or a separately configured provider may be used when Apple capabilities are unavailable. The UI identifies material differences in privacy, connectivity, cost, and quality.
- No user note, recording, transcript, or learner profile is transmitted to a third-party model without an explicit, contextual disclosure and consent path.

Private Cloud Compute is not implied by adopting Foundation Models. It is a server execution mode with network, entitlement, eligibility, quota, and release constraints. It cannot enter the MVP critical path without a separate decision and a working offline/degraded path.

### Recording and privacy gates

The following are blocking acceptance criteria for any recording or meeting feature:

- `NSMicrophoneUsageDescription` clearly explains the user-visible purpose before microphone access.
- Permission is requested at first use, not opportunistically during onboarding.
- Recording starts only after a deliberate user action.
- The app displays a persistent, unmistakable visual and/or audible recording indication, including while the app is backgrounded where platform surfaces permit.
- The user can stop recording immediately and can inspect, rename, export if approved, and delete recordings and transcripts.
- The retention and deletion policy covers raw audio, derived transcripts, extracted vocabulary, generated notes, backups, logs, caches, and provider requests.
- iOS/iPadOS background audio mode is enabled only for the user-initiated recording behavior it is intended to support.
- Audio session interruptions, route changes, calls, alarms, lock state, task cancellation, storage exhaustion, thermal pressure, and process termination have tested recovery behavior.
- macOS enables only the required App Sandbox microphone and Hardened Runtime audio-input entitlements and still requests user permission.
- Any third-party AI or transcription path has separate consent and a clear destination/purpose disclosure.
- App privacy disclosures, the public privacy policy, and App Store metadata agree with observed behavior.

The project does not use deferred background-task APIs as a promise of continuous live recording. System-scheduled background work may process, index, or clean up already captured data when appropriate, but it does not replace the foreground/user-initiated audio lifecycle.

### Release authority

An MVP build is not a release candidate until evidence exists for all of the following:

- stable Xcode 27 and final version 27 SDK/runtime pinning;
- successful App Store Connect validation with the stable toolchain;
- no unresolved beta-framework blocker in SwiftUI, the selected persistence stack, Speech, Foundation Models, Translation, or App Intents paths used by the build;
- all advertised device, region, and German/Persian capability claims verified on physical devices;
- canonical post-GM snapshots and all companion layout matrices reviewed;
- VoiceOver, Dynamic Type, keyboard, pointer, reduced-motion, contrast, and mixed-direction tests passed;
- recording consent, indication, background behavior, privacy disclosures, retention, deletion, and provider transmission passed;
- local-only behavior and absence of implied sync verified on iPhone, iPad, and Mac;
- migration, restart, storage-pressure, model-unavailable, speech-asset-unavailable, and offline paths passed.

### Android and non-Apple re-entry gate

Android, Web, Windows, Linux, and other non-Apple clients may re-enter only through a new accepted ADR and funded work item. Re-entry requires:

- evidence of user demand and a named product owner;
- declared feature and data-parity scope;
- a supported OS/device/browser matrix;
- a security, privacy, permissions, accessibility, offline, recovery, QA, CI, distribution, and support plan;
- a versioned interoperability or sync contract if data crosses installations;
- explicit ownership of platform-native UX differences;
- a migration plan that does not compromise the accepted Apple client.

Re-entry does not automatically restore Flutter or Dart. The new decision must compare native, shared-core, and cross-platform approaches using then-current evidence. No dormant Flutter scaffold, Android build, Web target, or compatibility abstraction is maintained in anticipation of that decision.

## Decision identifiers

### LB-DEC-053 — Initial pilot and canonical layout baseline

Re-decided by this ADR:

- iPhone is the primary pilot surface.
- The post-GM iPhone 17 Pro simulator on iOS 27 is the canonical native snapshot baseline.
- iPad and Mac have mandatory companion layout and input matrices.
- Pixel evidence is subordinate to accessibility, input, layout, and physical-device evidence.

### LB-DEC-057 — Native Apple client and platform baseline

Decided by this ADR:

- Swift 6.4 and SwiftUI are the client baseline.
- iOS/iPadOS 27 and macOS 27 Golden Gate are the minimum supported operating systems.
- iPhone, iPad, and Mac are the only accepted MVP client surfaces.
- Xcode 27 beta 4 is provisional; stable Xcode/OS 27 is required for golden and release authority.
- Apple silicon is the required development and CI host architecture.
- Flutter, Dart, Android, and Web are out of scope.

### LB-WI-M0-13 — Native Apple baseline adoption

This ADR, the supersession metadata, and the reconciled active specifications complete LB-WI-M0-13. Creating the workspace and native shell is owned by LB-WI-M1-10; authoritative stable-toolchain release evidence is owned by LB-WI-M6-10. Accepting this baseline therefore does not claim that those implementation or release work items are already complete.

## Supersession of ADR-008

ADR-008 remains in the repository as a historical accepted decision but has no current normative authority. The following ADR-008 decisions are explicitly revoked:

- Android-only M1–M6 pilot and release scope;
- Flutter `3.44.0`, Dart, Material 3, Android SDK, and Android host baselines;
- pure-Dart domain/application packages;
- Flutter platform adapters and Flutter golden harness;
- the `360 × 800`, `TargetPlatform.android` canonical golden fixture;
- Android-first iOS re-entry framing.

Where another document points to ADR-008 for platform or visual-baseline authority, this ADR controls until the reference is updated.

## Not decided here

This ADR does not decide:

- the final physical persistence schema, indexes, migrations, or repository implementation;
- local database file protection, encryption key lifecycle, backup inclusion, or lost-key recovery;
- a CloudKit or other synchronization design;
- a user account or authentication system;
- the final German/Persian typefaces and licenses;
- the exact third-party or local AI providers offered to users;
- pricing, subscriptions, or provider-cost policy;
- a watchOS product commitment;
- a dedicated LinguaBrain hardware implementation;
- a non-Apple client implementation.

## Alternatives considered

### Continue with the Android-first Flutter baseline

Rejected. It contradicts the selected Apple-first product experience and prevents direct use of the newest SwiftUI, Speech, Foundation Models, accessibility, and platform-integration capabilities without additional bridge complexity.

### Retain Flutter for Apple platforms

Rejected. A Flutter iOS/macOS client would preserve framework portability that is no longer a current product requirement while weakening the native-only architecture decision and retaining Dart, plugin, embedding, and platform-adapter complexity.

### Support OS 26 and OS 27

Rejected for the MVP. Supporting OS 26 would enlarge API-availability, UI, speech, model, test, and fallback matrices. The project deliberately optimizes for version 27 and accepts the smaller eligible-device population.

### Ship only on iPhone

Rejected. iPad and Mac are valuable learning, meeting-note, and keyboard-oriented contexts and are accepted first-class MVP surfaces. iPhone remains the primary pilot so evidence collection and the canonical baseline stay focused.

### Enable CloudKit automatically because all clients are Apple clients

Rejected. Availability on multiple devices is not a sync design. Automatic sync introduces identity, conflict, schema, account, quota, deletion, recovery, and privacy behavior that needs its own decision and evidence.

### Use an unpinned beta simulator as golden authority

Rejected. Beta SDKs, runtimes, fonts, SwiftUI rendering, and system design can change. Beta snapshots are provisional and must be regenerated after GM.

### Make Apple Foundation Models the only AI provider

Rejected. Availability depends on device, region, readiness, and language. Persian is not currently an Apple Intelligence-supported language, so an Apple-only model path cannot fulfill the first language pair.

## Consequences

### Positive

- The app can use Apple platform capabilities directly and adopt native interaction and accessibility behavior.
- Swift concurrency provides clear isolation for audio, transcription, and model sessions.
- iPhone pilot evidence remains focused while iPad and Mac receive explicit quality matrices.
- The OS 27 minimum removes backward-compatibility branches during the MVP.
- Runtime capability checks make unsupported languages, devices, regions, and assets honest product states.
- Local-only scope avoids accidental or underdesigned sync behavior.
- The stable-toolchain gate prevents beta artifacts from silently becoming release authority.

### Negative

- The MVP excludes users on older Apple operating systems and unsupported hardware.
- The product has no Android or Web client.
- Three Apple surfaces still require distinct layout, input, permission, and release testing.
- Development and CI require Apple-silicon Macs.
- Persian support requires non-Apple-model or deterministic fallback paths for some AI and translation features.
- Beta development may require rework when final SDKs ship.
- Local-only state can differ across a learner's iPhone, iPad, and Mac.

### Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Beta API or rendering changes invalidate work | Treat Xcode/OS 27 as provisional, pin only after GM, and rerun the full release matrix. |
| Shared SwiftUI code creates lowest-common-denominator UX | Permit platform-specific scenes, commands, layouts, and adapters; enforce iPad and Mac acceptance matrices. |
| Persian requests fail in Apple models | Check locale support at runtime and provide explicit deterministic or separately approved provider fallbacks. |
| Speech assets are missing or unsupported | Check device and locale capability, manage AssetInventory, and preserve record-without-transcription behavior. |
| Meeting audio is uploaded without informed consent | Prohibit silent provider switching; require contextual consent and destination disclosure. |
| Background recording stops or corrupts state | Test interruption, route, lock, storage, cancellation, and restart recovery on physical devices. |
| Users assume Apple-device sync | Keep CloudKit disabled, use nonsynchronizable Keychain items by default, and state local-only behavior in product copy. |
| Canonical screenshot becomes a fixed-layout specification | Require companion device/window matrices, Dynamic Type, VoiceOver, keyboard, pointer, and real-device evidence. |
| Flutter assumptions survive in documentation or CI | Track their removal under LB-WI-M0-13 and treat this ADR as controlling during cleanup. |
| Future Android demand forces an accidental architecture fork | Require the non-Apple re-entry ADR, product scope, and interoperability contract before implementation. |

## Acceptance evidence

- This ADR exists with `status: accepted`, date `2026-07-21`, and identifies LB-DEC-053, LB-DEC-057, and LB-WI-M0-13.
- ADR-008 is explicitly superseded and no longer controls platform, framework, or snapshot decisions.
- The Xcode project uses Swift 6.4/Swift 6 language mode and contains only accepted Apple app targets and shared Swift packages.
- Deployment targets are iOS 27.0, iPadOS 27.0, and macOS 27.0.
- No operative Flutter, Dart, Android, or Web target remains in build, CI, QA, release, or support scope.
- The iPhone 17 Pro canonical snapshot harness exists provisionally and is regenerated against pinned GM/stable inputs.
- iPad and Mac matrices, VoiceOver, Dynamic Type, keyboard, pointer, mixed-direction, and physical-device suites are executable release checks.
- Speech, Translation, and Foundation Models adapters expose runtime capability and unsupported-language states.
- Persian-unavailable Apple-model behavior has an accepted fallback and test evidence.
- Microphone permission, recording indication, retention/deletion, interruption, background, and third-party disclosure gates pass.
- iPhone, iPad, and Mac stores remain local and no sync claim appears.
- Stable Xcode/OS 27 and App Store validation close the golden/release authority gate before distribution.

## Follow-up actions

- [ ] Create the native Xcode 27 workspace, Swift packages, multiplatform SwiftUI app target, and test targets under LB-WI-M1-10.
- [x] Remove operative Flutter/Dart/Android/Web assumptions from active specifications and repository ignores without deleting historical ADR evidence; no production Flutter build or CI target existed.
- [ ] Set iOS/iPadOS/macOS deployment minima to 27.0 and enable Swift 6 language mode.
- [ ] Pin Xcode 27 beta 4 only as a provisional developer input; replace it with the stable build after release.
- [ ] Build the provisional iPhone 17 Pro snapshot harness with deterministic Persian/German fixtures.
- [ ] Define and automate the iPad and macOS layout/input matrices.
- [ ] Add VoiceOver, Dynamic Type, keyboard, pointer, mixed-direction, and reduced-motion acceptance suites.
- [ ] Implement SpeechAnalyzer/SpeechTranscriber capability and asset checks behind an application protocol.
- [ ] Implement Foundation Models and Translation capability/language checks with tested Persian fallbacks.
- [ ] Implement explicit microphone consent, recording indication, interruption, background, retention, and deletion flows.
- [ ] Keep the selected persistence adapter local-only and Keychain items nonsynchronizable until a later sync decision.
- [ ] Re-pin the toolchain, runtime, simulator, fonts, dependencies, and snapshots after the OS 27 GM.
- [x] Update decision registers, project status, roadmap, specifications, and change log to reference ADR-009 in the work item that owns documentation reconciliation.

## Official references

- [Apple: macOS 27 Golden Gate](https://www.apple.com/la/os/macos/)
- [Apple Developer: macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes)
- [Apple Developer: Xcode SDK and system requirements](https://developer.apple.com/xcode/system-requirements)
- [Apple Developer: Upcoming App Store requirements](https://developer.apple.com/news/upcoming-requirements/)
- [Apple Newsroom: Xcode 27, Swift 6.4, and 2027 frameworks](https://www.apple.com/newsroom/2026/06/apple-aids-app-development-with-new-intelligence-frameworks-and-advanced-tools/)
- [Apple Developer: Configuring a multiplatform app](https://developer.apple.com/documentation/xcode/configuring-a-multiplatform-app-target)
- [Apple Developer: What's new in SwiftUI](https://developer.apple.com/swiftui/whats-new/)
- [Apple Developer: What's new in SwiftData](https://developer.apple.com/videos/play/wwdc2026/274/)
- [Apple Developer: SwiftData CloudKit synchronization constraints](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- [Apple Developer: SpeechAnalyzer](https://developer.apple.com/documentation/speech/speechanalyzer)
- [Apple Developer: Speech updates](https://developer.apple.com/documentation/updates/speech)
- [Apple Developer: SpeechTranscriber capability and locale checks](https://developer.apple.com/documentation/speech/speechtranscriber)
- [Apple Developer: Speech AssetInventory](https://developer.apple.com/documentation/speech/assetinventory)
- [Apple Developer: Speech recognition permissions and SpeechAnalyzer privacy](https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition)
- [Apple Developer: Legacy SFSpeechRecognizer limits](https://developer.apple.com/documentation/speech/sfspeechrecognizer)
- [Apple Developer: Foundation Models](https://developer.apple.com/documentation/foundationmodels/)
- [Apple Developer: SystemLanguageModel availability](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)
- [Apple Developer: Foundation Models language and locale support](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models)
- [Apple: Current Apple Intelligence language and device availability](https://www.apple.com/de/newsroom/2026/06/apple-intelligence-brings-powerful-ai-capabilities-into-everyday-experiences/)
- [Apple Developer: Translation LanguageAvailability](https://developer.apple.com/documentation/translation/languageavailability)
- [Apple Developer: Translation strategies](https://developer.apple.com/documentation/translation/translationsession/strategy)
- [Apple Developer: Microphone recording permission](https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission%28completionhandler%3A%29)
- [Apple Developer: AVAudioSession recording and background behavior](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/record)
- [Apple Developer: Choosing background execution strategies](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app)
- [Apple Developer: App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple Developer: Configuring the macOS App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)
- [Apple Developer: Configuring the Hardened Runtime](https://developer.apple.com/documentation/xcode/configuring-the-hardened-runtime)
- [Apple Developer: Keychain Services](https://developer.apple.com/documentation/security/keychain-services/)
- [Apple Developer: Synchronizable Keychain items](https://developer.apple.com/documentation/security/ksecattrsynchronizable)
