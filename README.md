# LinguaBrain AI

> An AI-powered adaptive learning platform.

LinguaBrain AI combines a deterministic Learning Engine, a learner Knowledge Graph, spaced repetition, and optional AI content generation to provide personalized language learning. The initial product supports Persian-speaking learners of German; the architecture is intended to support other language pairs and learning domains later.

## Core principle

> AI creates content. The Learning Engine creates learning.

AI may generate examples, explanations, cards, and exercises. The Learning Engine remains responsible for educational decisions: what to teach, when to review it, and which exercise type best serves the learner.

## MVP focus

- German ↔ Persian learning
- Android-phone controlled MVP pilot
- German–Persian word and phrase learning for general and professional missions
- AI-enriched knowledge items and automatic classification
- Basic knowledge graph and smart decks
- FSRS-based review scheduling
- Adaptive daily plan using available time and energy
- Translation and cloze exercises
- Offline-first local data model with optional AI providers

Image-based Level 1 learning, OCR/document ingestion, speaking evaluation, and additional languages are post-MVP capabilities.

## Repository layout

The normative monorepo paths and dependency boundaries are defined by [ADR-001](decisions/ADR-001-Repository-Package-and-Module-Layout.md). Directories are created when their approved milestone begins.

```text
LinguaBrain AI/
├── apps/
│   ├── mobile/                         # M1 Flutter reference client
│   └── device/                         # Future; created only after approval
├── packages/
│   ├── linguabrain_domain/             # Pure Dart domain model and contracts
│   ├── linguabrain_application/        # Pure Dart use cases, ports, transactions
│   ├── linguabrain_language_de/        # First-party German Language Package
│   ├── linguabrain_language_fa/        # First-party Persian Language Package
│   ├── linguabrain_persistence_sqlite/ # SQLite repositories, migrations, FTS, outbox
│   ├── linguabrain_ai/                 # AI orchestration and provider adapters
│   ├── linguabrain_review_fsrs/        # FSRS scheduler adapter and vectors
│   ├── linguabrain_media/              # Media cache and playback adapters
│   ├── linguabrain_platform_flutter/   # Secure storage, lifecycle, capabilities
│   └── linguabrain_test_support/       # Synthetic fixtures, fakes, contract suites
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

## Status

Documents 01–15 remain reviewed drafts. [ADR-001](decisions/ADR-001-Repository-Package-and-Module-Layout.md) defines the repository boundary, and [ADR-008](decisions/ADR-008-Initial-Pilot-and-Golden-Layout-Platform.md) defines an Android-phone-only pilot and Android golden-layout baseline. The next gate is ADR-002 for Flutter state management and dependency injection (`LB-DEC-055`, `LB-WI-M0-04`).

## Key resolved contracts

- KnowledgeItems represent semantic learning targets; exercises and media reference them.
- LexicalSense provides stable polysemy and translation identity.
- FSRS schedules learner-specific ReviewUnits per LearningObjective.
- Domain services validate/promote content; ALE makes educational decisions.
- German and Persian Language Packages are built-in, first-party MVP components.
- The shared core is client-surface neutral and can later support a focused dedicated device without forking learner data or learning logic.
- Production code uses a modular monorepo with pure Dart domain/application packages and thin client shells; the Python vocabulary spike remains a non-production experiment.
- The controlled MVP pilot targets Android phones only; iOS requires a separate re-entry decision while shared code remains portable.
