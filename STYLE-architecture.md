# STYLE-architecture.md

## Purpose

This document governs architectural ownership, invariant repair, deep-module
design, authorization boundaries for disruptive change, and the difference
between real fixes and anti-fixes.

Use this document whenever work touches more than one module, repairs a shared
contract, changes layout or rendering ownership, restructures a subsystem,
introduces or removes an abstraction boundary, or is likely to be framed as
"just a local patch" despite cross-cutting symptoms.

## Mandatory reading and pass-forward

All contributors, including agents, must read this document line by line
before planning, implementing, reviewing, or delegating architecture-touching
work.

If you generate downstream instructions or artifacts — PRDs, tranche files,
tasking files, review requests, audit scopes, or delegated task descriptions —
you must pass the relevant mandates forward explicitly.

Passing this document forward means:

- naming it as required reading downstream
- restating the applicable ownership and invariant rules downstream
- restating any authorization boundaries downstream
- restating the required verification gates downstream

It is not acceptable to assume that a later contributor or agent will infer
these constraints from context.

## Core rules

### Fix the owner, not the symptom site

If multiple symptoms depend on the same underlying contract, owner, or
invariant, repair that owner first.

Do not solve a cross-cutting problem by stacking local compensations at the
symptom sites.

If a proposed change requires the same defensive logic to be repeated in
several sibling layers, stop and locate the real owner.

### One invariant, one owner

Each important invariant should have a clearly identifiable owner.

Consumers may rely on an invariant, but they should not each be responsible for
reconstructing or re-enforcing it independently.

If an invariant seems to be partially enforced in many places, that is a design
smell and should trigger architectural review.

### Prefer foundational tranches when ownership is wrong

If several user-visible defects or requested features depend on one unclear or
misowned responsibility, create a foundational tranche first.

Do not force thin user-facing slices when that would lock the wrong
architecture into place.

A foundational tranche must still be:

- crisply scoped
- explicitly justified
- independently verifiable

### Deep modules over shallow coordination

Prefer modules that own real complexity behind a small, stable interface.

Avoid shallow modules that merely pass state around while exposing the true
complexity to all callers.

The more cross-cutting the behavior, the stronger the case for a deep owner.

### Anti-fixes are prohibited

Do not clamp, mask, cosmetically suppress, or reroute a bad state merely to
make the output look plausible or to make a weak test pass.

A local masking change is acceptable only if:

- the masking policy is itself the correct owner-level behavior
- that ownership is explicitly identified
- the policy is documented and verified as such

Otherwise, the change is an anti-fix and must not be presented as resolution.

### User authorization bounds disruptive change

Deep redesign, large refactors, internal replacement, and clean-room rebuild
work are permitted only within an explicit user-approved authorization
boundary.

When that boundary is in place, contributors may choose the better design
rather than preserving accidental structure.

When that boundary is not in place, do not silently smuggle in major
architectural change.

### External contracts require explicit migration

Internal redesign is one question; external breakage is another.

If a change may affect outside clients, public APIs, file formats, serialized
artifacts, or documented workflows, you must:

- identify the exposed contract explicitly
- obtain explicit user approval for the breaking change
- define migration, compatibility, and documentation obligations explicitly

No contributor or agent may assume that internal improvement automatically
justifies external breakage.

### Green-state discipline is mandatory

Architectural work does not excuse leaving the repository in an indeterminate
state.

Every approved tranche must begin and end in the required green state for its
scope. Required gates may include tests, docs builds, example renders,
integration checks, migration verification, or other project-specific
artifacts.

If a tranche cannot do this safely, it is too large or incorrectly framed and
must be split or escalated.

## Required planning artifacts

Any PRD, tranche document, or tasking document for architecture-touching work
must explicitly include:

- the current-state problem, not just the desired feature
- the target-state ownership model
- the shared contracts and invariants involved
- the owner that must be repaired or established
- any areas that must not be solved by local patches
- the user authorization boundary
- the verification gates required before the work is considered complete

## Review and audit standard

Architecture reviews and audits must ask:

- did the change repair the owning layer?
- did it preserve or improve ownership clarity?
- did it create or remove duplicated invariant logic?
- did it introduce any anti-fixes?
- did it respect the authorization boundary and migration obligations?

If the answer to any of these is unclear, the work is not yet adequately
specified or reviewed.
