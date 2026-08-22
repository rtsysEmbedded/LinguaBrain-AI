# Security Review: Hermes Content and Anki Generation

**Feature**: T002-hermes-content-anki-generation  
**Date**: 2026-08-22  
**Reviewer**: Architecture Team

## Credentials Security

### Verified
- API keys stored in Keychain via `SecureCredentialStore` protocol (`LinguaBrainApplication.swift:70-74`)
- Credential scopes are endpoint-scoped (`apiKeyScope` in `ProviderConfiguration`)
- `CredentialLoader` protocol provides abstraction for loading credentials
- No credentials logged in test code (`LinguaBrainTestSupport.swift` uses `NoOpCredentialLoader`, `FailingCredentialLoader`)

### Requirements
- All API keys must be loaded from Keychain or secure platform storage
- Credentials must never appear in logs, test fixtures, or debug output

## Data Privacy

### Verified
- Provider credentials excluded from logs and exports (`FR-009`)
- MediaAsset includes `consentContext` field for audit trail (`LinguaBrainDomain.swift:244`)
- Generated content stored as learner-owned domain model

### Gaps
- T037 security review document was missing - now documented

## Network Security

### Verified
- TLS required for all provider communications
- Timeout configuration prevents hanging connections (`FR-008`)
- Health checks validate endpoint availability before use

### Requirements
- All provider endpoints must use HTTPS
- Request timeouts must be configurable (default 30s)

## Input Validation

### Verified
- `StrictProposalValidator` rejects unsafe text (`LinguaBrainAI.swift:132-176`)
- Script/HTML injection detection in `unsafe(_:)` method
- Schema version validation prevents malformed proposals

### Tests
- `testValidatorRejectsUnsafeTextAndIncompleteSenses` validates input sanitization

## Access Control

### Verified
- Consent gate protocol (`ConsentGate`) for cloud providers (`LinguaBrainApplication.swift:76-79`)
- Provider can be disabled via `ProviderMode.off`
- Text-only fallback available when provider unavailable

## Media Asset Security

### Verified
- MediaAsset includes checksum, cacheReference, availability, fallbackReason
- Media providers separate from text providers (FR-008)

### Gaps
- T038: Full media cache lifecycle implementation missing
- No media export in APKG without explicit approval (T043 pending)

## Test Coverage

### Verified Tests
- `testProviderCannotDirectlyMutateStorage` (Constitution III compliance)
- `testProviderCannotModifyApprovedBundles` (Constitution III compliance)
- `testNoAPIKeyThrowsMissingKeyError`
- `testProviderHealthStatusReturnsStatus`
- `testProviderIsAvailableReturnsCorrectly`

## Recommendations

1. **Implement media cache lifecycle** (T038): Verify checksums on retrieval, implement cache eviction
2. **Add APKG media export** (T043): Verify media provenance in exports
3. **Add accessibility tests** (T035): UITests directory empty
4. **Complete audio integration** (T040): Remove hardcoded `audioEnabled: false`

## Sign-off

Security review documented. Remaining gaps tracked in Phase 8 convergence tasks.