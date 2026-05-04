---
date-created: 2026-04-30T18:52:39
---

# PRD: Re-architect TaxonomyMakie and PhyloPicMakie tree glyph overlays

## User statement

> "When adding PhyloPic images to leaves of the plot, placement and sizing is completely out. There have been multiple hacks and half-fixes by various agents."
>
> "The problem may be a fundamental architectural issue, and implementation mechanism choice or approach or design issue, or an implementation problem."
>
> "Currently, the glyphs are super super super super tiny and squished in the corner, as can be seen when running `examples/src/taxonomytree.jl`. They are present but miniscule."
>
> "There previously were major issues with placement, e.g. glyphs overlaid on label or too offset. I cannot assess these now, not sure if these are still an issue or they have been fixed, or if the fixes to these were what is causing the current issues."
>
> "One issue previously was the hard-coded assumption that the axes were anisotropic, and then various attempts at mapping from pixel space to data space. A design decision that avoids this by using scatter was suggested and if this robust, idiomatic, and works well, that might be better if that's not already implemented."
>
> "The full Makie project is available in this workspace through the `codebases-and-documentation` folder: `Makie.jl`. This is a key context document, with mandated reading/review/transmission of mandate downstream."
>
> "The live `PhyloPicMakie.jl` project is also available in this workspace. This is meant to provide general heavy PhyloPic database support and help with the Makie infrastructure and general rendering as possible without specialized knowledge of the client, while the Paleobiology PhyloPic layer does any adaptation and bridging. A large part of this is the taxonomy name bridging. It can do whatever it needs to help the rendering of PhyloPic glyphs, but any general purpose functionality for the latter should ideally live in PhyloPic so the benefits can be shared by other very different packages."
>
> "I am giving you full architectural-scale ground-up refactoring of both packages if required."
>
> "I'm open to discussing API changes if recommended or needed, but these need to be explicitly flagged and get my approval."
>
> "Public API break is absolutely possible and even wanted if needed for best practices. Migration/compatibility/docs probably not needed, none of this stuff is out yet and nobody is using it. All that matters is the finalized documentation accurately and comprehensively reflects the new surface cleanly and correctly."
>
> "Yes. Clean up the vocab and ensure STYLE* compliance."

## Problem statement

The user-facing problem is that `taxonomytreeplot(...; show_phylopic = true)` does not produce usable PhyloPic leaf overlays. In the reproduced `examples/src/taxonomytree.jl` render, the tree draws, but the PhyloPic glyphs are effectively invisible because they are tiny and visually collapsed into the far right margin. Historical placement problems also suggest that even when glyphs become visible, their relationship to labels and leaf anchors is unstable.

The architectural problem is that the tree overlay path currently has duplicated rendering ownership. `TaxonomyMakie` contains both:

- a composable tree-aware overlay path that delegates to `PhyloPic.augment_phylopic!`, and
- a separate private `show_phylopic = true` recipe path that re-implements image loading, glyph sizing, label measurement, and pixel/data placement logic locally.

This duplicate ownership has produced shallow, overlapping mechanisms, inconsistent public surface semantics, vocabulary drift, and verification gaps. The visible bug is a symptom of that deeper design problem.

## Target outcome

When this effort is complete:

- tree plots with PhyloPic glyphs render at correct visible size, correct aspect ratio, and correct placement relative to the intended leaf-label or leaf-position anchor,
- the one-step convenience path `taxonomytreeplot(...; show_phylopic = true, ...)` remains available as an idiomatic happy-path wrapper,
- the one-step wrapper is thin and built on the same lower-level tree-aware overlay path exposed explicitly to advanced users,
- `PhyloPicMakie` exposes a flexible, user-friendly generic overlay surface for glyph placement relative to labels, markers, ticks, legends, and arbitrary explicit anchors, so that non-tree clients can reuse the same machinery,
- `PhyloPicMakie.jl` ships standalone minimal working example scripts in `examples/src` with an isolated `examples` environment, so that its public overlay interface can be demonstrated and exercised independently of `PaleobiologyDB.jl`,
- `TaxonomyMakie` owns only tree-specific concerns such as leaf discovery, anchor derivation, label-relative layout policy, and convenience API,
- `PhyloPicMakie` owns general glyph rendering behavior, shared Makie-space projection/rendering machinery, image loading/caching, and any renderer-general geometry helpers that are truly reusable,
- all public naming and documentation are brought back into compliance with the active controlled vocabulary and `STYLE*` governance,
- tests, docs, and at least one rendered example artifact verify the real visual contract rather than only smoke-test execution.

## User stories

1. As a user making a taxonomy tree plot, I want `taxonomytreeplot(...; show_phylopic = true)` to produce visible, correctly sized silhouettes, so that the default happy path is trustworthy.
2. As a user making a taxonomy tree plot, I want glyphs to maintain correct aspect ratio under axis anisotropy, figure resizing, and auto-limit changes, so that rendered silhouettes do not stretch or collapse.
3. As a user reading leaf labels, I want glyphs to respect the intended inline or aligned placement policy, so that text and silhouettes do not overlap or drift unpredictably.
4. As a user who wants more control, I want an explicit lower-level tree-aware overlay API, so that I can plot the tree and then add glyphs in a composable second step.
5. As a user who does not want glyphs, I want ordinary `taxonomytreeplot` behavior to remain clean and unaffected, so that the overlay architecture does not complicate the no-glyph path.
6. As a user working with live PBDB and PhyloPic queries, I want caching-friendly verification and usage patterns, so that render workflows remain practical despite slow upstream calls.
7. As a user exploring many taxa, I want missing-image behavior to be explicit and predictable, so that I can choose skip, placeholder, or hard error behavior knowingly.
8. As a user relying on documentation, I want the final docs to describe the actual supported surface exactly, so that examples and API reference remain trustworthy.
9. As a maintainer, I want one owner for general glyph rendering behavior, so that fixes to sizing and placement do not need to be duplicated across packages.
10. As a maintainer, I want one owner for tree-specific anchor semantics, so that changes to leaf positioning and label policy are centralized in the tree layer.
11. As a maintainer, I want Makie-space conversions to use Makie-supported projection mechanisms where appropriate, so that the implementation follows host-framework contracts instead of unstable local approximations.
12. As a maintainer, I want vocabulary cleanup from `tip*` to `leaf*` and other controlled-term compliance, so that the public surface stops drifting from the project’s ratified terminology.
13. As a maintainer, I want API changes to be explicitly surfaced for approval before final adoption, so that architectural cleanup does not silently rewrite the public contract.
14. As a maintainer, I want foundational architectural work to remain trancheable and green throughout, so that deep refactoring does not leave either package in a half-working state.
15. As a tester, I want direct verification of glyph size, aspect, and anchor placement, so that the historical failure mode is caught by automated checks.
16. As a tester, I want at least one rendered tree+PhyloPic artifact checked as part of green state, so that purely geometric or no-error tests do not mask a visual regression.
17. As a downstream package author using `PhyloPicMakie`, I want any general glyph-rendering improvements to live in `PhyloPicMakie`, so that other clients can benefit from the same fixes.
18. As a downstream package author using `PhyloPicMakie`, I want a generic anchor-driven overlay API that works for labels, markers, ticks, legends, and explicit coordinates, so that I do not need tree-specific internals to place silhouettes cleanly.
19. As a downstream package author evaluating `PhyloPicMakie`, I want standalone runnable examples in `examples/src` with an isolated `examples` environment, so that I can learn and verify the public overlay interface without depending on `PaleobiologyDB.jl`.
20. As a downstream tree-plot maintainer, I want tree-specific ergonomic wrappers to remain available, so that architectural cleanup does not force an awkward user experience.
21. As a reviewer, I want the redesign to distinguish owner-level fixes from local symptom patches, so that another anti-fix is not mistaken for resolution.
22. As a future maintainer, I want the final module boundaries to make it obvious where taxonomy resolution ends and generic Makie glyph rendering begins, so that new features extend the right layer.

## Authorized disruption boundary

- internal redesign allowed:
  - Full ground-up refactoring across both `PaleobiologyDB.jl` `TaxonomyMakie` code and `PhyloPicMakie.jl` if required.
  - Deletion, replacement, consolidation, or relocation of duplicated rendering machinery.
  - Controlled-vocabulary cleanup and public-surface renaming where justified.
- internal redesign forbidden:
  - Silent anti-fixes that preserve the appearance of functionality while leaving duplicated or misowned rendering logic in place.
  - Drift away from active governance or upstream host-framework contracts.
- external breaking changes allowed:
  - Yes, in principle, because this surface is not yet externally adopted and the user explicitly allows best-practice breaks.
  - Every proposed public API break or rename must still be explicitly flagged and ratified by the user before implementation is finalized.
- required migration or compatibility obligations:
  - Compatibility shims, deprecation aliases, and migration notes are not required by default.
  - Final documentation must accurately and comprehensively reflect the approved final public surface.
  - If external-use assumptions change later, migration/compatibility obligations must be revisited with the user.
- non-negotiable protections:
  - Every tranche must begin and end in a green state.
  - Visual correctness, not mere execution success, is the acceptance boundary.
  - User quality of life must be preserved or improved even if the internals are heavily redesigned.
  - Controlled vocabulary and `STYLE*` compliance must be restored rather than deferred indefinitely.

## Current-state architecture

- Existing owners:
  - `ext/TaxonomyMakie/_layout.jl` owns tree layout and leaf coordinate extraction.
  - `ext/TaxonomyMakie/_recipe.jl` owns plot recipe construction and the `show_phylopic = true` integrated path.
  - `ext/TaxonomyMakie/_augment.jl` owns a separate explicit tree-aware overlay API that delegates to `PhyloPic.augment_phylopic!`.
  - `ext/TaxonomyMakie/_phylopic.jl` owns a private render path for `show_phylopic = true`.
  - `ext/TaxonomyMakie/PhyloPic/src/_render.jl` and the external `PhyloPicMakie.jl` project own a generic glyph-rendering stack.
- Existing failure modes:
  - The integrated `show_phylopic = true` path renders glyphs at approximately `2 × 2` pixels in the reproduced live example.
  - Historical placement problems include label overlap and excessive rightward offset.
  - The integrated path computes sizing once, before stable viewport/data-limit state, and does not correct reactively afterwards.
  - Verification largely checks “does not error” rather than the visible rendering contract.
- Existing coupling, duplication, or design debt:
  - `show_phylopic = true` bypasses the explicit `augment_tip_phylopic!` path and duplicates rendering ownership in the recipe layer.
  - Tree-specific overlay code duplicates image loading, glyph sizing, and label-relative placement logic that overlaps with general `PhyloPicMakie` responsibilities.
  - The current design does not cleanly expose a general-purpose anchored-overlay surface in `PhyloPicMakie`, which encourages tree clients to grow their own partial rendering logic.
  - The public surface is inconsistent with the controlled vocabulary: `tip_positions`, `augment_tip_phylopic!`, `showtips`, and `tip_*` names remain despite `tip` being proscribed.
  - Tests in `test/taxonomytree_makie.jl` cover offline layout and smoke behavior, but do not verify actual size, aspect, or placement correctness.
  - Documentation describes tree-specific PhyloPic options in data-unit terms tied to the current implementation, which may not survive a better architectural split unchanged.
  - `PhyloPicMakie.jl` does not currently ship an isolated `examples` environment or standalone public-interface show-off scripts, which makes it harder to validate and communicate the generic overlay surface independently of tree clients.

## Target architecture

- Major modules and responsibilities:
  - A `TaxonomyMakie` tree-plot module owns taxonomy-tree layout, leaf extraction, label policy, plot orchestration, and user-facing convenience wrappers.
  - A tree-aware overlay planning module in `TaxonomyMakie` owns derivation of final glyph anchors from leaf positions and chosen label-relative policy.
  - `PhyloPicMakie` owns a generic anchor-driven overlay API for label-relative, marker-relative, tick-relative, legend-relative, and explicit-anchor glyph placement.
  - `PhyloPicMakie` owns all general-purpose Makie glyph rendering and image geometry behavior that is not tree-specific.
  - The Paleobiology/PhyloPic bridge owns PBDB taxon-to-PhyloPic node/image resolution and any PBDB-specific lookup strategy, but not generic rendering policy.
- Ownership boundaries:
  - Tree-specific questions such as “which leaves receive glyphs,” “what is a label-relative anchor,” and “how should aligned versus inline tree columns behave” belong to `TaxonomyMakie`.
  - General glyph-rendering questions such as image aspect preservation, renderer-safe size computation, rotation, mirroring, missing-image handling, Makie-space conversion, and reusable anchored-placement mechanics belong to `PhyloPicMakie`.
  - Any helper that is generic enough to benefit multiple clients should live in `PhyloPicMakie`, not remain hidden in `TaxonomyMakie`.
- Shared contracts and invariants:
  - Glyphs must be visibly sized and aspect-correct on anisotropic axes and after viewport/auto-limit changes.
  - One-step and two-step tree APIs must route through the same underlying overlay machinery rather than diverging.
  - Tree overlays should use the same generic `PhyloPicMakie` anchor/overlay substrate that non-tree clients use, rather than a tree-only rendering fork.
  - `PhyloPicMakie.jl` standalone examples must run in an isolated `examples` environment and demonstrate the public interface without any dependency on `PaleobiologyDB.jl`.
  - Tree-specific wrappers must remain ergonomic, but must not become owners of general rendering logic.
  - Controlled vocabulary must be consistent across code, tests, docs, and public API.
- Target deep modules and simplified interfaces:
  - The integrated `show_phylopic = true` path becomes a thin wrapper over the same lower-level tree-aware overlay pipeline exposed explicitly to advanced callers.
  - `PhyloPicMakie` provides a sufficiently expressive anchor/overlay interface for pre-resolved images and projected or data-space anchors, so tree clients, tick/legend helpers, and arbitrary plot overlays do not reimplement Makie mechanics.
  - Tree overlay planning becomes a deep, testable module that translates leaf geometry plus label policy into anchor instructions without owning pixel/data rendering internals.

## Implementation decisions

- The bug is treated as an owner-level architecture problem, not as a local constant-tuning bug.
- The current `show_phylopic = true` recipe path is not the long-term owner of glyph-rendering behavior.
- The final design should support both:
  - a thin one-step happy-path convenience API, and
  - a composable two-step flow where callers plot first and overlay second.
- The final design must prefer Makie-supported projection and coordinate-space tools over ad hoc viewport/data-limit reconstruction wherever feasible.
- Public naming cleanup is in scope and desired, especially where current names violate controlled vocabulary.
- Current public `tip*` surface should be cleanly refactored to `leaf*` equivalents with no deprecation layer, unless the user later explicitly requests transitional aliases.
- Because external adoption is effectively zero, API cleanup may proceed more aggressively than it would in a mature released surface, but only with explicit user sign-off on the final break set.
- No downstream implementation tranche may assume that compatibility wrappers are required by default; that question is already user-scoped as “not required unless later requested.”
- Live verification should use `set_autocaching!(true)` for PBDB and PhyloPic-heavy paths to keep green-state checks tractable.

## Module design

- **Name**: `TaxonomyMakie` tree recipe and orchestration layer
  - **Responsibility**: Own tree plotting, user-facing plot entry points, and wrapper orchestration between tree geometry and optional leaf-glyph overlays.
  - **Interface**: `taxonomytreeplot`, `taxonomytreeplot!`, rank-axis helpers, and approved PhyloPic convenience keywords. Failure modes include invalid tree input, unsupported keyword combinations, and explicit missing-image policies routed from the overlay layer.
  - **Tested**: yes

- **Name**: `TaxonomyMakie` leaf overlay planning layer
  - **Responsibility**: Convert leaf positions, label policy, and alignment mode into overlay anchor instructions without rendering glyphs itself.
  - **Interface**: Leaf extraction and anchor-planning helpers; explicit tree-aware overlay wrapper(s) over the general rendering engine. Failure modes include inconsistent layout metadata or unsupported tree-specific anchor policies.
  - **Tested**: yes

- **Name**: `PhyloPicMakie` general glyph rendering core
  - **Responsibility**: Render pre-resolved image matrices in Makie with correct aspect, placement, rotation, missing-image policy, reactive space handling, and reusable anchored-placement support.
  - **Interface**: General `augment_phylopic!` and related low-level calls for explicit coordinates, plus a generic anchor/overlay surface for label-, marker-, tick-, legend-, and projected-anchor workflows. Failure modes include invalid rendering options, mismatched vector lengths, unsupported rotation/aspect values, unsupported anchor specifications, and missing images under `:error`.
  - **Tested**: yes

- **Name**: `PhyloPicMakie` generic anchor and placement layer
  - **Responsibility**: Normalize high-level placement requests such as “offset from this rendered label” or “attach to this marker/tick/legend anchor” into stable render instructions for the general glyph core.
  - **Interface**: User-facing or helper-facing anchor-specification types and placement adapters that can serve trees and non-tree clients alike. Failure modes include ambiguous anchor semantics, unsupported host-object kinds, or anchor specifications that cannot be resolved under the active Makie scene state.
  - **Tested**: yes

- **Name**: Paleobiology/PhyloPic bridge
  - **Responsibility**: Resolve PBDB taxonomy terms and identifiers into PhyloPic node/image selections and feed that result into the generic renderer.
  - **Interface**: PBDB-specific lookup and enrichment functions, including cached acquisition paths. Failure modes include no resolvable PhyloPic node, missing image for selected rendering, and external API/network failures.
  - **Tested**: yes

- **Name**: Documentation and rendered-example verification layer
  - **Responsibility**: Ensure the final public surface, standalone `PhyloPicMakie.jl` examples, tree examples, and rendered artifacts stay synchronized with the approved architecture.
  - **Interface**: Guide pages, API reference pages, isolated `examples/src` scripts with an `examples` project where required, and render-check harnesses. Failure modes include outdated examples, docs that describe superseded keywords, example environments that drift from package reality, and render artifacts that contradict intended placement behavior.
  - **Tested**: yes

## Governance and controlled vocabulary

- Governance documents that must be read line by line downstream:
  - `CONTRIBUTING.md`
  - `STYLE-architecture.md`
  - `STYLE-docs.md`
  - `STYLE-git.md`
  - `STYLE-julia.md`
  - `STYLE-makie.md`
  - `STYLE-upstream-contracts.md`
  - `STYLE-verification.md`
  - `STYLE-vocabulary.md`
  - `STYLE-workflow-docs.md`
  - `STYLE-writing.md`
- Repo-local governance status outside `PaleobiologyDB.jl`:
  - No repo-local `CONTRIBUTING*.md` or `STYLE*.md` files were found in the checked-out `PhyloPicMakie.jl` root. Work there remains governed by the active project governance set for this run plus the explicit upstream primary-source obligations listed below.
- Vocabulary decisions and required cleanup:
  - `tip` terminology is to be treated as legacy debt and cleaned up toward `leaf` terminology.
  - Current names such as `tip_positions`, `augment_tip_phylopic!`, `showtips`, `tip_xoffset`, and `tip_yoffset` are not vocabulary-compliant and should be hard-renamed or replaced with `leaf*` equivalents.
  - `edge`, not `branch`, remains the canonical structural term in code identifiers.
  - Public surfaces and docs must continue to use canonical project spellings such as `rootnode`, `edgeweight`, `lineageunits`, and `node_positions`.
  - Downstream work must not preserve the appearance of vocabulary compliance while silently retaining proscribed legacy identifiers without explicit exception approval.
- Terms to avoid:
  - `tip` as the canonical long-term concept term,
  - `branch` in code identifiers where `edge` is intended,
  - vague phrases such as “Makie way” instead of explicit host-framework contracts.

## Primary upstream references

- Makie primary sources:
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/docs/src/explanations/conversion_pipeline.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/docs/src/explanations/recipes.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/docs/src/reference/generic/space.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/docs/src/explanations/cameras.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/utilities/projection_utils.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/basic_recipes/textlabel.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/CairoMakie/src/scatter.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/test/boundingboxes.jl`
- `PhyloPicMakie.jl` primary sources:
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/PhyloPicMakie.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_coordinates.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_render_core.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_augment_api.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/test/test_coordinates.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/test/test_render_core.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/test/test_makie_integration.jl`
- Additional graph-stack primary sources for standalone `PhyloPicMakie.jl` examples:
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Graphs.jl/README.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Graphs.jl/docs/src/first_steps/construction.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Graphs.jl/docs/src/first_steps/plotting.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/MetaGraphsNext.jl/README.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/MetaGraphsNext.jl/docs/src/index.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/MetaGraphsNext.jl/docs/src/api.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/MetaGraphsNext.jl/src/metagraph.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/GraphMakie.jl/README.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/GraphMakie.jl/docs/src/index.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/GraphMakie.jl/src/recipes.jl`
- `PaleobiologyDB.jl` current-state sources:
  - `examples/src/taxonomytree.jl`
  - `ext/TaxonomyMakie/_layout.jl`
  - `ext/TaxonomyMakie/_recipe.jl`
  - `ext/TaxonomyMakie/_augment.jl`
  - `ext/TaxonomyMakie/_phylopic.jl`
  - `ext/TaxonomyMakie/PhyloPic/src/_render.jl`
  - `test/taxonomytree_makie.jl`
  - `docs/src/guide/taxonomytree_makie.md`
  - `docs/src/api/taxonomytree_makie.md`
- Additional user-supplied PhyloPic context:
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/phylopic/code-recipies-for-the-phylopic-api.md`

## Tranche gates

- Required green checks at tranche start and end:
  - relevant package tests for `PaleobiologyDB.jl`,
  - relevant package tests for `PhyloPicMakie.jl` when that package is modified,
  - no unauthorized regressions in unaffected plotting or PhyloPic functionality.
- Required docs, example builds, or integration outputs:
  - updated API docs and guide pages for any renamed or redesigned public surface,
  - standalone `PhyloPicMakie.jl` examples in `examples/src` runnable from an isolated `examples` project, independent of `PaleobiologyDB.jl`,
  - a rendered tree+PhyloPic example artifact demonstrating visible, correctly placed glyphs,
  - updated example script(s) when user-facing workflow changes.
- Migration and compatibility verification obligations:
  - no default compatibility layer is required,
  - any proposed public API break must be explicitly surfaced for approval before implementation is finalized,
  - final documentation must match the approved final surface exactly.
- Regression expectations:
  - one-step and two-step tree overlay paths must remain behaviorally aligned,
  - glyph aspect and placement must remain stable under figure resize and auto-limit changes,
  - caching-enabled live checks should use `set_autocaching!(true)` for slow PBDB/PhyloPic paths.

## Testing and verification decisions

- What must stay green throughout:
  - offline layout and recipe tests,
  - PhyloPic renderer unit tests in `PhyloPicMakie.jl`,
  - taxonomy/PhyloPic bridge tests relevant to image lookup and caching,
  - docs for any touched pages,
  - at least one example render artifact.
- What examples or integration artifacts must be checked:
  - at least one standalone `PhyloPicMakie.jl` example run from `julia --project=examples examples/src/<name>.jl`,
  - `examples/src/taxonomytree.jl`,
  - one rendered output showing `show_phylopic = true`,
  - one explicit two-step overlay flow using the lower-level tree-aware API,
  - one resize or relimit scenario proving glyph size/aspect do not collapse.
- What migration verification is required if breakage is allowed:
  - because no active external users are assumed, the main required artifact is accurate finalized documentation rather than compatibility shims,
  - user approval is still required for any final public-surface break list.
- Prior art in the codebase to use as reference:
  - `PhyloPicMakie.jl` coordinate and rendering tests for generic glyph correctness,
  - Makie projection helpers and text-label recipe patterns for mixed data/pixel-space behavior,
  - existing `TaxonomyMakie` explicit overlay API in `_augment.jl` as the conceptual starting point for a thin wrapper.
- What makes a good test for this work:
  - a test that would have failed for the current bug,
  - direct inspection of glyph size or rendered bounding extent rather than only `@test_nowarn`,
  - checks of anchor relationships relative to leaf positions or label-origin policy,
  - visual or artifact-level verification for the rendered happy path.

## Out of scope

- Broad redesign of unrelated PBDB taxonomy-query APIs not required for tree glyph overlays.
- Unrelated PhyloPic thumbnail-grid redesign unless a shared helper must move for sound ownership.
- General documentation overhaul beyond the pages touched by the approved surface changes.
- Long-term external compatibility support or migration shims for unreleased APIs, unless the user later requests them.
- Solving every possible future annotation use case in this effort if it would introduce speculative abstractions without a concrete need.

## Open questions

- **Question**: Which low-level `PhyloPicMakie` mechanism should power the new generic anchored-overlay API when placement depends on rendered screen geometry?
  - **Plain-language form**: for cases like tree labels, axis tick labels, legends, or other rendered objects whose final on-screen location matters, should `PhyloPicMakie`:
    - extend its current reactive data-space `image!` path until it can robustly express those screen-dependent placements itself, or
    - adopt an explicit projected-anchor primitive so higher-level clients can hand it a resolved screen-space or pixel-space anchor and let the renderer handle the rest?
  - **Owner**: first foundational tranche.
  - **Suggested resolution path**: prototype both within the approved disruption boundary, measure them against resize/reactivity and placement tests, and keep the general-purpose winner in `PhyloPicMakie` so tree, tick, legend, marker, and arbitrary-overlay clients can all share it.
  - **Current recommendation**: make the product-level decision now that `PhyloPicMakie` should grow a first-class generic anchored-overlay surface; inside that boundary, bias toward a reusable projected-anchor primitive if rendered-object screen geometry is the true contract, because that keeps Makie-space projection mechanics in the general renderer and keeps `TaxonomyMakie` focused on leaf and label policy rather than renderer internals.

## Further notes

- The reproduced live render confirmed the visible failure mode directly: PhyloPic glyphs are functionally invisible in the current example output.
- Runtime inspection also confirmed the immediate mechanism: the integrated tree recipe path creates one scatter per glyph with approximately `2 × 2` pixel `markersize`, which is consistent with `_axis_pixels_per_data` falling back to `1.0` before stable viewport/data-limit information exists.
- The explicit tree-aware overlay API in `ext/TaxonomyMakie/_augment.jl` already demonstrates the desired ownership direction conceptually by delegating rendering to `PhyloPic.augment_phylopic!`; the redesign should unify the integrated and explicit overlay paths instead of maintaining two separate rendering owners.
- Downstream tranches must keep the architectural distinction clear:
  - `TaxonomyMakie` may own leaf extraction and label-relative overlay planning.
  - `PhyloPicMakie` should own general glyph rendering behavior and any truly reusable Makie-space helpers.
- This PRD authorizes foundational redesign because the current failure is a symptom of misowned duplicated behavior, not merely a bad constant or isolated recipe bug.
