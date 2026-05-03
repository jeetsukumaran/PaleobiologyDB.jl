# Focused repair tasking: Taxonomy tree overlay owner and limits repair

## Scope

This is a surgical code-fix tasking for the current public tree-overlay
regression.

It is not an example-reset tasking, not a docs-truth tasking, and not a broad
architecture reopen. The target is the actual render-owner bug behind the
collapsed `taxonomytreeplot(...; show_phylopic = true)` output.

The fix must repair the public tree-overlay path itself:

- integrated one-step tree overlays
- explicit `augment_leaf_phylopic!(ax, plt; ...)` two-step overlays
- their render-parent ownership
- their axis-limit behavior
- and the missing regression tests that should have caught this

The example may be touched only as a final truth check or minimal follow-on if
the fixed code changes how the example should be invoked. The example is not
the owner of this bug.

## Settled user decisions

Implementation must treat the following as fixed input:

- The screenshot failure is the real problem to solve. This is not a side issue
  or an example-style issue.
- The current output collapse is unacceptable and must be fixed in code, not
  hidden.
- The fix must target the real public path, not only the internal axis-backed
  helper path.
- Do not solve this by hard-coding axis limits, suppressing autolimits, or
  otherwise masking the bug in the example.
- Do not “fix” the example while leaving the public overlay path broken.
- Do not reopen the wider architecture unless a clean repair truly requires it;
  if so, escalate the exact reason rather than silently broadening scope.

## Governance

Mandated line-by-line reading applies before implementation begins.

All tasks must comply with:

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
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-architecture.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-docs.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-git.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-julia.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-makie.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-upstream-contracts.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-verification.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-vocabulary.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-workflow-docs.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-writing.md`

Primary-source owners that must be re-read in full before editing:

- `ext/TaxonomyMakie/_recipe.jl`
- `ext/TaxonomyMakie/_augment.jl`
- `ext/TaxonomyMakie/_leaf_overlay.jl`
- `ext/TaxonomyMakie/_layout.jl`
- `ext/TaxonomyMakie/PhyloPic/src/_render.jl`
- `examples/src/taxonomytree.jl`
- `test/taxonomytree_makie.jl`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_anchored_overlay.jl`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_render_core.jl`
- `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/docs/src/explanations/conversion_pipeline.md`
- `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/utilities/projection_utils.jl`
- `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/layouting/data_limits.jl`
- `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/scenes.jl`
- `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/CairoMakie/src/scatter.jl`

## Current-state diagnosis

The current broken output is caused by a render-owner mismatch, not by the
tree layout itself and not by the example script itself.

Verified current-state facts:

- The pure tree layout in `ext/TaxonomyMakie/_layout.jl` still produces sane
  small data-space coordinates for the tree.
- The shared label-aware tree planner in `ext/TaxonomyMakie/_leaf_overlay.jl`
  produces sane label-relative anchors.
- The shared anchored-overlay substrate in `PhyloPicMakie.jl` behaves
  sensibly when parented to a `Makie.Axis`.
- The integrated public path in `ext/TaxonomyMakie/_recipe.jl` currently
  renders the overlay into `p::TaxonomyTreePlot`, not into the axis.
- The explicit convenience overload in `ext/TaxonomyMakie/_augment.jl` also
  accepts `ax::Makie.Axis` but ignores it and renders into `p`.
- Offline reproduction with a mock tree shows:
  - axis-backed overlay path: sane `ax.finallimits`
  - plot-backed overlay path: exploded `ax.finallimits`
- The current tests mostly prove the safe axis-backed helper path and do not
  assert final axis-limit sanity on the real public path.

This is therefore a real public-path contract failure:

- wrong render owner
- wrong limit ownership
- weak regression coverage

## Non-negotiable execution rules

- Do not fix this by hard-coding `xlims!` or `ylims!` in the example.
- Do not fix this by suppressing or clamping autolimits.
- Do not leave `augment_leaf_phylopic!(ax, p; ...)` accepting an axis and then
  ignoring it.
- Do not leave any visible overlay plot with `space = :pixel` parented under
  `plt.plots`.
- Do not regress lifecycle cleanup while moving the render owner to the axis.
- Do not solve the bug only for the internal helper path while leaving
  `taxonomytreeplot(...; show_phylopic = true)` broken.
- Do not let structural assertions or test-only probes substitute for a visibly
  correct public plot.
- Do not write tests first and then steer the logic toward satisfying narrow
  assertions. Fix the public behavior first, then encode that truth in tests.
- Do not weaken verification to smoke-only `@test_nowarn` checks.
- Do not turn this into a docs-policing or example-reset pass.

## Concrete anti-patterns or removal targets

The following are explicit repair targets:

- `ext/TaxonomyMakie/_recipe.jl` calling `_augment_leaf_phylopic!(p, ...)` for
  the integrated public overlay path.
- `ext/TaxonomyMakie/_augment.jl` ignoring the public `ax::Makie.Axis`
  argument in the `augment_leaf_phylopic!(ax, p::TaxonomyTreePlot; ...)`
  convenience overload.
- any plot-backed path that leaves pixel-space overlay plots inside
  `TaxonomyTreePlot` children.
- any public-path state where the overlay changes final axis limits from
  tree-scale coordinates to huge probe- or screen-space extents.
- any test coverage that proves only the axis-backed helper path while skipping
  the real public path.

## Failure-oriented and positive verification

The final implementation must include checks that would have failed on the
current broken code:

- an offline regression that proves the integrated public path keeps sane
  `ax.finallimits`
- an offline regression that proves the explicit convenience path
  `augment_leaf_phylopic!(ax, plt; ...)` keeps sane `ax.finallimits`
- a regression that would fail if the `ax` argument is ignored again
- a regression that would fail if a visible pixel-space overlay plot is parented
  under `plt.plots`
- a lifecycle regression that proves moving ownership to the axis does not
  reintroduce leaked support plots or leaked overlays
- a manual or scripted check that `examples/src/taxonomytree.jl` no longer
  produces the corner-collapsed output after the code fix

Positive verification is also required:

- the public one-step path must render a visibly sane tree-plus-PhyloPic plot
- the public two-step path must render a visibly sane tree-plus-PhyloPic plot
- both must preserve the documented label-relative placement contract

The order of operations matters:

- first make the real public behavior correct
- then confirm it manually or with a rendered artifact
- only then add or tighten tests around that repaired behavior

## Tasks

### 1. Revalidate and reproduce the owner mismatch on the real public path

**Type**: REVIEW  
**Output**: A verified start-state note that reproduces the current bug offline and identifies the exact owner mismatch in the integrated and explicit public paths.  
**Depends on**: none

Re-read the current tree overlay, shared overlay, and Makie owner files in
full. Reproduce the failure offline with a mock tree and a local glyph so the
diagnosis does not depend on PBDB or PhyloPic network behavior. Confirm all of
the following explicitly before editing:

- the axis-backed internal helper path has sane limits
- the plot-backed public path has exploded limits
- `taxonomytreeplot(...; show_phylopic = true)` currently routes through the
  plot-backed path
- `augment_leaf_phylopic!(ax, p; ...)` currently ignores `ax`

Do not change production code in this task unless a tiny diagnosis-only probe
is required to make the failure concrete.

### 2. Repair the render-owner contract in the integrated and explicit public paths

**Type**: WRITE  
**Output**: The integrated one-step path and the explicit convenience path both render through the correct axis owner instead of `TaxonomyTreePlot`.  
**Depends on**: 1

Repair `ext/TaxonomyMakie/_recipe.jl` and `ext/TaxonomyMakie/_augment.jl` so
the public tree-overlay paths use the axis as the render owner. The explicit
convenience overload must stop ignoring its `ax` argument. The integrated
`show_phylopic = true` path must no longer parent visible overlay plots into
`p.plots`. If additional plumbing is needed to access or preserve the correct
axis owner from the recipe path, add it cleanly rather than patching around
the symptom.

This task is about owner correctness, not cosmetic masking. Do not hard-code
axis limits. Do not suppress autolimits. End the task with the touched code in
a locally sane state, the obvious owner mismatch removed, and at least one
manual or scripted sanity check confirming that the public plot no longer
collapses into the corner before any new regression tests are written.

### 3. Preserve lifecycle ownership while moving render ownership to the axis

**Type**: WRITE  
**Output**: Axis-parented overlays and support plots remain teardown-safe and visibility-safe under tree plot lifecycle operations.  
**Depends on**: 2

Moving the render owner to the axis must not break lifecycle cleanup. Refactor
`ext/TaxonomyMakie/_leaf_overlay.jl` and any adjacent owner code needed so the
tree plot still owns the lifecycle of the overlays it creates, even if the
actual visible overlay plots and probe plots are axis-parented. If the cleanest
solution requires a managed handle or explicit association between the tree plot
and axis-owned overlay artifacts, implement that. This task fails if the fix
restores sane limits but regresses teardown or visibility behavior. Before
moving on, verify the repaired path still produces a visibly sane plot on the
real public flow.

### 4. Add public-path regression tests for owner identity, sane limits, and lifecycle after the behavior is visibly fixed

**Type**: TEST  
**Output**: Automated tests fail on the current broken code and pass only when the real public-path owner bug is fixed.  
**Depends on**: 3

Strengthen `test/taxonomytree_makie.jl` so it verifies the actual public path,
not only the safe internal helper path. At minimum, add offline tests that:

- exercise the integrated tree-overlay path on a mock tree and assert sane
  `ax.finallimits`
- exercise `augment_leaf_phylopic!(ax, plt; ...)` on a mock tree and assert
  sane `ax.finallimits`
- fail if the explicit convenience path ignores `ax`
- fail if a visible pixel-space overlay plot ends up inside `plt.plots`
- preserve lifecycle cleanup expectations after the owner repair

Do not settle for `@test_nowarn`. The new tests must verify the real external
behavior that was broken. Keep the tests honest and behavior-driven: prefer
checks tied to sane limits, real overlay presence, and lifecycle truth over
fragile internal-string or implementation-shape assertions that could pass for
the wrong logic.

### 5. Verify the real user-facing example path after the code fix

**Type**: REVIEW  
**Output**: A truthful closeout showing that the code fix reaches the user-facing example and removes the corner-collapsed output.  
**Depends on**: 4

Run the targeted verification honestly after the code fix:

- the touched offline tree-overlay tests
- the relevant `test/runtests.jl` path if the changed scope requires it
- `examples/src/taxonomytree.jl` with caching enabled where appropriate

Confirm that the example now produces a visibly sane tree-plus-PhyloPic output
instead of the collapsed corner plot. If the example still needs a minimal
truth-alignment update after the code fix, make that update here, but do not
turn this task into a separate example redesign effort.
