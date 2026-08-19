# Feature Specification: Hermes Content and Anki Generation

**Feature Branch**: `002-hermes-content-anki-generation`
**Created**: 2026-08-18
**Status**: Draft
**Input**: Provider-agnostic content generation with Swift-first Hermes orchestration, structured proposals, validation, approval, media, and Anki export.

## User Scenarios & Testing

### User Story 1 - Generate and approve a card collection (Priority: P1)

As a learner, I can request a vocabulary collection for a language pair, level, and topic, inspect the generated cards, edit or reject them, and approve the cards I want to study.

**Why this priority**: This is the smallest useful vertical slice and establishes learner ownership of AI-generated content.

**Independent Test**: Generate a batch with a deterministic fake provider, approve a subset, restart the app, and verify that only approved cards are available for offline study.

**Acceptance Scenarios**:

1. **Given** a configured language pair and level, **When** the learner submits a generation request, **Then** Hermes shows a structured preview with lemma, sense, meaning, example, translation, level, and provenance.
2. **Given** a preview containing valid and invalid proposals, **When** validation completes, **Then** invalid proposals are rejected with actionable reasons and valid proposals remain reviewable.
3. **Given** a preview, **When** the learner edits, rejects, and approves selected cards, **Then** only approved cards are persisted and become study candidates.
4. **Given** approved cards, **When** the app restarts without network access, **Then** the cards remain available for study.

### User Story 2 - Preserve meaning, identity, and media quality (Priority: P1)

As a learner, I can study different senses of the same word independently and receive optional pronunciation media without losing the text card when media generation is unavailable.

**Why this priority**: Sense identity and reliable offline media are required for correct review scheduling and language-learning quality.

**Independent Test**: Generate a polysemous word with two senses, generate audio through a fake media provider, approve one sense with audio and one without it, and verify independent identities and text-only fallback.

**Acceptance Scenarios**:

1. **Given** one lemma with two meanings, **When** the proposal is accepted, **Then** each sense has its own stable identity and review direction.
2. **Given** audio is enabled but unavailable, **When** the learner approves a card, **Then** the text card is retained with an explicit missing-media reason.
3. **Given** generated audio is approved, **When** the learner studies offline, **Then** the cached audio is playable and its provenance is visible in the card record.

### User Story 3 - Export approved content to Anki (Priority: P2)

As a learner, I can export approved Hermes cards to Anki without regenerating content or mixing rejected/imported content unintentionally.

**Why this priority**: Export makes Hermes-generated content reusable while keeping Hermes as the canonical source.

**Independent Test**: Approve a multilingual deck containing RTL and LTR text, export it, inspect the exported fields/tags, and import the result into a clean Anki fixture.

**Acceptance Scenarios**:

1. **Given** approved cards from Hermes, **When** the learner chooses TSV export, **Then** the export contains stable fields for source, target, examples, direction, level, and provenance tags.
2. **Given** approved cards with media, **When** APKG export is supported, **Then** the package contains owned media and renders in a clean Anki fixture.
3. **Given** rejected or imported cards are present, **When** the learner opens export selection, **Then** source groups are clearly separated and only selected cards are exported.

### User Story 4 - Use interchangeable providers safely (Priority: P2)

As a product operator, I can change the text, audio, or image provider without changing Hermes domain semantics or allowing a provider to mutate canonical learning state.

**Why this priority**: Hermes must remain Swift-first and provider-agnostic while supporting cloud, local, and future on-device capabilities.

**Independent Test**: Run the same request against a fake in-process provider and a contract-compatible remote fixture, then compare normalized proposals and verify that provider failure leaves the local learning loop usable.

**Acceptance Scenarios**:

1. **Given** a provider implementing the versioned contract, **When** it returns a proposal, **Then** Hermes validates and approves it through the same application boundary.
2. **Given** a provider fails or is disabled, **When** generation is requested, **Then** Hermes reports the failure, preserves existing data, and offers a manual/no-AI or text-only fallback where applicable.
3. **Given** any provider response, **When** it is processed, **Then** the provider cannot directly modify storage, review state, mastery, or Knowledge Graph facts.

## Edge Cases

- Empty input, unsupported language pair, unsupported CEFR level, or request over the batch limit.
- Invalid JSON, missing required fields, wrong target language, unsafe text, or malformed media.
- Duplicate lemma/sense/direction and the same request retried after timeout.
- One item in a batch fails while other items are valid.
- User cancels during generation or closes the app before approval.
- Provider quota, consent, credential, network, or capability failure.
- RTL/LTR content, Unicode normalization, and HTML/script injection attempts.
- APKG export with unsupported media or template features.

## Requirements

### Functional Requirements

- **FR-001**: System MUST accept structured and natural-language generation requests with source language, target language, level, topic/items, count, directions, and media preferences.
- **FR-002**: System MUST return versioned structured proposals containing lexical senses, examples, translations, grammar data when applicable, media metadata, and provenance.
- **FR-003**: System MUST validate proposals outside the model before approval or persistence.
- **FR-004**: System MUST preserve separate identities for separate lexical senses and review directions.
- **FR-005**: System MUST detect duplicates using language pair, lemma, sense, part of speech, and direction rather than lemma alone.
- **FR-006**: System MUST support per-card edit, regenerate, reject, and approve actions.
- **FR-007**: System MUST persist only approved content into the learner-owned domain model.
- **FR-008**: System MUST support optional audio and image providers with local caching, provenance, and explicit text-only fallback.
- **FR-009**: System MUST keep provider credentials in secure platform storage and exclude credentials and private content from logs and exports.
- **FR-010**: System MUST use a provider-agnostic adapter boundary that supports in-process Swift and external agents in other languages.
- **FR-011**: Agents and providers MUST NOT directly mutate canonical knowledge, review history, mastery, scheduling, or Knowledge Graph facts.
- **FR-012**: System MUST provide TSV export for approved cards and APKG export after the APKG exporter acceptance gate is complete.
- **FR-013**: System MUST preserve approved cards and cached media for offline study after restart.
- **FR-014**: System MUST make generation, validation, approval, retry, and export idempotent or explicitly reconciled.
- **FR-015**: System MUST expose provider, model, prompt/schema, validator, media, consent, and generation-time provenance.

### Key Entities

- **GenerationRequest**: Learner intent and generation settings.
- **CardProposal**: Unapproved structured output for one or more cards.
- **GeneratedCardBundle**: Approved lexical content, senses, sentences, media, directions, and provenance.
- **LexicalSense**: Meaning-specific identity with examples, qualifiers, and independent review identity.
- **MediaAsset**: Audio/image resource with checksum, provider metadata, cache reference, and availability state.
- **GenerationJob**: Durable request/stage state, errors, retries, and idempotency key.
- **ExportManifest**: Selected approved cards, output format, media ownership, and export provenance.

## Success Criteria

### Measurable Outcomes

- **SC-001**: At least 95% of valid cards in a deterministic 20-card request reach preview without manual data repair.
- **SC-002**: A learner can generate, review, approve, and open a 20-card text-only collection within 3 minutes after provider response is available.
- **SC-003**: Repeating an identical request does not create duplicate approved cards.
- **SC-004**: 100% of rejected cards remain absent from study queues and exports.
- **SC-005**: Approved text cards remain reviewable after restart with network access disabled.
- **SC-006**: At least 95% of valid multilingual export fixtures round-trip through the supported TSV/APKG path without field or direction loss.
- **SC-007**: Automated tests demonstrate that no provider can mutate canonical learning or scheduling state directly.

## Assumptions

- The Anki Core offline review gate remains a prerequisite and is not weakened by this feature.
- Hermes remains the canonical store; Anki is an export target.
- Swift is the primary runtime for app and orchestration code, while agent implementation language is unrestricted behind contracts.
- Initial cloud provider behavior follows ADR-013; local and on-device providers are capability-gated.
- APKG export follows a separate round-trip acceptance gate; TSV is the first export target.
- User-private AI content may be accepted for personal study with provenance and validation status preserved.

