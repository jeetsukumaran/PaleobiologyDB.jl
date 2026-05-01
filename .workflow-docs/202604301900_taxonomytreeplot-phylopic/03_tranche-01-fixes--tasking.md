# Tasks for Tranche 1 Fixes: Anchored Overlay Lifecycle and Contract Repair

Parent tranche: Tranche 1
Parent PRD: `01_prd.md`
Related tranche tasking: `03_tranche-01--tasking.md`

## Governance

Mandated line-by-line reading applies to all relevant governance documents for both repositories covered by the tranche. These fixes are expected to stay inside `PhyloPicMakie.jl`, but the same tranche authorities remain active.

All tasks must comply with:

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

Important fix-pass notes:

- `PhyloPicMakie.jl` repo-local `STYLE*.md` files are active authorities. Earlier PRD wording that implied otherwise is stale and must not be repeated.
- `STYLE-makie.md` is especially controlling here. These fixes must satisfy exact Makie scene, plot, and data-limit ownership contracts rather than merely preserving the visual appearance of the current workaround.
- `STYLE-vocabulary.md` remains controlling. Do not reintroduce vague local terminology in new internal names or docs.

Read-only git and shell commands may be used freely. Mutating git operations such as commit, merge, push, and branch remain the human project owner's responsibility unless the user explicitly instructs otherwise.

## Required revalidation before implementation

- Read Tranche 1 in `02_tranches.md`, the parent PRD in `01_prd.md`, and `03_tranche-01--tasking.md` in full.
- Read this fixes tasking file in full before starting implementation.
- Re-read the review-target `PhyloPicMakie.jl` files in full:
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/PhyloPicMakie.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_anchored_overlay.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_coordinates.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_render_core.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_augment_api.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/test/test_anchored_overlay.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/test/test_render_core.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/test/test_makie_integration.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/README.md`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/docs/src/index.md`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/docs/src/api/rendering.md`
- Re-read the Makie primary sources that constrain these specific fixes:
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/docs/src/explanations/conversion_pipeline.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/docs/src/explanations/recipes.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/docs/src/reference/generic/space.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/utilities/projection_utils.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/basic_recipes/textlabel.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/scenes.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/makielayout/blocks/axis.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/layouting/data_limits.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/CairoMakie/src/scatter.jl`
- Re-check the live verification state honestly. At minimum, rerun the touched `PhyloPicMakie.jl` tests that cover anchored overlays, integration behavior, and render-core behavior before editing code.
- If the review diagnosis no longer matches reality, stop and raise that before changing code.

## Fix scope established by review

The follow-on implementation must repair the specific Tranche 1 regressions identified in architecture review:

- Hidden probe `Scatter` plots created by `_augment_phylopic_anchored!` outlive the visible overlay and continue to affect scene ownership and `autolimits!` after the returned overlay plot is deleted.
- The new integration coverage exercises resize and relimit reactivity while the overlay is alive, but it does not verify deletion, visibility transitions, or post-removal `autolimits!`, so the lifecycle regression currently slips through green verification.
- The public `on_missing = :placeholder` contract drifted: docs still promise a small gray rectangle while the implementation now renders a placeholder image glyph.

These tasks are fix-forward work inside Tranche 1. They do not reopen the tranche architecture question, and they must not revert to ad hoc geometry or client-side Makie-space reconstruction.

## Tranche execution rule

This fix pass remains inside the Tranche 1 disruption boundary. It may change internal owner structures, helper types, and test scaffolding inside `PhyloPicMakie.jl`, but it must end with:

- a lifecycle-safe anchored-overlay owner,
- render-aware tests that catch the deletion and `autolimits!` regression,
- truthful public contract documentation,
- and the touched verification path green.

External public API breaks are not authorized by this fix pass without fresh user approval. Internal return-type or helper refactors are allowed if they are necessary to make overlay ownership correct and testable.

## Tasks

### 1. Revalidate the Lifecycle Regression and Choose the Repair Strategy

**Type**: REVIEW
**Output**: A verified start-state diagnosis for the fix pass, including confirmed reproduction of the hidden-probe lifecycle defect, confirmed Makie ownership constraints, and a chosen repair direction for overlay teardown and data-limit ownership.
**Depends on**: none

Read the tranche, parent PRD, prior tranche tasking, this fixes tasking file, and the active governance set in full. Reproduce the review finding against the live `PhyloPicMakie.jl` state by confirming that a data-anchor overlay created through `_augment_phylopic_anchored!` leaves probe plots behind after deletion and that those probe plots still influence `autolimits!` or scene ownership. Use the cited Makie sources to determine the exact host contract for plot deletion, scene plot lists, and data-limit participation before choosing a repair shape. Do not edit production code in this task unless a tiny verification-only probe is required to make the reproduction diagnosable. End the task with a precise implementation note describing whether the repair will use a composite owner object, coordinated plot attachment and teardown, or another Makie-compliant ownership mechanism.

---

### 2. Repair Anchored Overlay Ownership, Teardown, and Data-Limit Behavior

**Type**: WRITE
**Output**: `_augment_phylopic_anchored!` owns and tears down all supporting probe plots correctly, so deleting or otherwise deactivating an overlay no longer leaves hidden plots behind or pollutes axis data limits.
**Depends on**: 1

Refactor the anchored-overlay implementation in `src/_anchored_overlay.jl`, plus `src/PhyloPicMakie.jl` or other internal files as needed, so the visible overlay and any transparent support plots form one coherent owner-level unit. The returned handle must let callers manage the entire overlay lifecycle rather than only the visible scatter plot. Follow the Makie contracts in `scenes.jl`, `axis.jl`, `data_limits.jl`, and the projection-related sources instead of building a local pseudo-lifecycle. If the fix requires replacing the current raw `Makie.Plot` return with a small internal owner object, do that cleanly and keep the public `augment_phylopic!` entry points behaviorally unchanged. End the task with touched-scope code and tests green, and with no hidden probe plots surviving the supported teardown path.

---

### 3. Add Lifecycle and `autolimits!` Regression Coverage

**Type**: TEST
**Output**: Integration and render-aware tests fail on the reviewed lifecycle bug class and pass on the repaired implementation, including deletion or deactivation and post-removal `autolimits!` checks.
**Depends on**: 2

Extend `test/test_makie_integration.jl` and any closely related anchored-overlay tests so the suite covers the lifecycle contract that Tranche 1 is supposed to establish. Add checks that create a data-anchor overlay, materialize the figure, exercise the supported teardown or deactivation path, and verify that scene plots, overlay ownership, and `autolimits!` behavior return to the expected post-removal state. Keep the existing resize and relimit reactivity checks, but add assertions that would have failed on the hidden-probe leak. If helper fixtures are needed, keep them local to the Makie integration or anchored-overlay tests rather than scattering ad hoc harness code across the suite. End the task with the touched verification slice green and with the historical regression explicitly encoded.

---

### 4. Resolve the Placeholder Contract Drift

**Type**: WRITE
**Output**: The public `on_missing = :placeholder` contract is internally consistent across code, tests, and docs, with one clearly chosen behavior.
**Depends on**: 3

Resolve the mismatch between the public docs and the current implementation for missing-image placeholders. Either keep the image-glyph placeholder and update the public contract text, or restore rectangle semantics if that is the intended behavior, but do not leave the implementation and docs disagreeing. Touch `src/_render_core.jl`, `src/_augment_api.jl`, `README.md`, `docs/src/index.md`, `docs/src/api/rendering.md`, and any relevant tests only as needed to make the chosen behavior truthful and verifiable. End the task with touched-scope tests green and no remaining placeholder-description drift.

---

### 5. Re-run End-Green Verification for the Fix Pass

**Type**: REVIEW
**Output**: A truthful end-state verification result for the Tranche 1 fix pass, covering the repaired lifecycle behavior, the updated regression tests, and any touched docs or package-level checks.
**Depends on**: 4

Run the touched verification path again at end state in `PhyloPicMakie.jl`. At minimum this includes the anchored-overlay, render-core, and Makie integration tests that cover the repaired lifecycle and placeholder behavior. If docs were materially touched, rerun the docs build path as required by the tranche and repo policies. If the environment permits it without new blockers, rerun the full `julia --project=. -e 'import Pkg; Pkg.test()'` package path and report honestly whether `Aqua` and `JET` complete. This task closes the fix pass and must leave the repository in a policy-compliant green state for the implemented scope.

---
