# Tasks for Tranche 3: Migrate TaxonomyMakie to shared leaf overlay planning

Parent tranche: Tranche 3
Parent PRD: `01_prd.md`

## Governance

Mandated line-by-line reading applies to all relevant governance documents for both repositories named by this tranche because the migration crosses the `PaleobiologyDB.jl` and `PhyloPicMakie.jl` boundary.

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

Important tranche-3 governance notes:

- `STYLE-vocabulary.md` must be read in both repositories. The files are not identical, so repository-local vocabulary remains controlling within each touched repository. For this tranche, that especially means no further spread of proscribed `tip*` terminology in new owner logic inside `PaleobiologyDB.jl`.
- Tranche 3 is not the approved public-break tranche. Internal code should move toward `leaf*` terminology and shared ownership now, but outward-facing rename cleanup is still reserved for Tranche 4 unless an unexpected conflict forces escalation.
- `STYLE-verification.md` and `STYLE-makie.md` are controlling. Tree-overlay verification must prove real one-step versus two-step parity and visual correctness, not just `@test_nowarn`.

Read-only git and shell commands may be used freely. Mutating git operations such as commit, merge, push, and branch remain the human project owner's responsibility unless the user explicitly instructs otherwise.

## Required revalidation before implementation

- Read Tranche 3 in `02_tranches.md`, the parent PRD in `01_prd.md`, and this tasking file in full.
- Re-read the current `PaleobiologyDB.jl` tree-overlay owners in full:
  - `examples/src/taxonomytree.jl`
  - `ext/TaxonomyMakie/TaxonomyMakie.jl`
  - `ext/TaxonomyMakie/_layout.jl`
  - `ext/TaxonomyMakie/_recipe.jl`
  - `ext/TaxonomyMakie/_augment.jl`
  - `ext/TaxonomyMakie/_phylopic.jl`
  - `ext/TaxonomyMakie/PhyloPic/src/PhyloPic.jl`
  - `ext/TaxonomyMakie/PhyloPic/src/_resolve.jl`
  - `ext/TaxonomyMakie/PhyloPic/src/_render.jl`
  - `test/taxonomytree_makie.jl`
  - `docs/src/guide/taxonomytree_makie.md`
  - `docs/src/api/taxonomytree_makie.md`
- Re-read the Makie and `PhyloPicMakie.jl` primary sources named by the PRD and tranche, including:
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/docs/src/explanations/conversion_pipeline.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/docs/src/explanations/recipes.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/docs/src/reference/generic/space.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/docs/src/explanations/cameras.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/utilities/projection_utils.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/basic_recipes/textlabel.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/CairoMakie/src/scatter.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/test/boundingboxes.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/PhyloPicMakie.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_anchored_overlay.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_render_core.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_augment_api.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/test/test_anchored_overlay.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/test/test_render_core.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/test/test_makie_integration.jl`
- Re-check the current owner split before changing code. At tranche start, the integrated `show_phylopic = true` recipe path still owns a separate renderer in `_phylopic.jl`, while the explicit tree overlay path still delegates through the PBDB bridge into the `PhyloPicMakie` public data-anchor API.
- Re-check the user-authorized disruption boundary. Full internal redesign across both packages is authorized, but Tranche 3 must not silently finalize the public rename set reserved for Tranche 4.
- If the diagnosis no longer matches reality, stop and raise that before changing code.

## Tranche execution rule

This tranche may deeply refactor internals and retire duplicated render ownership where needed, but it must begin and end in a truthful green state for its scope. The goal is owner repair, not symptom patching. By tranche end:

- the one-step `show_phylopic = true` path and the explicit tree overlay flow must share the same underlying overlay machinery,
- `TaxonomyMakie` must no longer own a second renderer for tree glyphs,
- tree-specific semantics must remain in `TaxonomyMakie`,
- general rendering ownership must remain in `PhyloPicMakie`,
- no-glyph tree behavior and approved missing-image behavior must still work,
- and the required tests, docs checks if touched, and rendered example verification must be green.

## Tasks

### 1. Revalidate the tranche-3 baseline and start-green boundary

**Type**: REVIEW  
**Output**: A verified current-state diagnosis for the cross-package migration, including confirmation of the duplicated owner split, the current public `tip*` surface that must not silently spread further, and the exact green gates for this tranche.  
**Depends on**: none

Read the parent PRD, Tranche 3, the active governance set for both repositories, and the tranche's mandated Makie and `PhyloPicMakie` primary sources in full. Reconfirm the current roles of `ext/TaxonomyMakie/_layout.jl`, `_augment.jl`, `_recipe.jl`, `_phylopic.jl`, the vendored PBDB bridge in `ext/TaxonomyMakie/PhyloPic/src/_resolve.jl` and `_render.jl`, plus the current tests, docs, and example. If the tranche would require new public `PhyloPicMakie` owner work beyond the existing internal substrate, stop and raise that before implementation. Do not edit production code in this task unless a tiny verification-only note is needed to make the baseline diagnosable.

### 2. Establish the internal leaf overlay planning owner in TaxonomyMakie

**Type**: WRITE  
**Output**: One internal owner that computes leaf discovery, label-policy interpretation, alignment policy, and anchor instructions for tree overlays without rendering glyphs itself.  
**Depends on**: 1

Create or refactor toward a dedicated internal planning layer in `TaxonomyMakie`, introducing a new internal file if that yields a cleaner deep module boundary. New owner logic must use `leaf*` terminology internally even though the unrevised public surface still carries legacy `tip*` names until Tranche 4. Touch `ext/TaxonomyMakie/TaxonomyMakie.jl`, `_layout.jl`, and `_augment.jl` as needed. The output of this task should be a deep, testable tree-owned contract that can serve both one-step and two-step flows.

### 3. Build the shared tree-to-PhyloPic adapter over the anchored-overlay substrate

**Type**: WRITE  
**Output**: An internal adapter that resolves PBDB taxon names to images and routes tree-planned anchors into the shared `PhyloPicMakie` owner without reintroducing local rendering ownership.  
**Depends on**: 2

Refactor the vendored PhyloPic bridge so tree overlays can consume the same image-resolution logic while targeting the shared anchored-overlay machinery rather than the legacy tree-local scatter path. This likely touches `ext/TaxonomyMakie/PhyloPic/src/_resolve.jl` and `_render.jl`, and may require a small adjacent helper if the cleanest seam is not already present. Keep general rendering ownership in `PhyloPicMakie`; keep tree semantics in `TaxonomyMakie`.

### 4. Migrate the explicit two-step tree overlay flow to the new shared planner

**Type**: MIGRATE  
**Output**: The existing explicit tree overlay path routes through the new leaf planning owner and shared adapter instead of open-coding anchor and render policy inline.  
**Depends on**: 3

Wire the current explicit tree overlay flow in `ext/TaxonomyMakie/_augment.jl` to the shared internal planner and bridge. Preserve the current public entrypoints for now, but do not deepen the legacy `tip*` vocabulary internally. Make the explicit flow the canonical tree-side path that the one-step wrapper will later reuse.

### 5. Replace the integrated `show_phylopic` recipe owner and retire the legacy renderer path

**Type**: MIGRATE  
**Output**: `taxonomytreeplot(...; show_phylopic = true)` uses the same underlying overlay machinery as the explicit tree overlay flow, and `_phylopic.jl` no longer owns rendering behavior.  
**Depends on**: 4

Refactor `ext/TaxonomyMakie/_recipe.jl` so the integrated happy path delegates into the same tree planner plus shared adapter pipeline used by the explicit flow. Remove or drastically reduce the owner role of `ext/TaxonomyMakie/_phylopic.jl`. If any helper survives there, it should be a thin support helper rather than a second renderer owner. Preserve ordinary no-glyph tree plotting behavior and the tranche's required missing-image policies.

### 6. Strengthen tree-overlay verification to prove one-step and two-step parity

**Type**: TEST  
**Output**: Stronger automated and manual verification that the old failure mode is actually prevented and both tree flows now share the same behavioral contract.  
**Depends on**: 5

Upgrade `test/taxonomytree_makie.jl` so it stops relying mainly on `@test_nowarn` for the overlay path. Add coverage that verifies shared-owner behavior, missing-image policy, and size or anchor relationships at the tree layer. Keep the tranche's required manual verification explicit: run `examples/src/taxonomytree.jl`, use `set_autocaching!(true)` for live PBDB and PhyloPic-heavy checks, and compare one-step versus two-step behavior under resize or relimit. If touched docs or examples describe overlay semantics that have changed at the tree layer, update them enough to remain truthful for this tranche.

### 7. Close the tranche with example and end-green verification

**Type**: REVIEW  
**Output**: A truthful end-state result for Tranche 3, including required test results, any touched docs or example checks, and confirmation that `TaxonomyMakie` no longer owns a second renderer.  
**Depends on**: 6

Run the tranche-required green checks in `PaleobiologyDB.jl`, and rerun `PhyloPicMakie.jl` tests if any adapter-facing shared-renderer contract changed during implementation. If any docs were touched, run the relevant docs build. Confirm that the tree example still renders credibly and that one-step and two-step flows now share owner behavior rather than merely both "not erroring." This task closes the tranche only if the real owner boundary is repaired and the required verification artifacts are green.
