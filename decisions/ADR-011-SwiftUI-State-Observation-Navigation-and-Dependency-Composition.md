---
title: "ADR-011: SwiftUI State, Observation, Navigation, and Dependency Composition"
status: accepted
date: 2026-08-01
decision_makers:
  - Apple Client Architect
  - Software Architect
  - UX Lead
decision_ids:
  - LB-DEC-058
work_items:
  - LB-WI-M0-15
---

# ADR-011: SwiftUI State, Observation, Navigation, and Dependency Composition

## Context

LinguaBrain needs one native presentation architecture for iPhone, iPad, and Mac before the M1 application shell begins. The architecture must support SwiftUI's platform-adaptive containers without moving learning rules, persistence, AI routing, or media behavior into views.

The application has several kinds of state with different lifetimes:

- durable learner state owned by repositories and application use cases;
- scene/window navigation state;
- feature presentation state such as loading, content, validation, and recoverable errors;
- short-lived view state such as focus, disclosure, selection, and animation;
- long-running, cancellable work such as recording, transcription, AI enrichment, and review sessions.

The design must remain testable with deterministic fakes, work with strict Swift 6 concurrency, preserve independent Mac windows and Apple-device installations, and avoid a global state container becoming a second database or learning engine.

## Decision drivers

- Use the native Swift 6.4 and SwiftUI 27 programming model.
- Make ownership and lifetime of state visible.
- Keep the domain/application layers independent of SwiftUI and Observation.
- Use typed, testable navigation across compact and regular Apple surfaces.
- Support scene-specific state and restoration without persisting domain objects in navigation paths.
- Make async work cancellable and actor-safe.
- Permit previews, unit tests, view tests, and XCUITest to substitute deterministic dependencies.
- Avoid third-party state-management and dependency-injection frameworks until evidence justifies one.

## Decision

### Observation baseline

Presentation models use the native Observation framework.

- Feature models are reference types annotated with `@Observable` and isolated to `@MainActor`.
- A SwiftUI owner keeps a feature or scene model in `@State`.
- Descendant views receive observable models explicitly and use `@Bindable` only when they need bindings.
- Small value-type UI state stays in private `@State`, `@FocusState`, or platform SwiftUI state wrappers.
- `ObservableObject`, `@Published`, `@StateObject`, and `@EnvironmentObject` are not the default for new production code. They are allowed only at a documented legacy/framework interoperability boundary.
- Observation types belong to `LinguaBrainPresentation` or `apps/learner`, never `LinguaBrainDomain` or `LinguaBrainApplication`.

Observation controls rendering invalidation; it does not define the canonical data model, transaction model, or event bus.

### State ownership and lifetimes

| State category | Owner | Lifetime | Rule |
| --- | --- | --- | --- |
| Domain and learner data | Repositories/application services | Durable | Never duplicated as an authoritative UI store |
| App dependencies | Composition root | Process or scene, explicitly declared | Immutable references to protocols/adapters |
| Scene navigation | Scene-owned navigation model | One window/scene | Never a process-global singleton |
| Feature presentation | `@MainActor @Observable` feature model | Feature flow | Derived from use-case results and replaceable in tests |
| View mechanics | SwiftUI view | View identity | Focus, disclosure, transient selection, animation only |
| Long-running service state | Actor-backed application/platform adapter | Operation/session | Exposed through typed async APIs and cancellable tasks |

Feature models may cache read models for presentation, but after a command they refresh from the application boundary or consume an authoritative result. They do not mutate repository records, FSRS state, mastery, or graph data directly.

### Feature model contract

Each non-trivial feature uses a small `@MainActor @Observable` model with:

- an explicit, finite presentation phase such as `idle`, `loading`, `content`, `empty`, or `failed`;
- immutable view-facing read models wherever practical;
- intent-named methods such as `load()`, `saveDraft()`, or `submitAnswer()`;
- injected use-case protocols rather than concrete persistence/provider clients;
- typed recoverable errors mapped to user actions;
- task ownership and cancellation when a feature disappears or a new intent supersedes old work.

Views render state and send intents. They do not contain business decisions or infrastructure calls.

### Dependency composition

`apps/learner` is the only production composition root.

- Dependencies are expressed as narrow Swift protocols owned by the inward layer that consumes them.
- Concrete persistence, review, AI, media, security, and Apple-platform adapters are created at launch and passed through initializer injection.
- `AppDependencies` is an immutable composition value containing protocol-typed services. It is not a mutable service locator and exposes no global `shared` instance.
- Root feature factories may close over `AppDependencies` to construct feature models with explicit inputs.
- SwiftUI environment injection is reserved for genuinely hierarchy-wide, UI-facing dependencies or scene models. Required dependencies are inserted at the root; production code does not rely on hidden fallback implementations.
- Feature views prefer initializer injection. Environment access must stay at a documented presentation boundary and must not be used by domain/application code.
- Tests and previews build the same composition interfaces with fakes, fixed clocks, deterministic IDs, and in-memory repositories.

No third-party DI container is adopted for the MVP. A future container requires measured composition complexity, startup/test evidence, and a new ADR.

### Navigation model

Navigation uses lightweight, typed values rather than views or domain objects.

```swift
enum AppSection: Hashable, Codable {
    case today
    case library
    case add
    case progress
    case settings
}

enum AppRoute: Hashable, Codable {
    case knowledgeItem(id: UUID)
    case reviewSession(id: UUID)
    case validationProposal(id: UUID)
    case settings(destination: SettingsRoute)
}
```

- `NavigationStack` uses typed routes and `navigationDestination(for:)` on compact surfaces and focused flows.
- `NavigationSplitView` owns sidebar/content/detail selection on regular iPad and Mac windows.
- One scene-owned `NavigationModel` stores selected section, typed path, sheet/item presentation, and split-view selection required for that scene.
- Routes contain stable identifiers and small value types, not repositories, feature models, provider clients, or full domain entities.
- Deep links and restoration payloads parse into typed routes through one application-owned route parser. Invalid or no-longer-valid identifiers produce a recoverable destination, not a crash.
- Modal presentation uses optional identifiable values or explicit presentation enums instead of unrelated Boolean combinations.

The same information architecture may render with different native containers. This is intentional platform adaptation, not navigation-state duplication.

### Scene and window behavior

- Every iPhone/iPad scene and every Mac window receives its own navigation model.
- Global mutable navigation singletons are prohibited.
- Mac commands act on the focused scene/window through SwiftUI focused values or explicit scene coordination.
- A new Mac window begins from an explicit route/selection and does not steal another window's path.
- Navigation restoration is best-effort presentation state. Canonical learner data remains in repositories.
- Restored routes are validated against the current schema, authorization, local-store availability, and item existence before display.

### Concurrency and cancellation

- Presentation models are `@MainActor`; they update UI-observed state only on the main actor.
- Application and adapter protocols declare `Sendable` and actor isolation where appropriate.
- Long-lived mutable services such as recording, transcription, provider sessions, and local-store coordination are actor-backed.
- Views start lifecycle-bound work with `.task` or explicit model intents. Feature models retain a task only when replacement/cancellation semantics require it.
- Cancellation is normal control flow. A cancelled operation must not be rendered as an error or commit a partial UI success state.
- Unstructured detached tasks, `Task.sleep` as coordination, and main-actor blocking I/O are prohibited in production flows.

### Error, loading, and offline presentation

Feature phases distinguish:

- initial loading from refresh;
- empty content from failed loading;
- offline-but-usable state from unavailable network-only capability;
- validation rejection from transport/provider failure;
- cancelled work from actionable failure;
- locally committed success from queued or proposed enrichment.

User-visible success is shown only after the required application transaction commits. AI or media failure must not roll back an already valid local learner action unless the command contract explicitly defines atomic coupling.

### Minimal composition example

The following shape is normative; exact names may evolve with Document 16 contracts.

```swift
struct AppDependencies: Sendable {
    let knowledge: any KnowledgeUseCases
    let learning: any LearningUseCases
    let clock: any AppClock
}

@MainActor
@Observable
final class AppNavigationModel {
    var section: AppSection = .today
    var path: [AppRoute] = []
}

@main
struct LinguaBrainApp: App {
    private let dependencies: AppDependencies

    init() {
        dependencies = ProductionComposition.makeDependencies()
    }

    var body: some Scene {
        WindowGroup {
            LearnerScene(dependencies: dependencies)
        }
    }
}

struct LearnerScene: View {
    let dependencies: AppDependencies
    @State private var navigation = AppNavigationModel()

    var body: some View {
        RootView(dependencies: dependencies)
            .environment(navigation)
    }
}
```

Production composition and test composition must use the same inward-facing protocols. This example does not select persistence, event/outbox, or secure-storage implementations.

### Testing requirements

- Feature-model tests run under `@MainActor` with fake use cases and deterministic clocks.
- Navigation tests verify typed route transitions, invalid deep links, compact/split adaptation, and independent window paths.
- View tests cover loading, content, empty, offline, validation, error, cancellation, and restoration states.
- Composition tests prove every production dependency is supplied and no test/preview dependency can enter a release build.
- Concurrency tests cover cancellation, late-result suppression, duplicate intent protection, and absence of UI updates after feature teardown.
- XCUITest covers onboarding, first-item creation, review entry/exit, restoration, and keyboard-driven Mac navigation.

## Dependency rules

```text
SwiftUI View
    └──> @MainActor @Observable Feature Model
             └──> Application Use-Case Protocol
                      └──> Domain + Adapter Ports

App Composition Root
    └──> Concrete Adapters + Feature Factories
```

Forbidden paths include:

- View → concrete database/provider/security adapter;
- Feature model → SwiftData/Core Data/SQL row or provider SDK type;
- Environment → mutable global service locator;
- Domain/Application → SwiftUI, Observation, navigation, or scene types;
- one scene/window mutating another scene's navigation model;
- navigation route carrying a full mutable domain object.

## Alternatives considered

### `ObservableObject` and Combine as the primary model

Rejected for new MVP code. Native Observation provides the selected modern SwiftUI integration with more precise dependency tracking. Combine remains permitted only where an Apple or third-party API requires interoperability.

### A Redux-style global store

Rejected. It would duplicate durable learner state, couple unrelated features, complicate independent windows, and risk turning presentation state into the learning engine.

### Third-party state and dependency frameworks

Rejected for the MVP because native Observation, typed navigation, protocols, and composition roots satisfy current needs with less lifecycle and upgrade risk.

### Global singleton services

Rejected because they hide dependencies, weaken isolation and tests, and create unsafe cross-window state.

### Type-erased `NavigationPath` everywhere

Rejected as the default because homogeneous typed route arrays provide stronger compile-time, restoration, and test guarantees. `NavigationPath` is allowed only for a documented heterogeneous flow that cannot be represented clearly with a typed route enum.

### Views calling repositories directly

Rejected because it bypasses transactions, validation, events, error mapping, and the application boundary.

## Consequences

### Positive

- The architecture uses current native SwiftUI/Observation capabilities without external framework lock-in.
- State ownership and window lifetime are explicit.
- Views remain small and application behavior is testable without a simulator.
- iPhone, iPad, and Mac can use native containers while sharing typed routes and feature contracts.
- Persistence, AI, review, media, and security adapters remain replaceable.
- Strict concurrency and cancellation behavior are designed before long-running features begin.

### Negative

- The team must maintain explicit factories and dependency wiring.
- Scene-specific navigation requires deliberate restoration and deep-link tests.
- Developers must resist placing convenience business logic in observable models.
- Some Apple frameworks may still require Combine or delegate bridges inside adapter targets.

### Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| One giant observable app model emerges | Feature-sized models, ownership review, and forbidden catch-all state containers |
| Environment hides required dependencies | Root-only insertion, initializer injection by default, and composition tests |
| Async results overwrite newer state | Intent generation/token checks, cancellation, and late-result tests |
| Navigation paths break after schema changes | Lightweight versioned routes and validation during restoration |
| Mac windows share accidental state | Per-scene navigation models and focused command routing |
| Observation types leak inward | SwiftPM forbidden-import checks from ADR-010 |

## Acceptance evidence

- LB-DEC-058 is `DECIDED` and links to this ADR.
- `LinguaBrainDomain` and `LinguaBrainApplication` remain free of SwiftUI and Observation imports.
- A minimal composition-root fixture can build root views using only deterministic fake use cases.
- Two scene fixtures maintain independent typed navigation paths.
- Feature-model tests demonstrate loading, success, failure, cancellation, and late-result suppression.
- No global service locator, mutable dependency singleton, or third-party state framework is required.

## Follow-up actions

- [ ] Implement the minimal composition root and fake dependency fixture in LB-WI-M1-10.
- [ ] Add SwiftPM forbidden-import checks for SwiftUI and Observation in Domain/Application targets.
- [ ] Define command/query/use-case protocols and typed errors in Document 16.
- [ ] Add typed route, deep-link, restoration, and independent-window test vectors.
- [ ] Record any framework interoperability exception beside its adapter and test it.
- [ ] Revalidate Observation and navigation APIs against stable Xcode 27 before release.

## Official references

- [Apple Developer: Observation](https://developer.apple.com/documentation/observation)
- [Apple Developer: Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)
- [Apple Developer: Environment](https://developer.apple.com/documentation/swiftui/environment)
- [Apple Developer: NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack)
- [Apple Developer: NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [Apple Developer: Understanding the navigation stack](https://developer.apple.com/documentation/swiftui/understanding-the-navigation-stack)
