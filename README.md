# LinguaBrain AI

> An AI-powered adaptive learning platform.

LinguaBrain AI combines a deterministic Learning Engine, a learner Knowledge Graph, spaced repetition, and optional AI content generation to provide personalized language learning. The initial product supports Persian-speaking learners of German; the architecture is intended to support other language pairs and learning domains later.

## Core principle

> AI creates content. The Learning Engine creates learning.

AI may generate examples, explanations, cards, and exercises. The Learning Engine remains responsible for educational decisions: what to teach, when to review it, and which exercise type best serves the learner.

## MVP focus

- German ↔ Persian learning
- Native Swift/SwiftUI on iOS/iPadOS 27 and macOS 27 Golden Gate
- iPhone controlled MVP pilot, with first-class local-only iPad and Mac surfaces
- German–Persian word and phrase learning for general and professional missions
- AI-enriched knowledge items and automatic classification
- Basic knowledge graph and smart decks
- FSRS-based review scheduling
- Adaptive daily plan using available time and energy
- Translation and cloze exercises
- Offline-first local data model with optional AI providers

Image-based Level 1 learning, OCR/document ingestion, speaking evaluation, and additional languages are post-MVP capabilities.

## Repository layout

The normative monorepo paths and dependency boundaries are defined by [ADR-010](decisions/ADR-010-Swift-Package-and-Module-Layout.md), which supersedes ADR-001. Directories are created when their approved milestone begins.

```text
LinguaBrain AI/
├── apps/
│   └── learner/
│       ├── LinguaBrain.xcworkspace/    # Native workspace; user state is ignored
│       ├── LinguaBrain.xcodeproj/      # iOS/iPadOS and macOS app targets
│       ├── App/                        # SwiftUI entry, scenes, navigation, presentation
│       ├── Resources/                  # Localizations, assets, manifests, entitlements
│       ├── Tests/                      # Composition and platform integration tests
│       └── UITests/                    # Critical Apple-platform journeys
├── packages/
│   └── LinguaBrainKit/
│       ├── Package.swift               # One local Swift package, bounded targets
│       ├── Sources/
│       │   ├── LinguaBrainDomain/
│       │   ├── LinguaBrainApplication/
│       │   ├── LinguaBrainPresentation/
│       │   ├── LinguaBrainLanguageDE/
│       │   ├── LinguaBrainLanguageFA/
│       │   ├── LinguaBrainPersistence/
│       │   ├── LinguaBrainReviewFSRS/
│       │   ├── LinguaBrainAI/
│       │   ├── LinguaBrainMedia/
│       │   ├── LinguaBrainPlatformApple/
│       │   └── LinguaBrainTestSupport/
│       └── Tests/
│           ├── LinguaBrainDomainTests/
│           ├── LinguaBrainApplicationTests/
│           ├── LinguaBrainPresentationTests/
│           ├── LinguaBrainLanguageDETests/
│           ├── LinguaBrainLanguageFATests/
│           ├── LinguaBrainPersistenceTests/
│           ├── LinguaBrainReviewFSRSTests/
│           ├── LinguaBrainAITests/
│           ├── LinguaBrainMediaTests/
│           └── LinguaBrainPlatformAppleTests/
├── services/
│   └── sync_api/                       # Post-MVP FastAPI service
├── contracts/                          # Future external API/event schemas
├── experiments/
│   └── vocabulary-mvp/                 # Python/FastAPI/n8n reference experiment
├── tooling/                            # Repository checks and developer commands
├── docs/
├── decisions/
├── diagrams/
├── assets/
├── README.md
├── PROJECT_STATUS.md
├── CHANGELOG.md
├── LICENSE
└── .gitignore
```

## Documentation index

Track current progress and the next verified task in the [Project Status and Delivery Checklist](PROJECT_STATUS.md). Open, decided, and deferred choices are indexed in the [Decision Register](decisions/DECISION_REGISTER.md).

1. [Product Vision](docs/01_Product_Vision.md)
2. [Learning Philosophy](docs/02_Learning_Philosophy.md)
3. [Non-Functional Requirements](docs/03_Non_Functional_Requirements.md)
4. [Core Domain Model](docs/04_Core_Domain_Model.md)
5. [Learning Domain Model](docs/05_Learning_Domain_Model.md)
6. [Knowledge Graph Architecture](docs/06_Knowledge_Graph_Architecture.md)
7. [Adaptive Learning Engine](docs/07_Adaptive_Learning_Engine.md)
8. [AI Orchestration Layer](docs/08_AI_Orchestration_Layer.md)
9. [Language Independence Framework](docs/09_Language_Independence_Framework.md)
10. [MVP Definition and Roadmap](docs/10_MVP_Definition_and_Roadmap.md)
11. [Technical Architecture](docs/11_Technical_Architecture.md)
12. [Database Schema and Persistence](docs/12_Database_Schema_and_Persistence.md)
13. [AI Agent Pipeline](docs/13_AI_Agent_Pipeline.md)
14. [Frontend UX/UI](docs/14_Frontend_UX_UI.md)
15. [Implementation Backlog and Requirements Traceability](docs/15_Implementation_Backlog_and_Traceability.md)

Supporting product artifacts:

- [MVP Card Inventory and Interaction Requirements](docs/supporting/Card_Inventory_and_Interaction_Requirements.md)
- [Anki Core MVP Specification](docs/supporting/Anki_Core_MVP_Specification.md)

## Status

Documents 01–15 remain reviewed drafts. [ADR-009](decisions/ADR-009-Native-Apple-Client-and-Platform-Baseline.md) defines the native Apple OS 27 targets, [ADR-010](decisions/ADR-010-Swift-Package-and-Module-Layout.md) defines the Swift/Xcode/SwiftPM repository boundary, [ADR-011](decisions/ADR-011-SwiftUI-State-Observation-Navigation-and-Dependency-Composition.md) defines presentation composition, and [ADR-012](decisions/ADR-012-Anki-Core-First-and-APKG-Import-Boundary.md) establishes the Anki Core-first delivery gate. The next gate is ADR-003 for native Swift persistence (`LB-DEC-059`, `LB-WI-M0-05`).

## Key resolved contracts

- KnowledgeItems represent semantic learning targets; exercises and media reference them.
- LexicalSense provides stable polysemy and translation identity.
- FSRS schedules learner-specific ReviewUnits per LearningObjective.
- Domain services validate/promote content; ALE makes educational decisions.
- German and Persian Language Packages are built-in, first-party MVP components.
- The Swift domain/application core is independent of SwiftUI and Apple model/storage SDKs; a future non-Apple device must preserve its versioned semantics through a separately approved runtime or interoperability boundary.
- Production code uses a modular monorepo, one local multi-target Swift package, and thin native Apple app hosts; the Python vocabulary spike remains a non-production experiment.
- The controlled pilot targets iPhone on iOS 27. iPadOS 27 and macOS 27 are first-class local-first surfaces. Release 1.0 may optionally synchronize approved learner data through Apple/Google accounts under ADR-014; signed-out learning remains complete.
- Apple Foundation Models, SpeechAnalyzer, and Translation are capability- and locale-gated adapters. German–Persian learning retains validated cloud/local and no-AI fallbacks.
- SwiftUI presentation uses native Observation, `@MainActor` feature models, typed per-scene navigation, initializer injection, and an app-owned composition root; global service locators are prohibited.
