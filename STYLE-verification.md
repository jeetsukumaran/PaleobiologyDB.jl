# STYLE-verification.md

## Purpose

This document governs how correctness is verified.

Its purpose is to prevent green builds that still permit visibly wrong,
contract-breaking, or misleading behavior.

Use this document whenever work affects rendering, layout, public APIs,
display behavior, documentation examples, migrations, architecture, or any bug
whose real failure mode can be observed more directly than the current tests do.

## Mandatory reading and pass-forward

All contributors, including agents, must read this document line by line
before planning, implementing, reviewing, or delegating verification-sensitive
work.

If you generate downstream instructions or artifacts, you must pass the
verification obligations forward explicitly. Downstream work must be told:

- what behavior is actually being verified
- which artifacts count as verification artifacts
- which gates must be green at tranche end
- which weak proxies are not sufficient

Linking a parent document is not enough. The verification obligations must be
restated in the downstream document or task description.

## Core rules

### Verify the real contract boundary

Tests and other checks must verify externally meaningful behavior, not merely
internal implementation-adjacent proxies.

If the defect is visual, readable, or compositional, a test that only asserts
that geometry exists is often insufficient.

If the defect is a public API or display contract, a test that only exercises
internal helpers is often insufficient.

### Reproduce the reported failure mode directly

A good regression test fails for the actual historical bug.

Do not replace a direct regression with a looser proxy unless the direct check
is impossible and the limitation is documented explicitly.

When the failure mode is visible in an example, screenshot, render, or docs
page, the verification plan should usually include that artifact.

### Visual work requires visual verification artifacts

For rendering, layout, annotation, plotting, or compositing changes, required
verification artifacts may include:

- rendered example outputs
- screenshots
- pixel or image-diff checks
- measured bounding boxes
- contract-level assertions about text placement or visibility

Smoke tests and geometry-only checks may be supplemental, but they are not
sufficient on their own when the real defect is visual.

### Public API work requires contract-level verification

If a change touches public API behavior, display semantics, exported names,
keyword meaning, or docs-described usage, verification should include:

- direct API tests
- example usage tests or rendered examples where relevant
- documentation updates and successful docs builds

### Multi-surface semantics require multi-surface verification

If a public semantic is available through more than one supported entry
surface, verification must include at least one regression for each supported
surface.

Testing only one path is insufficient when the semantic can be supplied
through constructor attributes, mutating calls, non-mutating convenience
wrappers, or other public entry points with different ownership boundaries.

When a public example is the clearest artifact for one of those surfaces, keep
at least one integration or render check aligned with that example shape.

### Architecture work requires owner-level verification

When a change repairs or establishes an owner, contract, or invariant,
verification must show that:

- the owner now enforces the rule
- sibling layers no longer need to re-enforce it defensively
- the historical bug is actually prevented
- existing unaffected behavior still works

### Weak proxies are not acceptable as the only proof

The following are often insufficient on their own:

- "the test suite passes"
- "geometry exists"
- "the object stays within the bounding box"
- "the function returns something"
- "the docs build"

These may all be part of verification, but they do not by themselves prove that
the original contract is correct.

### Every bug fix should add or strengthen verification

A bug fix that changes behavior but does not leave behind stronger verification
is suspect.

At minimum, one of the following should improve:

- direct regression coverage
- example verification
- docs verification
- integration verification
- auditability of the contract being enforced

### Green-state requirements must be explicit

Every PRD, tranche document, and tasking document must say exactly which
verification artifacts are required for the work to be considered complete.

Examples:

- full test suite
- specific integration tests
- docs build
- example render checks
- migration verification
- benchmark thresholds

If this is not stated explicitly, the verification plan is incomplete.

## Review and audit standard

Reviews and audits must ask:

- does this verification fail for the old bug?
- does it verify the real external behavior?
- does it rely on a weak proxy where a stronger artifact is available?
- does the green state for this work actually cover the reported contract?

If not, the verification is not yet good enough.
