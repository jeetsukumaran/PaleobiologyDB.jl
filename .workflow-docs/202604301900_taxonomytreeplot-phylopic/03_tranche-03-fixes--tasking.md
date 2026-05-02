# Tasks for Tranche 3 fixes: Ownership, parity, and portability repair

Parent tranche: Tranche 3
Parent PRD: `01_prd.md`
Related tranche tasking: `03_tranche-03--tasking.md`

## Governance

Mandated line-by-line reading applies to all relevant governance documents for both repositories. This fix pass is still a Tranche 3 architecture repair and may need to touch both `PaleobiologyDB.jl` and `PhyloPicMakie.jl` to restore the intended owner boundary honestly.

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

- The Tranche 03 review findings are not secondary polish. They are failures against the tranche's primary goals: portable repo state, one owner for generic rendering, one owner for tree-specific planning, and one-step versus two-step parity.
- The prior tasking was directionally correct, but it was too permissive in three places:
  - It allowed "same underlying overlay machinery" to be interpreted as sharing only the final render backend, rather than sharing the tree-planning contract that determines where glyphs go.
  - It did not explicitly forbid unmanaged Makie probe plots or require planner-created support plots to participate in a teardown owner.
  - It did not explicitly require that generic render-preparation policy remain single-owned in `PhyloPicMakie`, so the PBDB bridge was able to regrow a second generic rendering loop.
- This fixes tasking closes those gaps. Downstream implementation must not claim completion if:
  - explicit and integrated tree overlays still compute materially different anchors for the same documented policy,
  - tree-owned probe plots or overlay artifacts can outlive the tree plot that created them,
  - generic `on_missing`, rotation, mirroring, image filtering, or anchor-position render-preparation logic is still duplicated in `PaleobiologyDB.jl`,
  - or the repo still depends on committed workspace-local path overrides.
- `STYLE-vocabulary.md` remains controlling. Tranche 3 is still not the public-break tranche, so internal code should continue moving toward `leaf*` names, but outward-facing `tip*` rename finalization still belongs to Tranche 4 unless escalation is required.

Read-only git and shell commands may be used freely. Mutating git operations such as commit, merge, push, and branch remain the human project owner's responsibility unless the user explicitly instructs otherwise.

## Required revalidation before implementation

- Read Tranche 3 in `02_tranches.md`, the parent PRD in `01_prd.md`, `03_tranche-03--tasking.md`, and this fixes tasking file in full.
- Re-read the reviewed `PaleobiologyDB.jl` files in full:
  - `Project.toml`
  - `test/Project.toml`
  - `examples/src/taxonomytree.jl`
  - `ext/TaxonomyMakie/TaxonomyMakie.jl`
  - `ext/TaxonomyMakie/_layout.jl`
  - `ext/TaxonomyMakie/_leaf_overlay.jl`
  - `ext/TaxonomyMakie/_augment.jl`
  - `ext/TaxonomyMakie/_recipe.jl`
  - `ext/TaxonomyMakie/PhyloPic/src/PhyloPic.jl`
  - `ext/TaxonomyMakie/PhyloPic/src/_resolve.jl`
  - `ext/TaxonomyMakie/PhyloPic/src/_render.jl`
  - `test/phylopic_makie.jl`
  - `test/taxonomytree_makie.jl`
  - `docs/src/guide/taxonomytree_makie.md`
  - `docs/src/api/taxonomytree_makie.md`
- Re-read the relevant `PhyloPicMakie.jl` owner files in full:
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/PhyloPicMakie.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_anchored_overlay.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_render_core.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_augment_api.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/test/test_anchored_overlay.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/test/test_render_core.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/test/test_makie_integration.jl`
- Re-read the Makie primary sources that constrain the lifecycle, projection, and data-limit portions of these fixes:
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/docs/src/explanations/conversion_pipeline.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/docs/src/explanations/recipes.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/docs/src/reference/generic/space.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/utilities/projection_utils.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/basic_recipes/textlabel.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/scenes.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/makielayout/blocks/axis.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/layouting/data_limits.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/CairoMakie/src/scatter.jl`
- Reproduce the review findings honestly before editing:
  - committed workspace-local `Project.toml` path overrides,
  - explicit versus integrated anchor mismatch for long labels,
  - unmanaged tree-planning probe plots or overlay lifecycle leaks,
  - duplicated generic render-preparation logic in the PBDB bridge.
- If the diagnosis no longer matches reality, stop and raise that before changing code.

## Fix scope established by review

This fix pass must repair the Tranche 03 review failures directly:

- Restore portable repository dependency configuration. No committed workspace-local `path = ...` override for `PhyloPicMakie` may remain in `Project.toml` or `test/Project.toml`.
- Re-establish one owner for generic render-preparation behavior. PBDB-side code may resolve taxonomy names to images, but generic anchored render preparation, `on_missing` handling, placeholder choice, rotation, mirroring, and route-to-overlay mechanics must not remain duplicated in `PaleobiologyDB.jl`.
- Re-establish one owner for tree-specific planning. A label-aware tree overlay planner may exist in `TaxonomyMakie`, but it must be the shared planner for any tree flow that claims the same placement policy.
- Make one-step and two-step tree overlays genuinely parity-aligned at the contract level. Backend-only reuse is insufficient.
- Repair Makie lifecycle ownership. Tree-created probe plots and overlay artifacts must be owned and torn down with the tree overlay or tree plot that created them.

If a clean fix requires additional internal owner work in `PhyloPicMakie.jl`, do that. Do not preserve a bad boundary merely to keep all edits inside one repository.

## Tranche execution rule

This fix pass remains inside Tranche 3's authorized disruption boundary, but it is now a fix-forward repair of a failed tranche implementation. The work may redesign, replace, or move internals across the two repositories where necessary to restore the intended owner boundary. It must end with:

- portable project and test dependency configuration,
- one-step and explicit tree overlays sharing the same real planning contract where they claim the same behavior,
- no tree-owned probe or overlay lifecycle leaks,
- no duplicate generic render-preparation owner in `PaleobiologyDB.jl`,
- truthful docs for any touched tree-overlay behavior,
- and the required verification artifacts green.

Do not paper over parity by weakening the explicit API claim. If exact parity cannot be achieved without changing the tree-side public surface, stop and escalate rather than silently shipping a narrowed interpretation.

## Tasks

### 1. Revalidate the failure set and lock the non-negotiable repair boundary

**Type**: REVIEW  
**Output**: A verified start-state diagnosis for the Tranche 3 fix pass, including confirmed reproduction of the portability issue, planner-parity failure, lifecycle leak, and generic-owner duplication, plus an explicit note on whether upstream `PhyloPicMakie.jl` work is required for an honest fix.  
**Depends on**: none

Read the parent PRD, Tranche 3, the original Tranche 3 tasking, this fixes tasking file, and the active governance set in full. Reproduce the review findings directly against the live code. Confirm whether exact one-step versus two-step parity is possible with the current tree-side public surface, or whether a deeper shared owner in `PhyloPicMakie.jl` or an escalated tree-side API adjustment is required. Do not edit production code in this task unless a tiny verification-only probe is needed to make the diagnosis concrete. End the task with a short implementation note naming the exact owner boundary the remaining tasks will repair.

### 2. Restore portable dependency configuration and remove workspace-local source overrides

**Type**: CONFIG  
**Output**: `PaleobiologyDB.jl` no longer depends on committed workspace-local `PhyloPicMakie` source paths in package or test project files, and local development remains possible without encoding this workspace layout into the repository.  
**Depends on**: 1

Fix `Project.toml` and `test/Project.toml` first so the branch returns to a portable repository contract before deeper code work continues. If any docs, comments, or local instructions need adjustment so contributors know to use a manifest or local `Pkg.develop` workflow instead of committed `path = ...` overrides, make those changes in the truthful owner repository and keep them concise. Do not replace one workspace-specific path with another. End the task with the touched scope green and the repo portable again.

### 3. Re-center generic anchored taxon rendering ownership in PhyloPicMakie

**Type**: WRITE  
**Output**: `PhyloPicMakie.jl` owns the generic anchor-position render-preparation path, while the PBDB bridge in `PaleobiologyDB.jl` becomes a thin taxonomy-to-image adapter rather than a second generic renderer.  
**Depends on**: 1

Repair the owner boundary across `ext/TaxonomyMakie/PhyloPic/src/_render.jl` and the relevant `PhyloPicMakie.jl` source files. Do not leave PBDB-side copies of generic `on_missing`, placeholder, rotation, mirroring, image filtering, or route-to-anchored-overlay policy behind. If the cleanest fix is a new internal helper in `PhyloPicMakie.jl` that accepts pre-resolved images or taxon-resolved images with anchored positions, add it there and route the PBDB bridge through it. If a proposed change would keep the PBDB bridge as a second generic render-preparation owner, it is not acceptable for this fix pass. End the task with touched tests green in the repository or repositories changed.

### 4. Repair label-aware tree planning ownership and lifecycle

**Type**: WRITE  
**Output**: The label-aware tree overlay planner no longer leaves unmanaged probe plots or overlay artifacts behind, and any support plots it needs participate in a coherent teardown owner.  
**Depends on**: 3

Refactor `ext/TaxonomyMakie/_leaf_overlay.jl`, `ext/TaxonomyMakie/_recipe.jl`, and any adjacent owner files needed so label-aware planning is lifecycle-safe. Hidden probe scatters must not be created without an owning handle and teardown path. If the cleanest implementation moves some projected-anchor or managed-lifecycle responsibility deeper into `PhyloPicMakie.jl`, do that rather than keeping a fragile tree-local workaround. End the task with no remaining tree-owned lifecycle leak in the supported teardown path.

### 5. Unify one-step and explicit two-step tree overlays on the same planning contract

**Type**: MIGRATE  
**Output**: The integrated `show_phylopic = true` path and the explicit tree-overlay flow use the same label-aware or alignment-aware planning contract whenever they claim the same user-facing behavior.  
**Depends on**: 4

Repair `ext/TaxonomyMakie/_augment.jl`, `_recipe.jl`, and any necessary internal tree-overlay entrypoints so the explicit and integrated flows no longer diverge at anchor derivation. Do not accept backend-only sharing as sufficient. If the current explicit surface cannot express the planner inputs needed for true parity, either introduce the minimal tree-side owner adjustment needed inside the currently authorized boundary or stop and escalate that specific public-surface conflict to the user before continuing. End the task only when one-step and two-step behavior are genuinely aligned for the documented policy.

### 6. Add contract-level parity and lifecycle verification

**Type**: TEST  
**Output**: Automated verification fails on the reviewed Tranche 03 failure modes and passes on the repaired implementation, including parity between one-step and explicit tree flows, lifecycle cleanup, and owner-boundary-sensitive behavior.  
**Depends on**: 5

Upgrade `test/taxonomytree_makie.jl` and any touched cross-repo tests so they verify the real Tranche 3 contract instead of internal proxies only. Add checks that would have failed on:
- explicit versus integrated anchor mismatch,
- leaked tree-planning probe plots or overlay artifacts,
- and duplicated generic owner behavior surfacing through the tree path.
Keep the live manual gate explicit too: run `examples/src/taxonomytree.jl` with `set_autocaching!(true)`, exercise both one-step and explicit flows on the same tree, and verify resize or relimit behavior. End the task with the touched verification path green in every changed repository.

### 7. Close the fix pass with truthful docs and end-green verification

**Type**: REVIEW  
**Output**: A truthful end-state result for the Tranche 3 fix pass, covering portability, owner repair, parity, lifecycle cleanup, tests, and any touched docs or example artifacts.  
**Depends on**: 6

Run the required end-green checks honestly. In `PaleobiologyDB.jl`, rerun `julia --project=test test/runtests.jl`, and build docs if any touched docs changed. In `PhyloPicMakie.jl`, rerun the relevant tests if Tasks 3 or 4 changed upstream owner code. Confirm that no committed workspace-local source override remains, that one-step and explicit tree flows now share the real planning contract, and that deleting or recreating the tree overlay does not leave hidden Makie artifacts behind. This task closes the fix pass only if the original tranche goals are now actually satisfied rather than cosmetically approximated.
