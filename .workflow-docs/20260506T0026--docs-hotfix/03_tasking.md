# Tasks for Tranche 01: Fix CI docs failure and local documentation warnings

Parent tranche: Tranche 01. No on-disk `02_tranche-01.md` was present when this tasking was prepared; this task file is derived from the user-authored hotfix plan in chat and revalidated against the current repository state on 2026-05-06.
Parent PRD: `none on disk; user-authored hotfix plan in chat`

## Settled user decisions and environment baseline

- This is a single-tranche docs hotfix.
- `PBDBMakie` is the current extension name. Do not restore, alias, or otherwise reintroduce `TaxonomyMakie`.
- Docs must adapt to the current public API. Do not broaden the `PaleobiologyDB.PBDBMakie` API surface merely to satisfy Documenter.
- The internal vendored `PhyloPic` submodule remains an implementation detail of `PBDBMakieExt`. It is not authorized to become a new public binding or export as part of this hotfix.
- Keep the existing docs and test environment structure intact: use `julia --project=docs docs/make.jl` and the existing `docs/Project.toml` and `docs/Manifest.toml`. No dependency, manifest, or path-override changes are authorized.
- Keep `checkdocs = :exports` and the existing docs build entrypoint intact. Do not hide failures by weakening Documenter checks, changing `warnonly`, or deleting legitimate exported API docs blocks.
- No `codebases-and-documentation` directory was present in or near this workspace during tasking. No additional local upstream checkouts were available beyond the installed Julia and Documenter packages.

## Governance

Downstream implementation must read the following line by line before making substantial edits and must pass the same obligations forward in any further handoff:

- `AGENTS.md`
- `CONTRIBUTING.md`
- `STYLE-agent-handoffs.md`
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

The repo-local `STYLE*.md` files were checked against the bundled `development-policies` references and were identical. The bundled governance depot did not contain a `CONTRIBUTING.md`, so the repo-local `CONTRIBUTING.md` is the controlling contribution authority for this run.

Read-only git and shell commands may be used freely. Mutating git operations such as commit, merge, push, branch creation, reset, and rebase remain the human project owner's responsibility unless the user explicitly instructs otherwise.

## Primary-goal lock

### Lock 1: CI doctest owner drift

- The work is not complete if the docs CI workflow still imports or configures the retired `PaleobiologyDB.TaxonomyMakie` module name.
- Direct red-state repro: `.github/workflows/CI.yml` currently uses `using PaleobiologyDB.TaxonomyMakie` and `DocMeta.setdocmeta!(PaleobiologyDB.TaxonomyMakie, ...)`, which matches the reported CI failure `UndefVarError: TaxonomyMakie not defined in PaleobiologyDB`.
- Closed by Tasks 1 and 3.
- Failing proof artifact for the old implementation or fake-fix shape: the doctest command from Task 1 fails when run with `TaxonomyMakie`, but exits 0 when run with `PaleobiologyDB.PBDBMakie`.

### Lock 2: Extension method docstrings omitted from the docs build

- The work is not complete if `julia --project=docs docs/make.jl` still emits `no docs found` warnings for extension-owned PBDBMakie methods whose docstrings already exist on concrete methods, including `taxonomytreeplot`, `set_rank_axis_ticks!`, `leaf_positions`, and `augment_leaf_phylopic!`.
- Direct red-state repro: the 2026-05-06 docs build warned that those bindings were missing from `docs/src/api/taxonomytree_makie.md`, even though the concrete methods and docstrings live under `ext/PBDBMakieExt`.
- Closed by Tasks 1 and 3.
- Failing proof artifact for the old implementation or fake-fix shape: rerunning `julia --project=docs docs/make.jl` before Task 1 produces those warnings because the loaded extension module is absent from the `makedocs(modules = ...)` list.

### Lock 3: Public wrapper docstrings missing on exported PBDBMakie bindings

- The work is not complete if the docs build still emits `no docs found` warnings, or `@ref` failures that depend on those warnings, for the exported PhyloPic wrapper bindings `acquire_phylopic`, `augment_phylopic`, `augment_phylopic!`, `augment_phylopic_ranges`, `augment_phylopic_ranges!`, `phylopic_images_dataframe`, `phylopic_node`, `phylopic_images`, `pbdb_phylopic_grid`, and `pbdb_phylopic_grid!`.
- Direct red-state repro: the 2026-05-06 docs build warned about those names in `docs/src/api/phylopic_acquire.md` and `docs/src/api/phylopic_makie.md`, and also failed to resolve `[`augment_phylopic`](@ref)` because the public wrapper binding itself had no attached docstring.
- Closed by Tasks 2 and 3.
- Failing proof artifact for the old implementation or fake-fix shape: rerunning `julia --project=docs docs/make.jl` before Task 2 shows that the docstrings exist on internal `PhyloPic.*` functions but are not attached to the exported `PaleobiologyDB.PBDBMakie.*` wrappers.

### Lock 4: Docs page claims a non-public internal binding

- The work is not complete if `docs/src/api/phylopic_makie.md` still asks Documenter for `PhyloPic` as if it were a public `PaleobiologyDB.PBDBMakie` binding, or if the implementation silences that warning by making `PhyloPic` public.
- Direct red-state repro: the 2026-05-06 docs build warned `undefined binding 'PaleobiologyDB.PBDBMakie.PhyloPic'` for the `@docs PhyloPic` block.
- Closed by Task 3.
- Failing proof artifact for the old implementation or fake-fix shape: the current docs page triggers the undefined-binding warning; a fake fix would add a new public binding in `src/PBDBMakie.jl` instead of correcting the page to document only the supported public surface.

### Lock 5: Unqualified cross-reference points at the wrong owner

- The work is not complete if `docs/src/api/taxonomytree_makie.md` still contains an unqualified `[TaxonomyTree](@ref)` that Documenter cannot resolve from the `PaleobiologyDB.PBDBMakie` current-module context.
- Direct red-state repro: the 2026-05-06 docs build warned that fallback resolution to `PaleobiologyDB.Taxonomy.TaxonomyTree` is only allowed for fully qualified names.
- Closed by Task 3.
- Failing proof artifact for the old implementation or fake-fix shape: rerunning `julia --project=docs docs/make.jl` before Task 3 reproduces the `Cannot resolve @ref` warning for `TaxonomyTree`.

### Lock 6: Public API compatibility must survive the hotfix

- The work is not complete if the hotfix narrows, renames, removes, or hides the current exported `PaleobiologyDB.PBDBMakie` API surface, or if it deletes legitimate exported-API `@docs` blocks to make the docs build look green.
- Direct red-state repro or fake-fix shape: warnings can be silenced dishonestly by removing exported names from docs coverage, weakening Documenter checks, or creating a new public `PhyloPic` binding instead of fixing owner-level doc attachment and truthful docs text.
- Closed by Tasks 2 and 3.
- Failing proof artifact for the old implementation or fake-fix shape: compare `src/PBDBMakie.jl` before and after the hotfix, confirm that the export list is unchanged, and confirm that `checkdocs = :exports` still passes cleanly with the same exported wrappers documented.

## Handoff packet

- Active authorities: `AGENTS.md`; repo-local `CONTRIBUTING.md`; repo-local `STYLE-agent-handoffs.md`, `STYLE-architecture.md`, `STYLE-docs.md`, `STYLE-git.md`, `STYLE-julia.md`, `STYLE-makie.md`, `STYLE-upstream-contracts.md`, `STYLE-verification.md`, `STYLE-vocabulary.md`, `STYLE-workflow-docs.md`, `STYLE-writing.md`; bundled `development-policies` skill as baseline authority; this task file.
- Parent documents: the user-authored hotfix plan in chat; no on-disk PRD or tranche file existed for this directory at tasking time.
- Settled decisions and non-negotiables: keep `PBDBMakie` as the extension name; fix docs to match the current public API; do not expose internal `PhyloPic`; do not weaken Documenter checks or change dependency baselines.
- Authorization boundary: edits are authorized only in `.github/workflows/CI.yml`, `docs/make.jl`, `ext/PBDBMakieExt/PBDBMakieExt.jl`, `docs/src/api/phylopic_makie.md`, and `docs/src/api/taxonomytree_makie.md` unless a stop condition is triggered.
- Current-state diagnosis: CI still points at the retired `TaxonomyMakie` name; `docs/make.jl` loads `PBDBMakie` but does not register the loaded `PBDBMakieExt` module with Documenter; exported wrappers in `PBDBMakieExt.jl` delegate to internal `PhyloPic.*` implementations without attaching the existing docstrings to the exported public bindings; `phylopic_makie.md` documents an inaccessible internal module binding; `taxonomytree_makie.md` uses an unqualified `TaxonomyTree` cross-reference from the wrong current-module context.
- Primary-goal lock: Locks 1 through 6 above.
- Direct red-state repros:
  - `julia --project=docs docs/make.jl`
  - `julia --project=docs -e 'using Documenter: DocMeta, doctest; using PaleobiologyDB; using CairoMakie; import PhyloPicMakie; using PaleobiologyDB.PBDBMakie; DocMeta.setdocmeta!(PaleobiologyDB, :DocTestSetup, :(using PaleobiologyDB); recursive=true); DocMeta.setdocmeta!(PaleobiologyDB.PBDBMakie, :DocTestSetup, :(using PaleobiologyDB; using CairoMakie; import PhyloPicMakie; using PaleobiologyDB.PBDBMakie); recursive=true); doctest(PaleobiologyDB)'`
  - `julia --project=docs -e 'using PaleobiologyDB; using CairoMakie; using PaleobiologyDB.PBDBMakie; ext = Base.get_extension(PaleobiologyDB, :PBDBMakieExt); println(isnothing(ext) ? "EXTENSION_NOT_LOADED" : nameof(ext))'`
- Owner and invariant under repair: the CI doctest block owns the extension module name used during docs tests; the `makedocs(modules = ...)` list owns whether Documenter can audit extension-owned method docstrings; `PBDBMakieExt` owns the concrete public wrapper implementations and must attach docstrings at the public binding boundary; the docs markdown pages own truthful references to the supported public API and must not claim non-public bindings.
- Exact files or surfaces in scope: `.github/workflows/CI.yml`, `docs/make.jl`, `ext/PBDBMakieExt/PBDBMakieExt.jl`, `docs/src/api/phylopic_makie.md`, `docs/src/api/taxonomytree_makie.md`.
- Exact files or surfaces out of scope: `src/PBDBMakie.jl`; `docs/src/api/phylopic_acquire.md`; other docs pages; dependency manifests; package APIs beyond the enumerated docs and config hotfix surfaces.
- Required upstream primary sources already read during tasking:
  - Julia `Base.get_extension(parent::Module, extension::Symbol)` docstring, as printed from the local Julia installation.
  - Documenter `makedocs` docstring and keyword documentation from the local installed package at `/home/jeetsukumaran/.julia/packages/Documenter/AXNMp/src/Documenter.jl`, especially the `modules`, `checkdocs`, and `warnonly` keyword contracts.
- Green-state gates:
  - The doctest command using `PaleobiologyDB.PBDBMakie` exits 0.
  - `julia --project=docs docs/make.jl` completes without the currently observed stale-name, `no docs found`, undefined-binding, or `Cannot resolve @ref` warnings tied to Locks 1 through 5.
  - `src/PBDBMakie.jl` retains the same exported public wrapper list and does not add a public `PhyloPic` binding.
- Stop conditions:
  - If `Base.get_extension(PaleobiologyDB, :PBDBMakieExt)` returns `nothing` after `using CairoMakie; using PaleobiologyDB.PBDBMakie`, stop and re-diagnose before editing.
  - If a clean fix appears to require adding a new public binding, changing exported names, weakening Documenter checks, or touching files outside the authorized scope, stop and escalate.
  - If new warnings appear outside the known red-state set after Task 1 or Task 2, stop and revalidate the diagnosis before continuing.
  - If on-disk parent workflow documents for this same hotfix appear and conflict with this task file, stop and reconcile them before implementation.

## Required revalidation before implementation

- Read this task file and the user-authored hotfix plan in full.
- Re-read `.github/workflows/CI.yml`, `docs/make.jl`, `ext/PBDBMakieExt/PBDBMakieExt.jl`, `docs/src/api/phylopic_makie.md`, `docs/src/api/taxonomytree_makie.md`, and `src/PBDBMakie.jl` in full.
- Re-run the docs build and doctest commands listed in the handoff packet before making code changes so the implementing agent verifies the same red-state on the current checkout.
- Re-check the local upstream contract sources already identified above if the implementation plan would diverge from this tasking's chosen repair.
- If the red-state no longer matches the diagnosis captured here, stop and rewrite the workflow document instead of applying a stale fix.

## Tranche execution rule

This hotfix may repair the owning docs and extension surfaces directly, but it must begin and end in a policy-compliant green state for the docs workflow.

When the tranche is complete:

- the stale `TaxonomyMakie` CI references must no longer exist
- the docs build must no longer exclude the loaded `PBDBMakieExt` owner
- the exported `PBDBMakie` wrappers must no longer exist as undocumented public bindings
- the docs pages must no longer claim a non-public `PhyloPic` binding or an unqualified `TaxonomyTree` reference from the wrong module context

Forbidden workaround shapes:

- reintroducing a `TaxonomyMakie` alias or compatibility shim
- weakening `checkdocs`, changing `warnonly`, or otherwise hiding warnings
- deleting legitimate exported-API `@docs` blocks from `phylopic_acquire.md` or the API pages to make the warnings disappear
- adding a new public `PhyloPic` binding or export solely to satisfy the current docs page
- moving documentation truth into tests, YAML policing, or source-text assertions instead of repairing the actual owner surfaces

Docs must be brought into truth with the current API. Public API changes are not authorized for this hotfix unless the user explicitly approves reopening that boundary.

## Non-negotiable execution rules

- Do not modify `src/PBDBMakie.jl`.
- Do not change dependency manifests, package dependencies, or path overrides.
- Do not remove or rename exported PBDBMakie functions.
- Do not solve public-doc coverage failures by deleting the public docs blocks that are supposed to cover those exports.
- Do not copy-paste new wrapper docstrings when the canonical docstrings already exist on `PhyloPic.*`; forward the existing owner text instead.
- Do not broaden the PBDBMakie API to expose internal implementation details.

## Concrete anti-patterns or removal targets

- Retired `TaxonomyMakie` references in `.github/workflows/CI.yml`.
- A `makedocs(modules = ...)` list that omits the loaded `PBDBMakieExt` module.
- Wrapper functions in `ext/PBDBMakieExt/PBDBMakieExt.jl` that delegate to `PhyloPic.*` but leave the public exported binding undocumented.
- The `@docs PhyloPic` block in `docs/src/api/phylopic_makie.md`.
- The unqualified `[TaxonomyTree](@ref)` cross-reference in `docs/src/api/taxonomytree_makie.md`.
- Any fake fix that deletes `@docs acquire_phylopic`, `@docs phylopic_images_dataframe`, `@docs phylopic_node`, `@docs phylopic_images`, `@docs augment_phylopic[!]`, `@docs augment_phylopic_ranges[!]`, `@docs pbdb_phylopic_grid[!]`, or `@docs taxonomytreeplot` blocks instead of making those public bindings documentable.

## Failure-oriented verification

Use these exact checks. The first two are required for final green state, and at least one must be rerun after each task where noted below.

- `julia --project=docs -e 'using Documenter: DocMeta, doctest; using PaleobiologyDB; using CairoMakie; import PhyloPicMakie; using PaleobiologyDB.PBDBMakie; DocMeta.setdocmeta!(PaleobiologyDB, :DocTestSetup, :(using PaleobiologyDB); recursive=true); DocMeta.setdocmeta!(PaleobiologyDB.PBDBMakie, :DocTestSetup, :(using PaleobiologyDB; using CairoMakie; import PhyloPicMakie; using PaleobiologyDB.PBDBMakie); recursive=true); doctest(PaleobiologyDB)'`
- `julia --project=docs docs/make.jl`
- `julia --project=docs -e 'using PaleobiologyDB; using CairoMakie; using PaleobiologyDB.PBDBMakie; ext = Base.get_extension(PaleobiologyDB, :PBDBMakieExt); @assert !isnothing(ext); println(nameof(ext))'`

The following red-state messages must disappear by tranche end:

- `UndefVarError: TaxonomyMakie not defined in PaleobiologyDB`
- `no docs found for 'taxonomytreeplot'`
- `no docs found for 'set_rank_axis_ticks!'`
- `no docs found for 'leaf_positions'`
- `no docs found for 'augment_leaf_phylopic!'`
- `no docs found for 'acquire_phylopic'`
- `no docs found for 'phylopic_images_dataframe'`
- `no docs found for 'phylopic_node'`
- `no docs found for 'phylopic_images'`
- `no docs found for 'augment_phylopic!'`
- `no docs found for 'augment_phylopic'`
- `no docs found for 'augment_phylopic_ranges!'`
- `no docs found for 'augment_phylopic_ranges'`
- `no docs found for 'pbdb_phylopic_grid!'`
- `no docs found for 'pbdb_phylopic_grid'`
- `undefined binding 'PaleobiologyDB.PBDBMakie.PhyloPic'`
- `Cannot resolve @ref for md"[`TaxonomyTree`](@ref)"`
- `Cannot resolve @ref for md"[`augment_phylopic`](@ref)"`
- `Cannot resolve @ref for md"[`taxonomytreeplot`](@ref)"`

Positive outcome checks that must also be true at tranche end:

- `docs/build` is regenerated successfully by `julia --project=docs docs/make.jl`.
- `docs/src/api/phylopic_makie.md` still documents the exported rendering functions, but now summarizes the internal `PhyloPic` implementation detail in prose rather than via a broken `@docs` block.
- `docs/src/api/taxonomytree_makie.md` still documents the PBDBMakie API and now cross-references `PaleobiologyDB.Taxonomy.TaxonomyTree` explicitly.
- `src/PBDBMakie.jl` remains unchanged, proving the hotfix repaired docs/config owners rather than broadening the API.

## Tasks

### 1. Align the CI doctest block and docs builder with the loaded extension owner

**Type**: CONFIG
**Output**: The docs CI doctest snippet uses `PaleobiologyDB.PBDBMakie`, and `docs/make.jl` resolves and registers the loaded `PBDBMakieExt` module in `makedocs(modules = ...)`.
**Depends on**: none
**Positive contract**: The stale `TaxonomyMakie` module name is removed from the CI doctest block, the docs builder explicitly includes the loaded extension module, and Documenter can see the concrete extension-owned method docstrings for `taxonomytreeplot`, `set_rank_axis_ticks!`, `leaf_positions`, and `augment_leaf_phylopic!`.
**Negative contract**: Do not add a compatibility alias, do not weaken Documenter checks, and do not delete docs blocks to hide the missing coverage problem.
**Files**: `.github/workflows/CI.yml`, `docs/make.jl`
**Out of scope**: `src/PBDBMakie.jl`, `ext/PBDBMakieExt/PBDBMakieExt.jl`, `docs/src/api/phylopic_makie.md`, `docs/src/api/taxonomytree_makie.md`, `docs/src/api/phylopic_acquire.md`
**Verification**:
- Run `julia --project=docs -e 'using Documenter: DocMeta, doctest; using PaleobiologyDB; using CairoMakie; import PhyloPicMakie; using PaleobiologyDB.PBDBMakie; DocMeta.setdocmeta!(PaleobiologyDB, :DocTestSetup, :(using PaleobiologyDB); recursive=true); DocMeta.setdocmeta!(PaleobiologyDB.PBDBMakie, :DocTestSetup, :(using PaleobiologyDB; using CairoMakie; import PhyloPicMakie; using PaleobiologyDB.PBDBMakie); recursive=true); doctest(PaleobiologyDB)'` and confirm exit 0.
- Run `julia --project=docs -e 'using PaleobiologyDB; using CairoMakie; using PaleobiologyDB.PBDBMakie; ext = Base.get_extension(PaleobiologyDB, :PBDBMakieExt); @assert !isnothing(ext); println(nameof(ext))'` and confirm it prints `PBDBMakieExt`.
- Run `julia --project=docs docs/make.jl` and confirm that the previous `no docs found` warnings for `taxonomytreeplot`, `set_rank_axis_ticks!`, `leaf_positions`, and `augment_leaf_phylopic!` are gone. It is acceptable at this checkpoint for wrapper-binding and markdown-truth warnings covered by Tasks 2 and 3 to remain.

In `.github/workflows/CI.yml`, replace the stale `PaleobiologyDB.TaxonomyMakie` import and `DocMeta.setdocmeta!` target with `PaleobiologyDB.PBDBMakie`. In `docs/make.jl`, keep the current backend-triggered extension-loading sequence, then bind the loaded extension with `Base.get_extension(PaleobiologyDB, :PBDBMakieExt)` immediately after `using PaleobiologyDB.PBDBMakie`, assert or stop if it is `nothing`, and add that module object to the `makedocs(modules = ...)` vector. This design is constrained by the verified upstream contracts: `Base.get_extension` is the Julia API for retrieving a loaded package extension, and Documenter only audits docstrings from the modules explicitly named in `makedocs(modules = ...)`.

### 2. Attach existing PhyloPic docstrings to the exported PBDBMakie wrapper bindings

**Type**: WRITE
**Output**: The exported PhyloPic wrapper bindings in `PaleobiologyDB.PBDBMakie` remain thin delegators, but each now has its canonical docstring attached at the public binding boundary.
**Depends on**: 1
**Positive contract**: `acquire_phylopic`, `augment_phylopic`, `augment_phylopic!`, `augment_phylopic_ranges`, `augment_phylopic_ranges!`, `phylopic_images_dataframe`, `phylopic_node`, `phylopic_images`, `pbdb_phylopic_grid`, and `pbdb_phylopic_grid!` all become documentable as exported `PaleobiologyDB.PBDBMakie` bindings without changing their runtime behavior or their owner module.
**Negative contract**: Do not delete `@docs` blocks from `docs/src/api/phylopic_acquire.md`, do not write divergent duplicate docstrings by hand, do not move these functions into a second owner, and do not change the exported API names or signatures.
**Files**: `ext/PBDBMakieExt/PBDBMakieExt.jl`
**Out of scope**: `.github/workflows/CI.yml`, `docs/make.jl`, `src/PBDBMakie.jl`, `docs/src/api/phylopic_acquire.md`, `docs/src/api/phylopic_makie.md`, `docs/src/api/taxonomytree_makie.md`
**Verification**:
- Run `julia --project=docs docs/make.jl`.
- Confirm that the `no docs found` warnings disappear for `acquire_phylopic`, `phylopic_images_dataframe`, `phylopic_node`, `phylopic_images`, `augment_phylopic!`, `augment_phylopic`, `augment_phylopic_ranges!`, `augment_phylopic_ranges`, `pbdb_phylopic_grid!`, and `pbdb_phylopic_grid`.
- Confirm that the `Cannot resolve @ref` warning for `[`augment_phylopic`](@ref)` in `docs/src/api/phylopic_acquire.md` disappears.
- It is acceptable at this checkpoint for the `undefined binding 'PaleobiologyDB.PBDBMakie.PhyloPic'` and unqualified `TaxonomyTree` warnings covered by Task 3 to remain.

In `ext/PBDBMakieExt/PBDBMakieExt.jl`, keep each wrapper as a thin delegator to `PhyloPic.*`, but prepend a doc-forwarding form that attaches the existing canonical docstring from the internal implementation to the exported wrapper binding itself. Use the `PhyloPic` docstrings already defined in `ext/PBDBMakieExt/PhyloPic/src/_phylopic_core.jl`, `ext/PBDBMakieExt/PhyloPic/src/_render.jl`, and `ext/PBDBMakieExt/PhyloPic/src/_pbdb_phylopic_grid.jl`; do not create a second textual source of truth. This repair is required because `checkdocs = :exports` audits the exported `PaleobiologyDB.PBDBMakie` names, not merely the internal `PhyloPic.*` implementations that happen to perform the work.

### 3. Bring the PBDBMakie docs pages into truth with the current public API and verify the full hotfix

**Type**: WRITE
**Output**: The PBDBMakie API pages describe only bindings that truly exist on the current public surface, and the docs build and doctest flow both pass without the current known failures.
**Depends on**: 1, 2
**Positive contract**: `docs/src/api/phylopic_makie.md` no longer requests an inaccessible `PhyloPic` binding and instead summarizes the internal implementation detail in prose; `docs/src/api/taxonomytree_makie.md` uses a fully qualified `TaxonomyTree` reference target; the final docs build is free of the stale-name, missing-doc, undefined-binding, and `@ref` warnings captured in Locks 1 through 5.
**Negative contract**: Do not add or export a public `PhyloPic` binding, do not change `src/PBDBMakie.jl`, do not delete legitimate exported-function `@docs` blocks from `phylopic_acquire.md` or the API pages, and do not weaken verification requirements to claim success.
**Files**: `docs/src/api/phylopic_makie.md`, `docs/src/api/taxonomytree_makie.md`
**Out of scope**: `src/PBDBMakie.jl`, `docs/src/api/phylopic_acquire.md`, `.github/workflows/CI.yml`, `docs/make.jl`, `ext/PBDBMakieExt/PBDBMakieExt.jl`
**Verification**:
- Run `julia --project=docs docs/make.jl` and confirm that none of the red-state warnings listed in the failure-oriented verification section remain.
- Run `julia --project=docs -e 'using Documenter: DocMeta, doctest; using PaleobiologyDB; using CairoMakie; import PhyloPicMakie; using PaleobiologyDB.PBDBMakie; DocMeta.setdocmeta!(PaleobiologyDB, :DocTestSetup, :(using PaleobiologyDB); recursive=true); DocMeta.setdocmeta!(PaleobiologyDB.PBDBMakie, :DocTestSetup, :(using PaleobiologyDB; using CairoMakie; import PhyloPicMakie; using PaleobiologyDB.PBDBMakie); recursive=true); doctest(PaleobiologyDB)'` and confirm exit 0.
- Inspect `src/PBDBMakie.jl` and confirm that no new public `PhyloPic` binding or export was added.

In `docs/src/api/phylopic_makie.md`, replace the broken `@docs PhyloPic` block with a short prose summary derived from the existing module docstring in `ext/PBDBMakieExt/PhyloPic/src/PhyloPic.jl`, explicitly describing that submodule as an internal implementation detail that supplies the PBDB-to-PhyloPic data bridge and Makie rendering wrappers behind the exported PBDBMakie functions. Keep the exported function `@docs` blocks intact. In `docs/src/api/taxonomytree_makie.md`, replace the bare `[TaxonomyTree](@ref)` with the fully qualified `[`TaxonomyTree`](@ref PaleobiologyDB.Taxonomy.TaxonomyTree)` target because the current module is `PaleobiologyDB.PBDBMakie` and the verified red-state warning shows that Documenter only permits the fallback for fully qualified names in this case. End by rerunning the full docs build and doctest flow so the tranche closes on direct contract-level evidence rather than on source inspection alone.
