## Understanding the Current Repository State

### Feature Directory Already Exists
Based on the repository analysis:
- Branch: `002-hermes-content-anki-generation` already exists
- Spec directory: `specs/002-hermes-content-anki-generation/` already exists
- This is a DIFFERENT feature from the requested APKG export

### Required Implementation
The user requested a **NEW** native APKG export feature for approved Hermes cards. This means:
1. Create a NEW spec directory for APKG export feature
2. This is NOT the same as the existing Hermes content generation feature
3. APKG export must be implemented as a separate feature scope (as mentioned in PROJECT_STATUS.md)

### Key Requirements
- SQLite collection generation
- Notes, cards, models, templates, decks, tags support  
- Owned media packaging
- Safe ZIP creation
- Round-trip import verification
- Export operates only on learner-selected approved cards
- Separate from existing Hermes content generation feature

### Implementation Context
The existing `specs/002-hermes-content-anki-generation/` contains:
- User scenarios for Hermes content generation and review
- Export contracts referencing APKG export
- But APKG export functionality is NOT implemented yet

### Next Steps
1. Create a NEW feature directory for APKG export (not reuse existing)
2. Implement all APKG export requirements as a separate feature
3. Ensure round-trip verification works correctly
4. Follow the existing spec template structure
