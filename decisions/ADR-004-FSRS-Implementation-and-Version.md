---
title: "ADR-004: FSRS Implementation and Version"
status: accepted
date: 2026-08-09
decision_makers:
  - Product Owner
  - Review Engine Architect
decision_ids:
  - LB-DEC-040
work_items:
  - LB-WI-M0-06
  - LB-WI-M3-03
---

# ADR-004: FSRS Implementation and Version

## Context

The prototype originally mapped Again, Hard, Good, and Easy to fixed intervals.
That was useful for interaction testing but could not model delayed reviews,
different memory strengths, or changing card difficulty. Review state must also
remain reproducible after restart and across future scheduler upgrades.

## Decision

LinguaBrain pins the first review implementation to **FSRS-6.0**, using the
canonical 21 default parameters, desired retention `0.90`, a maximum interval
of 36,500 days, and deterministic scheduling with fuzz disabled.

The semantic reference is the MIT-licensed
[`open-spaced-repetition/swift-fsrs`](https://github.com/open-spaced-repetition/swift-fsrs)
implementation at commit `4fbaf20184d62f82a9f44f343337c61a2c5483e9`.

Each persisted scheduling result records:

- algorithm/version identifier;
- rating and review timestamp;
- elapsed and scheduled days;
- stability and difficulty after the review;
- learning/review/relearning phase and learning-step index;
- resulting due timestamp.

The current application prototype contains a small deterministic FSRS-6 adapter
using the pinned formulas and parameters. It validates both the official first-
review D/S vectors and the official interval-history vector at launch in Debug
builds. The production module will keep the scheduler behind a ReviewScheduler
port and may replace the embedded adapter with the pinned Swift package without
changing persisted domain contracts.

## Learning steps

- New/learning steps: 1 minute and 10 minutes.
- Relearning step: 10 minutes.
- A new-card Hard response uses the midpoint and returns in 6 minutes.
- Long-term intervals are computed from FSRS stability and desired retention;
  they are not hard-coded per button.

## Upgrade policy

- Every review log retains its original algorithm version and result.
- A new FSRS version requires a superseding ADR and new reference vectors.
- Existing immutable review logs are never rewritten silently.
- State migration or rescheduling must be explicit, versioned, reversible where
  feasible, and tested against a frozen fixture before release.
- Parameter optimization is deferred until sufficient learner history exists;
  the canonical defaults are used initially.

## Alternatives considered

### Keep fixed intervals

Rejected because fixed values cannot adapt to memory state or delayed reviews.

### Implement SM-2 first

Rejected because the product requirements already select FSRS and migrating a
new prototype from SM-2 would add work without improving the validation gate.

### Track the latest upstream commit automatically

Rejected because silent scheduler changes would make review history and due
dates non-reproducible.

## Consequences

### Positive

- Review intervals now respond to stability, difficulty, rating, and elapsed
  time.
- The scheduler is fully local and deterministic.
- Stored algorithm metadata supports audit and future migration.
- Official reference vectors detect formula or parameter drift.

### Negative

- Parameter optimization is not yet personalized.
- FSRS version upgrades require deliberate migration work.
- The current prototype adapter must move behind the production package and
  ReviewUnit boundaries before M3 is complete.

## Acceptance evidence

- First-review stability vector: `[0.212, 1.2931, 2.3065, 8.2956]`.
- First-review difficulty vector: approximately
  `[6.4133, 5.11217071, 2.11810397, 1.0]`.
- Reference interval history:
  `[0, 2, 11, 46, 163, 498, 0, 0, 2, 4, 7, 12, 21]`.
- iOS and macOS Debug builds pass with the reference assertion enabled.
- Simulator launch and restart complete without scheduler or schema failure.

## References

- [Open Spaced Repetition: swift-fsrs](https://github.com/open-spaced-repetition/swift-fsrs)
- [FSRS algorithm documentation](https://github.com/open-spaced-repetition/awesome-fsrs/wiki/The-Algorithm)
- [ABC of FSRS](https://github.com/open-spaced-repetition/fsrs4anki/wiki/ABC-of-FSRS)
