# Strict delivery tasking: taxonomy tree PhyloPic overlay owner fix

Parent PRD: `01_prd.md`  
Related tranche: `02_tranches.md` Tranche 3 / Tranche 5 stabilization overlap  
Related tasking superseded for this bug: `03_public-overlay-owner-fix--tasking.md`

## Purpose

This file exists because the ordinary tasking and review flow repeatedly
allowed the real public-path bug to survive while internal helper paths looked
green.

This strict tasking removes implementation discretion for the current bug.

The desired end product is fixed up front:

- `taxonomytreeplot(...; show_phylopic = true)` renders a sane tree-plus-glyph
  plot
- `augment_leaf_phylopic!(ax, plt; ...)` renders a sane tree-plus-glyph plot
- neither path blows up axis limits
- neither path parents visible pixel-space overlay plots into
  `TaxonomyTreePlot`
- deleting the tree plot still deletes all tree-owned overlay artifacts

Do not reinterpret this file as a design prompt. It is a delivery spec.

## Settled implementation decisions

The following implementation decisions are already made. The implementing agent
must not improvise alternatives unless a decision is proven technically
impossible, in which case the agent must stop and report the exact blocker.

### 1. The integrated overlay owner is the tree plot's parent scene

For the integrated one-step path in `ext/TaxonomyMakie/_recipe.jl`, the overlay
must be rendered into:

- `Makie.parent_scene(p)`

not into:

- `p::TaxonomyTreePlot`

This decision is already validated by offline reproduction:

- rendering into `Makie.parent_scene(p)` keeps sane limits
- rendering into `p` explodes limits

No alternate owner choice is allowed for this fix pass.

### 2. The explicit convenience overload must honor the axis argument

For `augment_leaf_phylopic!(ax, p::TaxonomyTreePlot; ...)` in
`ext/TaxonomyMakie/_augment.jl`:

- the overlay parent must be `Makie.get_scene(ax)`
- the implementation must validate that `Makie.get_scene(ax) === Makie.parent_scene(p)`
- if they differ, the function must throw `ArgumentError`

The function must not ignore `ax`.

### 3. A single internal helper must own plot-backed overlay attachment

Introduce one internal helper and route both public paths through it.

Required helper:

- file: `ext/TaxonomyMakie/_leaf_overlay.jl` or `ext/TaxonomyMakie/_recipe.jl`
- name: `_attach_plot_leaf_phylopic_overlay!`

Required inputs:

- `overlay_parent`
- `p::TaxonomyTreePlot`

Required keyword overrides:

- `glyph::Union{AbstractMatrix, Nothing} = nothing`
- `taxon::Union{AbstractVector, Nothing} = nothing`
- plus the existing overlay-policy keywords already needed by the public path

Required behavior:

- compute the existing label-aware or node-aware plan through
  `_plan_leaf_plot_phylopic_overlay`
- render the overlay through `_augment_leaf_phylopic!` using `overlay_parent`
- return the managed overlay handle or `nothing`

The integrated recipe path must call this helper with the real public policy
and no glyph override.

The offline tests must call this helper with a local test glyph so the actual
integrated machinery is exercised without PBDB or PhyloPic network dependency.

### 4. Axis-owned overlay handles must be recorded on the tree plot

Add one internal recipe attribute on `TaxonomyTreePlot`:

- name: `axis_overlay_handles`
- initial value: `Any[]`

This attribute is the authoritative registry of axis-scene-owned overlay
artifacts created on behalf of the tree plot.

When the integrated path creates an overlay, push the returned handle into
`p[:axis_overlay_handles][]`.

When the explicit convenience overload creates an overlay on behalf of `p`,
push that handle into `p[:axis_overlay_handles][]` too.

Do not store these handles only in local variables.

### 5. Tree plot deletion must explicitly delete axis-owned overlay handles

Add:

- `Base.delete!(scene::Makie.Scene, p::TaxonomyTreePlot)`

Required behavior:

1. iterate the handles stored in `p[:axis_overlay_handles][]` in reverse order
2. delete each one from `Makie.parent_scene(p)` using `delete!`
3. clear the stored handle vector
4. delegate to Makie's generic plot deletion using:
   - `invoke(Base.delete!, Tuple{Makie.Scene, Makie.AbstractPlot}, scene, p)`

No alternate teardown mechanism is allowed for this fix pass.

### 6. The tree layout is not to be modified

Do not edit `_compute_dendrogram_layout` in `ext/TaxonomyMakie/_layout.jl`
as part of this bug fix unless a separate independent defect is discovered and
proven relevant.

The current diagnosis is an overlay-owner bug, not a layout bug.

### 7. The example is not the owner of the fix

Do not use `examples/src/taxonomytree.jl` as the place to fix the bug.

Allowed example changes in this fix pass:

- minimal truth-alignment after the code fix, if needed
- final manual verification

Forbidden example changes:

- hard-coded `xlims!`
- hard-coded `ylims!`
- clipping or hiding bad output
- changing the example to avoid the public path

## Governance

Read line by line before implementation:

- Bundled governance depot under `/home/jeetsukumaran/site/service/env/start/workhost/resources/packages/shared/workhost-resources/configure/coding-agent-skills/development-policies/references`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/CONTRIBUTING.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-architecture.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-docs.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-git.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-julia.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-makie.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-upstream-contracts.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-verification.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-vocabulary.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-workflow-docs.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-writing.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-makie.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-verification.md`

Primary sources that must be re-read in full:

- `ext/TaxonomyMakie/_recipe.jl`
- `ext/TaxonomyMakie/_augment.jl`
- `ext/TaxonomyMakie/_leaf_overlay.jl`
- `test/taxonomytree_makie.jl`
- `examples/src/taxonomytree.jl`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_anchored_overlay.jl`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_render_core.jl`
- `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/scenes.jl`
- `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/utilities/projection_utils.jl`
- `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/layouting/data_limits.jl`

## Non-negotiable execution rules

- Do not leave any logic choice about render owner to the implementing agent.
- Do not invent a different helper name or different owner registry.
- Do not fix this with axis-limit clamping, clipping, or example-only masking.
- Do not move visible pixel-space overlay plots back under `p.plots`.
- Do not leave the explicit convenience overload permissive when `ax` and `p`
  belong to different scenes; it must throw.
- Do not modify PBDB lookup logic, example philosophy, or docs contracts as
  part of this fix unless absolutely required for verification truth.
- Do not add brittle source-text assertions in place of behavior checks.
- Do not rely on live PBDB or PhyloPic fetches for the core regression tests.

## Required revalidation before editing

Before changing code, reproduce all of the following:

1. axis-backed path is sane
2. scene-backed path is sane
3. plot-backed path is broken
4. integrated public path currently uses the plot-backed owner
5. explicit convenience path currently ignores `ax`

The reproductions must use:

- the existing mock tree fixture shape from `test/taxonomytree_makie.jl`
- a local matrix glyph such as the existing `_TEST_GLYPH`
- no live PBDB or PhyloPic network dependency

If any of those five facts are no longer true, stop and report the exact delta
before implementing.

## Tasks

### 1. Add the fixed owner plumbing exactly as specified

**Type**: WRITE  
**Output**: The code routes integrated and explicit plot-backed overlays through the exact scene-owner and helper contract specified above.  
**Depends on**: none

Implement exactly these code changes:

1. In `ext/TaxonomyMakie/_recipe.jl`, add the internal recipe attribute
   `axis_overlay_handles = Any[]`.
2. Add `_attach_plot_leaf_phylopic_overlay!` with the required signature and
   behavior described above.
3. Change the integrated `show_phylopic = true` path to call
   `_attach_plot_leaf_phylopic_overlay!(Makie.parent_scene(p), p; ...)`.
4. In `ext/TaxonomyMakie/_augment.jl`, change
   `augment_leaf_phylopic!(ax, p::TaxonomyTreePlot; ...)` so it:
   - validates `Makie.get_scene(ax) === Makie.parent_scene(p)`
   - throws `ArgumentError` on mismatch
   - otherwise calls `_attach_plot_leaf_phylopic_overlay!(Makie.get_scene(ax), p; ...)`
5. Ensure both paths append returned handles into `p[:axis_overlay_handles][]`.

At the end of this task, the public code path must already render sanely in a
manual or scripted local check before any new tests are added.

### 2. Add explicit lifecycle ownership for axis-scene overlays

**Type**: WRITE  
**Output**: Deleting a `TaxonomyTreePlot` deletes its axis-scene-owned overlays and support plots through the exact registered handle path.  
**Depends on**: 1

Implement exactly these code changes:

1. Add `Base.delete!(scene::Makie.Scene, p::TaxonomyTreePlot)`.
2. In that method:
   - iterate `p[:axis_overlay_handles][]` in reverse
   - call `delete!(Makie.parent_scene(p), handle)` for each
   - clear the vector
   - call
     `invoke(Base.delete!, Tuple{Makie.Scene, Makie.AbstractPlot}, scene, p)`
3. Do not substitute a scene sweep, child scan, or GC-dependent cleanup for
   this explicit handle deletion path.

At the end of this task, rerun the existing deletion scenario manually and
confirm no overlay artifacts remain after deleting the tree plot.

### 3. Replace the weak coverage with exact offline public-path regressions

**Type**: TEST  
**Output**: `test/taxonomytree_makie.jl` now fails on the current bug class and passes only on the delivered owner fix.  
**Depends on**: 2

Implement exactly these tests, offline, using the mock tree plus local glyph:

1. `integrated helper uses scene owner and keeps sane limits`
   - create `fig, ax, plt = taxonomytreeplot(tree; show_phylopic = false)`
   - call `_attach_plot_leaf_phylopic_overlay!(Makie.parent_scene(plt), plt; glyph = _TEST_GLYPH, ...)`
   - materialize
   - assert `ax.finallimits[]` remains tree-scale and not screen-scale
   - assert visible result exists

2. `explicit convenience overload honors axis and keeps sane limits`
   - create `fig, ax, plt = taxonomytreeplot(tree; show_phylopic = false)`
   - call the repaired convenience path on matching `ax`
   - materialize
   - assert sane `ax.finallimits[]`

3. `explicit convenience overload rejects mismatched axis`
   - create `fig, ax1, plt = taxonomytreeplot(tree; show_phylopic = false)`
   - create a second axis `ax2`
   - assert `augment_leaf_phylopic!(ax2, plt; ...)` throws `ArgumentError`

4. `tree plot does not own visible pixel-space overlay plots`
   - after creating a repaired overlay, inspect `plt.plots`
   - assert no visible glyph scatter with `space = :pixel` is present there

5. `deleting the tree plot deletes axis-scene overlay handles`
   - create overlay through the repaired path
   - assert `p[:axis_overlay_handles][]` is non-empty
   - delete the tree plot
   - materialize
   - assert no managed overlay artifacts remain in the axis scene

These tests must be behavior checks, not string checks and not `@test_nowarn`
substitutes.

### 4. Run the real user-facing example after the code fix

**Type**: REVIEW  
**Output**: The saved `examples/build/taxonomytree.png` is visibly sane after the code repair.  
**Depends on**: 3

Run:

- the touched `test/taxonomytree_makie.jl` scope
- then `examples/src/taxonomytree.jl`

Confirm the example no longer collapses the tree into the lower-left corner.
If the example needs a minimal truth-alignment edit after the code fix, make
only that minimal edit. Do not redesign the example here.

### 5. Close the fix with honest end-green verification

**Type**: REVIEW  
**Output**: A truthful closeout that the delivered code fixes the actual bug rather than only its tests.  
**Depends on**: 4

Run the relevant verification honestly:

- touched offline test scope in `test/taxonomytree_makie.jl`
- `julia --project=test test/runtests.jl` if the touched scope requires it
- `examples/src/taxonomytree.jl`

The fix is complete only if all of the following are true:

- the integrated path uses `Makie.parent_scene(p)`
- the explicit convenience path honors and validates `ax`
- axis-scene overlay handles are recorded and deleted explicitly
- the real example output is sane
- the bug is fixed in behavior, not merely in tests
