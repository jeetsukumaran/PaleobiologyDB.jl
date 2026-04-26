# STYLE-makie.md

## Purpose

This document governs how LineagesMakie.jl integrates with Makie and Makie-
family packages such as CairoMakie and GraphMakie.

Use this document whenever work touches plotting entrypoints, custom blocks,
recipes, scenes, layout ownership, rendering policy, annotation placement,
display behavior, or example outputs driven by Makie contracts.

## Mandatory reading and pass-forward

All contributors, including agents, must read this document line by line
before planning, implementing, reviewing, or delegating Makie-sensitive work.

If you generate downstream instructions or artifacts, you must pass forward:

- the exact Makie-family source files or docs that constrain the work
- the Makie contract conclusions drawn from them
- the verification artifacts needed to prove compliance

Do not reduce this to "follow Makie conventions". Name the specific upstream
contract whenever feasible.

## Core rules

### Makie contracts are host-framework contracts

Makie semantics are not optional local style.

When LineagesMakie wraps or extends Makie behavior, it must preserve Makie's
host-framework contract unless an explicit, documented divergence is approved.

### Non-mutating and mutating plotting entrypoints must follow Makie semantics

If the local API offers both non-bang and bang plotting forms, they must follow
Makie's mutating versus non-mutating contract clearly and predictably.

Do not blur the distinction through convenience wrappers that return surprising
objects or mutate unexpectedly.

### Decorations belong to the owning layout layer

If an element is semantically a panel or axis decoration rather than data
content, its layout and placement must be owned by the appropriate Makie block
or block-adjacent owner, not improvised independently by sibling layers.

Do not let multiple rendering layers invent their own competing decoration
offsets when they are all participating in one panel-level contract.

### Measure text before reserving annotation space

Text-driven layout must be based on measured or contractually derived text
extents whenever available.

Do not rely on magic offsets or uncoordinated local spacing when annotation
readability or collision avoidance matters.

### Scene ownership and data-space ownership must not be confused

Do not place decoration-like artifacts in data space merely because they are
drawn with plotting primitives.

When the semantics are panel-owned rather than data-owned, the layout and scene
ownership should reflect that distinction.

### Compositing policy must be explicit

If the visual result depends on draw order, fill policy, stroke policy, or
scene layering, that policy must be intentional and documented.

Do not rely on accidental rendering order to create or hide an invariant.

## Required planning artifacts

Any PRD, tranche document, or tasking document for Makie-sensitive work must
include:

- the exact Makie-family primary sources read
- the specific contract being preserved or repaired
- the owner of annotation, layout, or rendering policy
- the verification artifacts needed to demonstrate compliance

## Required verification

Makie-sensitive work typically requires more than unit tests.

Depending on the change, required verification may include:

- rendered example outputs
- screenshot or pixel-level checks
- docs builds
- integration tests for public plotting entrypoints
- direct checks of display-ready return types or block ownership

Weak geometry-only checks are not sufficient when the real defect is visual,
readability-related, or compositional.

## Review and audit standard

Reviews and audits of Makie-sensitive work must ask:

- which Makie-family primary sources were actually read?
- does the implementation match Makie's contract?
- is decoration ownership correctly centralized?
- are annotations measured and coordinated at the right layer?
- is the visual result explained by intentional policy rather than accident?
