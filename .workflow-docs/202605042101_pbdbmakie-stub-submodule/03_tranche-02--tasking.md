# Tasks for Tranche 2: add pre-Makie submodule verification and confirm full green state

Parent tranche: Tranche 2
Parent PRD: `01_prd.md`

## Settled user decisions and environment baseline

- No external breaking changes are authorized. The canonical user-facing import form remains `using PaleobiologyDB.PBDBMakie`.
- `PBDBMakie` must remain a submodule binding of `PaleobiologyDB`, not a separately registered package dependency, compatibility shim, or fallback module.
- `PBDBMakie` must not be exported from `PaleobiologyDB`. To satisfy the PRD requirement that `names(PaleobiologyDB)` includes `:PBDBMakie`, use `public PBDBMakie` in `src/PaleobiologyDB.jl` rather than `export PBDBMakie`.
- The Tranche 1 architecture is settled and must not be reopened here. `src/PBDBMakie.jl` remains the unconditional declaration owner, `ext/PBDBMakieExt/PBDBMakieExt.jl` remains the Makie implementation owner, and the `_PhyloPicBridge` design from `01_prd.md` and `04_tranche-01--remediation.md` remains in force.
- The pre-Makie contract boundary is public-runtime behavior, not helper-level proof. Before Makie loads, `PaleobiologyDB.PBDBMakie` must exist as a module, its declared API must be visible to tooling, `Base.get_extension(PaleobiologyDB, :PBDBMakieExt)` must remain `nothing`, and representative public calls must throw `MethodError`.
- The accepted limitation from the PRD remains settled: `TaxonomyTreePlot` is extension-only and must not appear as a pre-Makie declaration in the unconditional submodule.
- The root package environment remains manifest-free. The tracked secondary environments are `test/`, `docs/`, and `examples/`. Secondary manifest updates must be produced by Pkg operations, not manual manifest editing.
- README example commands are part of the user-facing truth boundary for this tranche. Do not weaken the examples gate by deleting claims or changing docs prose instead of repairing the environment metadata.
- The current revalidated baseline is mixed: `julia --project=test test/runtests.jl` passes, `julia --project=test test/runaqua.jl` passes, `isdefined(PaleobiologyDB, :PBDBMakie)` is already `true`, plain `names(PaleobiologyDB)` does not yet include `:PBDBMakie`, `examples/Manifest.toml` still records `PBDBMakie = "Makie"`, and `docs/Manifest.toml` still records `TaxonomyMakie = "Makie"`.

## Governance

All tasks must comply with:

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

Read each document line by line before beginning. Do not summarize or substitute recollection for the source text.

Parent workflow documents that must also be read in full before implementation:

- `01_prd.md`
- `02_tranches.md`
- `04_tranche-01--remediation.md`

Required upstream primary sources:

- Pkg.jl extension documentation at `https://pkgdocs.julialang.org/stable/creating-packages/#Conditional-loading-of-code-in-packages-(Extensions)` to confirm the extension naming and loading contract that the secondary manifests must encode.
- Julia `base/loading.jl` to confirm that stale extension names in tracked manifests produce extension-load callback attempts against retired extension module names.
- `Makie.jl/Makie/src/recipes.jl` is already a settled upstream source for the Tranche 1 owner boundary. Re-read it only if implementation pressure suggests touching `src/PBDBMakie.jl` or `ext/PBDBMakieExt/`; that would be a stop condition for this tranche because those owners are out of scope here.

No repo-local `CLAUDE.md` was found during revalidation. Do not assume one exists.

Read-only git and shell commands may be used freely. Mutating git operations such as commit, merge, push, and branch remain the human project owner's responsibility unless explicitly instructed otherwise.

## Primary-goal lock

### L-1. Public submodule visibility

- The work is not complete if `PBDBMakie` is only `isdefined` but still absent from plain `names(PaleobiologyDB)`, or if a pre-Makie tooling pass cannot see the declared submodule API.
- Direct red-state repro: `julia --project=. -e 'using PaleobiologyDB; println(isdefined(PaleobiologyDB, :PBDBMakie)); println(:PBDBMakie in names(PaleobiologyDB))'` currently prints `true` and then `false`.
- Tasks that close it: 1 and 2.
- Verification artifact: `test/pbdbmakie_stub.jl` plus `julia --project=test test/runtests.jl`. The old implementation fails the `names(PaleobiologyDB)` assertion even though the module binding exists.

### L-2. Pre-Makie declaration and dispatch contract

- The work is not complete if the repository still lacks a no-Makie regression proving that the extension remains unloaded before CairoMakie and that representative declared functions throw `MethodError`.
- Direct red-state repro: the current suite loads CairoMakie before any such assertions, so the historical failure mode could survive behind a green suite.
- Tasks that close it: 1 and 2.
- Verification artifact: `test/pbdbmakie_stub.jl` executed before any Makie backend load. The old implementation lacks this proof entirely.

### L-3. Secondary environment migration

- The work is not complete if tracked secondary manifests still encode retired extension names for `PaleobiologyDB`.
- Direct red-state repro: `rg -n 'PBDBMakie = "Makie"|TaxonomyMakie = "Makie"' examples/Manifest.toml docs/Manifest.toml` currently reports stale entries in both files.
- Tasks that close it: 3 and 4.
- Verification artifact: the manifest grep above must return no matches after the migration, and both env-load smoke commands must succeed without extension-load errors tied to retired names.

### L-4. Runnable example contract

- The work is not complete if the README-advertised example commands still fail after the migration.
- Direct red-state repro: `julia --project=examples examples/src/taxonomytree.jl` and `julia --project=examples examples/src/phylopicgallery.jl` currently fail from stale extension metadata before reaching their intended runtime path.
- Tasks that close it: 3 and 4.
- Verification artifact: both example commands complete successfully after the manifest refresh. The old implementation fails these commands.

### L-5. No binding-hack regression and final green state

- The work is not complete if `Core.eval` or `__init__` regrows in source, or if the test suite or Aqua regress while the new verification is added.
- Direct red-state repro: Tranche 1 removed the binding hack, but this tranche still carries a stale `__init__` comment in `test/runtests.jl` and has no explicit guard against secondary-environment regression.
- Tasks that close it: 2 and 4.
- Verification artifact: `julia --project=test test/runtests.jl`, `julia --project=test test/runaqua.jl`, and `rg -n 'Core\.eval|__init__' src ext/PBDBMakieExt` with no source matches. A fake fix that only adds the stub while leaving stale comments or regrowing the hack fails this lock.

## Handoff packet

- Active authorities: `AGENTS.md`, `CONTRIBUTING.md`, all repo-local `STYLE*.md` files, `01_prd.md`, `02_tranches.md`, `04_tranche-01--remediation.md`.
- Parent documents: `01_prd.md`, `02_tranches.md`, `04_tranche-01--remediation.md`.
- Settled decisions and non-negotiables: no external breaking changes; `PBDBMakie` remains a compile-time submodule, not an export and not a package dependency; `public PBDBMakie` is authorized, `export PBDBMakie` is not; `_PhyloPicBridge` remains correct and must not be reopened.
- Authorization boundary: verification additions, root-module publicness repair, tracked secondary-manifest migration, and example-gate repair are in scope. Reopening Tranche 1 owner boundaries, touching `src/PBDBMakie.jl`, touching `ext/PBDBMakieExt/`, broad docs rewrites, and compatibility fallbacks are out of scope.
- Current-state diagnosis: the root and test envs are green, but plain `names(PaleobiologyDB)` still omits `:PBDBMakie`, no no-Makie stub test exists, `test/runtests.jl` still describes the retired `__init__` binding mechanism, and both `examples/Manifest.toml` and `docs/Manifest.toml` still encode retired extension names.
- Primary-goal lock: L-1 through L-5 above.
- Direct red-state repros: plain `names(PaleobiologyDB)` omission; stale manifest grep hits; example commands fail in the examples env; the current suite lacks a no-Makie regression.
- Owner and invariant under repair: `src/PaleobiologyDB.jl` owns whether the submodule is publicly visible to tooling without exporting it; `test/pbdbmakie_stub.jl` and `test/runtests.jl` own the pre-Makie verification ordering; `examples/Manifest.toml` and `docs/Manifest.toml` own secondary-environment extension metadata; the invariant is that every supported environment agrees on the renamed `PBDBMakieExt` extension and the public pre-Makie contract.
- Exact files or surfaces in scope: `src/PaleobiologyDB.jl`, `test/pbdbmakie_stub.jl`, `test/runtests.jl`, `examples/Manifest.toml`, `docs/Manifest.toml`.
- Exact files or surfaces out of scope: `src/PBDBMakie.jl`, all files under `ext/PBDBMakieExt/`, `test/runaqua.jl`, `examples/src/*.jl`, `docs/src/**/*.md`, `README.md`, `Project.toml`, `test/Manifest.toml`.
- Required upstream primary sources: Pkg.jl extension docs and Julia `base/loading.jl`; `Makie.jl/Makie/src/recipes.jl` only if pressure arises to reopen the settled Tranche 1 owner boundary.
- Green-state gates: no-Makie stub green; full `test/runtests.jl` green; `test/runaqua.jl` green; examples env commands green; no stale retired extension names in tracked secondary manifests; no source reintroduction of `Core.eval` or `__init__`.
- Stop conditions: if revalidation shows `names(PaleobiologyDB)` already includes `:PBDBMakie` or the stale manifest entries are already gone, stop and rewrite the tasking rather than blindly applying stale tasks; if example commands still fail after manifest refresh because of external PBDB, PhyloPic, or network availability rather than local package state, stop and surface the exact traceback instead of weakening the gate or editing docs to hide it; if implementation pressure suggests touching `src/PBDBMakie.jl` or `ext/PBDBMakieExt/`, stop and escalate because that reopens settled Tranche 1 design.

## Required revalidation before implementation

- Read `02_tranches.md` §"Tranche 2" and `01_prd.md` in full.
- Read `04_tranche-01--remediation.md` in full because it supersedes the old Tranche 1 `_PhyloPic` `Ref` design and confirms the settled owner boundary.
- Read the current contents of every in-scope file in full:
  - `src/PaleobiologyDB.jl`
  - `test/runtests.jl`
  - `test/runaqua.jl`
  - `test/taxonomytree_makie.jl`
  - `examples/Project.toml`
  - `examples/Manifest.toml`
  - `examples/src/taxonomytree.jl`
  - `examples/src/phylopicgallery.jl`
  - `docs/Project.toml`
  - `docs/Manifest.toml`
  - `docs/make.jl`
  - `README.md`
- Re-run the live red-state checks before editing:
  - plain `names(PaleobiologyDB)` visibility for `:PBDBMakie`
  - stale secondary-manifest grep
  - examples env load or script repro
  - current green-state checks for `test/runtests.jl` and `test/runaqua.jl`
- Re-read the Pkg.jl extension documentation and Julia `base/loading.jl` section relevant to extension callbacks before changing tracked secondary manifests.
- If any of the red-state repros no longer reproduce, stop and revise the tasking instead of proceeding mechanically.

## Tranche execution rule

This tranche is a verification-and-environment-migration tranche. It may repair the public-tooling boundary for `PBDBMakie` and the tracked secondary-manifest metadata that supports the docs and examples workflows, but it must not reopen the Tranche 1 architecture or implementation owners. The repository must begin and end in the tranche's required green state for its scope: pre-Makie stub coverage in place, examples env repaired, full test suite green, Aqua green, and no binding-hack regression in source.

The positive maintainer-facing outcome is that a fresh contributor can load the root package, inspect `PBDBMakie` before Makie, run the standard suite, and run the documented examples without hitting stale extension-name drift in tracked environments.

## Non-negotiable execution rules

- Do not modify `src/PBDBMakie.jl`.
- Do not modify any file under `ext/PBDBMakieExt/`.
- Do not export `PBDBMakie` from `PaleobiologyDB`. Use `public PBDBMakie` only.
- Do not load Makie, CairoMakie, or PhyloPicMakie in `test/pbdbmakie_stub.jl`.
- Do not solve the missing `names(PaleobiologyDB)` contract by changing README, docs prose, or tests alone while leaving the root module private.
- Do not hand-edit `examples/Manifest.toml` or `docs/Manifest.toml`. Refresh them via Pkg operations and commit the resulting generated diffs.
- Do not add a separate `PBDBMakie` package dependency, alias package, compatibility fallback, or loader shim to any environment.
- Do not weaken the example gate by deleting README claims, skipping commands, replacing runtime checks with source-text checks, or moving product logic into tests.
- Do not reintroduce `Core.eval` or `__init__` in any source file.
- Do not change `test/runaqua.jl`.

## Concrete anti-patterns and removal targets

- The stale comment in `test/runtests.jl` that says `PBDBMakie` is bound by the extension's `__init__`.
- Any manifest stanza under `docs/Manifest.toml` or `examples/Manifest.toml` that still records `PBDBMakie = "Makie"` or `TaxonomyMakie = "Makie"` for `PaleobiologyDB`.
- A fake fix that only checks `isdefined(PaleobiologyDB, :PBDBMakie)` while leaving `:PBDBMakie` absent from plain `names(PaleobiologyDB)`.
- A fake fix that updates manifest text but never runs the examples or env-load commands.
- A fake fix that removes README or docs claims about runnable examples instead of repairing the secondary environments.
- A fake fix that loads Makie before the new stub test and then claims the pre-Makie contract is covered.
- Any attempt to recreate the retired owner boundary through a separate `PBDBMakie` package dependency or extension-name compatibility shim.

## Failure-oriented verification

The following checks must fail on the current bad state or stale regression shape and pass on the completed tranche:

1. Public names visibility:

   ```sh
   julia --project=. -e 'using PaleobiologyDB; @assert :PBDBMakie in names(PaleobiologyDB)'
   ```

   This currently fails.

2. Pre-Makie extension-unloaded and declaration contract:

   ```sh
   julia --project=. -e 'using PaleobiologyDB; @assert isnothing(Base.get_extension(PaleobiologyDB, :PBDBMakieExt)); @assert PaleobiologyDB.PBDBMakie isa Module; for sym in (:taxonomytreeplot, :augment_leaf_phylopic!, :acquire_phylopic); try getproperty(PaleobiologyDB.PBDBMakie, sym)(); error("unexpected success: $(sym)"); catch e; @assert e isa MethodError; end; end'
   ```

   The old suite has no equivalent proof.

3. Stale secondary-manifest entries:

   ```sh
   rg -n 'PBDBMakie = "Makie"|TaxonomyMakie = "Makie"' examples/Manifest.toml docs/Manifest.toml
   ```

   This currently matches both files.

4. Runnable example commands:

   ```sh
   julia --project=examples examples/src/taxonomytree.jl
   julia --project=examples examples/src/phylopicgallery.jl
   ```

   These currently fail from stale extension metadata before reaching the intended example behavior.

5. Final regression gates:

   ```sh
   julia --project=test test/runtests.jl
   julia --project=test test/runaqua.jl
   rg -n 'Core\.eval|__init__' src ext/PBDBMakieExt
   ```

   The final grep must return no source matches.

## Tasks

### 1. Make `PBDBMakie` public to tooling and add the no-Makie regression

**Type**: WRITE  
**Output**: `src/PaleobiologyDB.jl` declares `public PBDBMakie` without exporting it, and `test/pbdbmakie_stub.jl` exists with a complete pre-Makie contract test.  
**Depends on**: none

Update `src/PaleobiologyDB.jl` by adding `public PBDBMakie` immediately after `include("PBDBMakie.jl")` and before the module `end`. Do not add an `export` statement. Then create `test/pbdbmakie_stub.jl` with `using Test` and `using PaleobiologyDB`. The file must contain a top-level `@testset "PBDBMakie submodule"` with four nested testsets in this order: `"Module visibility before Makie"`, `"Declared API visibility before Makie"`, `"Extension remains unloaded before Makie"`, and `"Functions throw MethodError before Makie"`. The declared-API testset must assert that plain `names(PaleobiologyDB)` includes `:PBDBMakie`, that plain `names(PaleobiologyDB.PBDBMakie)` includes all 15 declared public symbols from `src/PBDBMakie.jl`, and that `:TaxonomyTreePlot` is absent before Makie loads. The extension-unloaded testset must assert `isnothing(Base.get_extension(PaleobiologyDB, :PBDBMakieExt))`. The final testset must cover the three representative calls from the tranche: `taxonomytreeplot()`, `augment_leaf_phylopic!()`, and `acquire_phylopic()`, each via `@test_throws MethodError`.

**Positive contract**: a no-Makie load of `PaleobiologyDB` exposes `PBDBMakie` through plain `names(PaleobiologyDB)` without exporting it, and the declared API is visible to introspection before Makie loads.  
**Negative contract**: do not touch `src/PBDBMakie.jl` or `ext/PBDBMakieExt/`; do not export `PBDBMakie`; do not load Makie in the stub; do not broaden the stub into extension-internal testing.  
**Files**: `src/PaleobiologyDB.jl`, `test/pbdbmakie_stub.jl`  
**Out of scope**: `test/runtests.jl`, manifests, example scripts, docs prose, all extension and submodule implementation files  
**Verification**:

```sh
julia --project=. -e 'using PaleobiologyDB; @assert :PBDBMakie in names(PaleobiologyDB); @assert PaleobiologyDB.PBDBMakie isa Module; @assert isnothing(Base.get_extension(PaleobiologyDB, :PBDBMakieExt))'
```

### 2. Run the stub before Makie and retire the stale `__init__` comment

**Type**: TEST  
**Output**: `test/runtests.jl` includes `pbdbmakie_stub.jl` before any Makie-related load and describes the compile-time submodule truth instead of the retired `__init__` hack.  
**Depends on**: 1

Read `test/runtests.jl` in full before editing. Insert `include("pbdbmakie_stub.jl")` immediately after `include("taxonomy_graphs.jl")` and before the first Makie-related `using` or `import`. Replace the stale two-line comment above `using PaleobiologyDB.PBDBMakie` with a two-line comment that states the current truth: `PBDBMakie` is a compile-time submodule of `PaleobiologyDB`, and its exports are loaded into test scope only after CairoMakie triggers `PBDBMakieExt`. Leave the order of the existing Makie-gated tests unchanged after the new stub include. Do not touch any other test file in this task.

**Positive contract**: the public no-Makie regression executes before CairoMakie, and the suite records the current owner boundary honestly.  
**Negative contract**: do not move Makie-gated tests ahead of the stub; do not preserve any `__init__`-binding wording; do not rewrite existing test logic beyond the include placement and comment replacement.  
**Files**: `test/runtests.jl`  
**Out of scope**: all other test files, manifests, source files other than the Task 1 scope  
**Verification**:

```sh
julia --project=test test/runtests.jl
```

### 3. Refresh the tracked secondary manifests for the renamed extension

**Type**: MIGRATE  
**Output**: `examples/Manifest.toml` and `docs/Manifest.toml` are regenerated by Pkg so their `PaleobiologyDB` extension stanzas agree with the current root `Project.toml`.  
**Depends on**: 1

From the repository root, refresh the tracked manifests with Pkg rather than editing them by hand. Run `julia --project=examples -e 'using Pkg; Pkg.resolve()'` and `julia --project=docs -e 'using Pkg; Pkg.resolve()'`. Commit only the generated diffs in `examples/Manifest.toml` and `docs/Manifest.toml`. After the refresh, each `[[deps.PaleobiologyDB]]` stanza must record `PBDBMakieExt = "Makie"` and must not retain `PBDBMakie = "Makie"` or `TaxonomyMakie = "Makie"`. Do not modify `examples/Project.toml`, `docs/Project.toml`, `examples/src/*.jl`, `docs/src/**/*.md`, or `docs/make.jl` in this task.

**Positive contract**: both tracked secondary environments agree with the current extension naming contract and no longer try to load retired extension names.  
**Negative contract**: do not hand-edit manifest files; do not add a separate `PBDBMakie` package dependency; do not repair the drift by changing docs or example source text instead of the tracked env metadata.  
**Files**: `examples/Manifest.toml`, `docs/Manifest.toml`  
**Out of scope**: `examples/Project.toml`, `docs/Project.toml`, `examples/src/*.jl`, `docs/src/**/*.md`, `docs/make.jl`, root `Project.toml`, `test/Manifest.toml`  
**Verification**:

```sh
rg -n 'PBDBMakie = "Makie"|TaxonomyMakie = "Makie"' examples/Manifest.toml docs/Manifest.toml
julia --project=examples -e 'using CairoMakie, PaleobiologyDB, PaleobiologyDB.PBDBMakie; @assert !isnothing(Base.get_extension(PaleobiologyDB, :PBDBMakieExt))'
julia --project=docs -e 'using CairoMakie, PaleobiologyDB, PaleobiologyDB.PBDBMakie; @assert !isnothing(Base.get_extension(PaleobiologyDB, :PBDBMakieExt))'
```

The `rg` command must return no matches.

### 4. Re-run the examples and final regression gates

**Type**: TEST  
**Output**: the documented examples run, the suite remains green, Aqua remains green, and no source binding-hack regression appears.  
**Depends on**: 2, 3

Run the README-advertised example commands exactly from the `examples` environment, then run the full repository regression gates. The example commands are `julia --project=examples examples/src/taxonomytree.jl` and `julia --project=examples examples/src/phylopicgallery.jl`. Then run `julia --project=test test/runtests.jl` and `julia --project=test test/runaqua.jl`. Finally, verify that no retired binding-hack source pattern survives under `src/` or `ext/PBDBMakieExt/`. If an example still fails after the manifest refresh because of external service availability or network access rather than local package state, stop and surface the exact traceback instead of weakening the gate or changing docs claims.

**Positive contract**: the supported examples, the standard suite, and Aqua all pass in their tracked environments, and the retired binding hack remains absent from source.  
**Negative contract**: do not replace runtime example execution with grep checks; do not suppress example failures by editing README or docs prose; do not reintroduce compatibility shims or stale extension names to make one env appear green.  
**Files**: none  
**Out of scope**: any source, test, docs, or example edits beyond the changes already authorized in Tasks 1 through 3  
**Verification**:

```sh
julia --project=examples examples/src/taxonomytree.jl
julia --project=examples examples/src/phylopicgallery.jl
julia --project=test test/runtests.jl
julia --project=test test/runaqua.jl
rg -n 'Core\.eval|__init__' src ext/PBDBMakieExt
```

The final `rg` command must return no source matches.
