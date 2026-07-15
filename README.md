# LinguaBrain AI

> An AI-powered adaptive learning platform.

LinguaBrain AI combines a deterministic Learning Engine, a learner Knowledge Graph, spaced repetition, and optional AI content generation to provide personalized language learning. The initial product supports Persian-speaking learners of German; the architecture is intended to support other language pairs and learning domains later.

## Core principle

> AI creates content. The Learning Engine creates learning.

AI may generate examples, explanations, cards, and exercises. The Learning Engine remains responsible for educational decisions: what to teach, when to review it, and which exercise type best serves the learner.

## MVP focus

- German ↔ Persian learning
- German–Persian word and phrase learning for general and professional missions
- AI-enriched knowledge items and automatic classification
- Basic knowledge graph and smart decks
- FSRS-based review scheduling
- Adaptive daily plan using available time and energy
- Translation and cloze exercises
- Offline-first local data model with optional AI providers

Image-based Level 1 learning, OCR/document ingestion, speaking evaluation, and additional languages are post-MVP capabilities.

## Repository layout

```text
.
├── README.md
├── PROJECT_STATUS.md # Live completed/remaining-work checklist
├── CHANGELOG.md
├── LICENSE
├── docs/          # Product and technical specifications
├── diagrams/      # Source diagram files and exports
├── decisions/     # Architecture Decision Records (ADRs)
└── assets/        # Documentation assets
```

## Documentation index

Track current progress and the next verified task in the [Project Status and Delivery Checklist](PROJECT_STATUS.md).

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

## Status

All 14 specifications are complete as reviewed drafts. The repository is ready for Architecture Decision Records (ADRs) and implementation backlog creation; unresolved decisions are explicitly listed in each document.

## Key resolved contracts

- KnowledgeItems represent semantic learning targets; exercises and media reference them.
- LexicalSense provides stable polysemy and translation identity.
- FSRS schedules learner-specific ReviewUnits per LearningObjective.
- Domain services validate/promote content; ALE makes educational decisions.
- German and Persian Language Packages are built-in, first-party MVP components.
- The shared core is client-surface neutral and can later support a focused dedicated device without forking learner data or learning logic.
