# Tasks for Tranche 1: Build PhyloPicMakie Generic Anchored Overlay Foundation

Parent tranche: Tranche 1
Parent PRD: `01_prd.md`

## Governance

Mandated line-by-line reading applies to all relevant governance documents for both repositories touched by this tranche.

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

Important tranche-specific note:

- The earlier PRD text saying `PhyloPicMakie.jl` had no repo-local `STYLE*.md` is now stale. This tranche must treat the repo-local `PhyloPicMakie.jl/STYLE*.md` files as active authorities.
- `STYLE-vocabulary.md` remains controlling even though this tranche is mostly inside `PhyloPicMakie.jl`. Downstream work must avoid vague host-framework phrasing and must not reintroduce proscribed terminology.

Read-only git and shell commands may be used freely. Mutating git operations such as commit, merge, push, and branch remain the human project owner's responsibility unless the user explicitly instructs otherwise.

## Required revalidation before implementation

- Read Tranche 1 in `02_tranches.md` and the parent PRD in `01_prd.md` in full.
- Read the relevant `PhyloPicMakie.jl` code, tests, docs, and package entry points in full:
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/PhyloPicMakie.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_coordinates.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_render_core.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_augment_api.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/test/test_coordinates.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/test/test_render_core.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/test/test_makie_integration.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/README.md`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/docs/src/index.md`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/docs/src/api/rendering.md`
- Read all cited Makie upstream primary sources in full where they constrain this work, especially:
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/docs/src/explanations/conversion_pipeline.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/docs/src/explanations/recipes.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/docs/src/reference/generic/space.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/docs/src/explanations/cameras.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/utilities/projection_utils.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/src/basic_recipes/textlabel.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/CairoMakie/src/scatter.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/Makie/test/boundingboxes.jl`
- Re-check the user-authorized disruption boundary before making deep changes. This tranche may redesign internal rendering ownership inside `PhyloPicMakie.jl`, but it may not hide fake fixes behind new ad hoc geometry hacks.
- Re-check the start-green state honestly. At minimum, rerun the renderer and integration tests and confirm whether the full `PhyloPicMakie.jl` package suite, including `Aqua` and `JET`, finishes cleanly in the current environment. If the tranche diagnosis no longer matches reality, stop and raise that before changing code.

## Tranche execution rule

This tranche is foundational. It may redesign, replace, or deeply refactor internals inside `PhyloPicMakie.jl` where authorized, but it must begin and end in the tranche's required green, policy-compliant state.

Task-level checkpoint rule:

- Each task must end with the repository green for the scope it touched.
- Where a task changes production code, it must add or update verification in the same session.
- The tranche may not rely on later tree-client work for correctness. The generic anchored-overlay foundation must stand on its own inside `PhyloPicMakie.jl`.
- No external breaking changes should be introduced in this tranche unless they are strictly internal or otherwise already permitted by the tranche and explicitly documented.

## Tasks

### 1. Revalidate the Baseline and Confirm Start-Green Status

**Type**: REVIEW
**Output**: A verified start-state diagnosis for Tranche 1, including confirmed active authorities, confirmed current renderer ownership, and a truthful green-baseline result or explicit blocker report.
**Depends on**: none

Read the tranche and parent PRD in full, then re-read the active governance files for both repositories and the Makie upstream sources that constrain this work. Re-check the live `PhyloPicMakie.jl` owner modules in `src/PhyloPicMakie.jl`, `src/_coordinates.jl`, `src/_render_core.jl`, and `src/_augment_api.jl`, along with `test/test_render_core.jl`, `test/test_makie_integration.jl`, `README.md`, and `docs/src/api/rendering.md`. Rerun the current verification path, including the full `PhyloPicMakie.jl` package tests if possible, and explicitly determine whether `Aqua` and `JET` complete green in the current environment or require a separate diagnosis note. Do not edit production code in this task unless a tiny verification-only adjustment is needed to make the start-green state diagnosable. This task must leave the repository unchanged or green for any touched verification-only files.

---

### 2. Introduce the Internal Anchor Model and Projection Helper Layer

**Type**: WRITE
**Output**: A new internal anchor and projection substrate in `PhyloPicMakie.jl` that can represent explicit data anchors and projected or screen-derived anchors, with focused unit coverage for supported and degenerate cases.
**Depends on**: 1

Create the internal owner layer that Tranche 1 is really about. Touch `src/PhyloPicMakie.jl`, `src/_coordinates.jl`, and add a new internal source file if doing so produces a cleaner deep-module boundary than overloading the existing coordinate helpers. Use Makie’s `register_projected_positions!` and related projection utilities as the primary design reference, not ad hoc camera reconstruction. The new internal contract should make it possible for higher-level callers to provide either plain data anchors or already-resolved projected anchors without leaking Makie projection mechanics into clients. Add or extend tests in `test/test_coordinates.jl` or a new focused test file to cover valid anchor specifications, invalid anchor specifications, and degenerate projection conditions. End the task with touched-scope tests green and no regression to the existing renderer APIs.

---

### 3. Build a Render-Aware Projection Regression Harness

**Type**: TEST
**Output**: Integration tests and reusable fixtures that can materialize figures, trigger resize or relimit changes, and assert anchor stability and visible extents for projected-anchor cases.
**Depends on**: 2

Strengthen the verification layer before rewriting the renderer path. Touch `test/test_makie_integration.jl` and add a new integration test file if needed to keep the suite readable. Follow the existing CairoMakie testing pattern but go beyond smoke tests: add checks that would fail for the historical size-collapse or misplaced-anchor class of bugs, and cover at least one rendered-object or projected-anchor case rather than only pure data-space coordinates. Use the current `_axis_scale_correction_obs` smoke as a starting point, but replace or extend it with more direct behavioral checks. End the task with the updated test slice green and with a clear path for later tasks to use the new harness rather than inventing one-off assertions.

---

### 4. Add the Low-Level Projected-Anchor Rendering Path

**Type**: WRITE
**Output**: A generic low-level rendering path in `PhyloPicMakie.jl` that can render pre-resolved image matrices from projected-anchor instructions while preserving aspect, placement, rotation, mirroring, and `on_missing` behavior.
**Depends on**: 3

Extend `src/_render_core.jl` and any internal helper files established in Task 2 so projected-anchor instructions become first-class inputs to the renderer rather than forcing clients to reverse-engineer pixel or data conversions. Preserve the existing generic responsibilities of `augment_phylopic!`: pre-resolved images in, Makie overlay out, with missing-image policy, rotation, and aspect handling owned here. Keep the new logic general-purpose and client-agnostic. Do not let tree semantics or PBDB-specific concepts leak into this layer. Add or update render-core tests in `test/test_render_core.jl` so the new path is verified alongside the existing data-anchor path. End the task with the renderer tests and integration tests green for the touched scope.

---

### 5. Migrate Existing Public Overlay APIs onto the New Foundation

**Type**: MIGRATE
**Output**: Existing public `augment_phylopic!` and `augment_phylopic_ranges!` behavior preserved, but internally routed through the new anchored-overlay substrate instead of a separate legacy path.
**Depends on**: 4

Migrate the current public PhyloPic-native overlay APIs in `src/_augment_api.jl` so they use the new foundation established in Tasks 2 through 4. Preserve current explicit-coordinate and range-based calling patterns unless a strictly internal re-route is enough. Touch `src/_augment_api.jl`, `src/_render_core.jl`, and any new internal helper files. Keep `PhyloPicMakie.jl` independent of `PaleobiologyDB.jl` and avoid introducing tree-specific abstractions. Update any relevant tests in `test/test_render_core.jl` and `test/test_makie_integration.jl` so both the old-style explicit data APIs and the new underlying substrate are covered. End the task with the package green for the touched verification path and with no duplicated rendering owner left behind in the public overlay entry points.

---

### 6. Finalize Tranche-1 Package Docs and End-Green Verification

**Type**: WRITE
**Output**: The tranche-1 foundation is documented in `PhyloPicMakie.jl`, and the tranche ends in a verified green state for code, docs, and required tests.
**Depends on**: 5

Update the package-facing docs to describe the new generic anchored-overlay foundation without stepping into the standalone examples work reserved for Tranche 2. Touch `README.md`, `docs/src/index.md`, and `docs/src/api/rendering.md` as needed so the public and semi-public layering is truthful and aligned with the final code. Run the tranche-required verification at end state: the renderer and integration tests must pass, and the full `PhyloPicMakie.jl` package test path should be rerun so the tranche closes from a known green baseline. If touched docs require it, build `PhyloPicMakie.jl` docs as well. This task is the tranche close-out checkpoint and must leave the repository in the tranche’s required green, policy-compliant state.

---
