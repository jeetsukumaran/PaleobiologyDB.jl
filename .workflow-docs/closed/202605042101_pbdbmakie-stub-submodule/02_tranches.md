# Tranches: PBDBMakie unconditional submodule

These tranches implement `01_prd.md` in dependency order.

All implementers must treat the following as controlling authorities and read
them line by line before beginning any tranche:

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
- Global `CLAUDE.md`

Vocabulary note: `STYLE-vocabulary.md` entries are LineagesMakie.jl-domain-specific
and do not directly constrain PBDBMakie API names. General governance obligations
(pass-forward, no unilateral amendments) still apply. The term `Core.eval` applied
to foreign module namespaces as a binding mechanism is proscribed in all downstream
documents; it is the anti-pattern being removed.

Required upstream primary sources --- must be read before implementation:

- Julia extension system: Pkg.jl extension documentation at
  https://pkgdocs.julialang.org/stable/creating-packages/#Conditional-loading-of-code-in-packages-(Extensions)
  and `base/loading.jl` in the Julia source tree
- Makie `@recipe` macro: `Makie.jl/src/recipes.jl` at
  `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Makie.jl/src/recipes.jl`;
  Makie recipe documentation

These sources constrain: how extensions are named and loaded; how `@recipe` creates
and registers types; what happens when multiple modules define functions with the same
name (dispatch, not redefinition).

## Tranche 1: Establish PBDBMakie submodule and rename extension

**Type:** AFK
**Blocked by:** None --- can start immediately

### Parent PRD

`01_prd.md`

### Governance and required reading

- Mandated line-by-line reading of all governance documents listed above.
- Mandated reading of the Makie and Julia extension primary sources listed above,
  especially `Makie.jl/src/recipes.jl` and the Pkg.jl extension documentation.
- Mandated reading of the current extension owner before making any changes:
  - `ext/PBDBMakie/PBDBMakie.jl`
  - `ext/PBDBMakie/_layout.jl`
  - `ext/PBDBMakie/_leaf_overlay.jl`
  - `ext/PBDBMakie/_recipe.jl`
  - `ext/PBDBMakie/_augment.jl`
  - `ext/PBDBMakie/PhyloPic/src/PhyloPic.jl`
  - `ext/PBDBMakie/PhyloPic/src/_phylopic_core.jl`
  - `ext/PBDBMakie/PhyloPic/src/_resolve.jl`
  - `ext/PBDBMakie/PhyloPic/src/_render.jl`
  - `ext/PBDBMakie/PhyloPic/src/_pbdb_phylopic_grid.jl`
  - `src/PaleobiologyDB.jl`
  - `Project.toml`
- Mandated reading of the existing test files before touching any source:
  - `test/taxonomytree_makie.jl`
  - `test/phylopic_makie.jl`
  - `test/runaqua.jl`
  - `test/runtests.jl`

### What to build

Perform the complete structural migration to a real compile-time submodule.

This tranche must:

1. Create `src/PBDBMakie.jl` --- the unconditional submodule. It must:
   - Declare `module PBDBMakie`
   - Declare all 15 public API functions using bare function declaration syntax:
     `taxonomytreeplot`, `taxonomytreeplot!`, `set_rank_axis_ticks!`,
     `leaf_positions`, `augment_leaf_phylopic!`, `acquire_phylopic`,
     `augment_phylopic`, `augment_phylopic!`, `augment_phylopic_ranges`,
     `augment_phylopic_ranges!`, `phylopic_images_dataframe`, `phylopic_node`,
     `phylopic_images`, `pbdb_phylopic_grid`, `pbdb_phylopic_grid!`
   - Each declaration uses the bare syntax: `function f end`
   - Declare `const _PhyloPic = Ref{Union{Module, Nothing}}(nothing)` --- a
     bridge set by the extension to expose the vendored PhyloPic module to tests;
     not exported
   - Export exactly the same symbol list as the current extension minus
     `TaxonomyTreePlot`
   - Import nothing from Makie or any optional package
   - Include a module-level docstring describing the submodule's role

2. Update `src/PaleobiologyDB.jl` --- add `include("PBDBMakie.jl")` after the
   existing includes. `PBDBMakie` must become a genuine compile-time sub-module
   binding.

3. Rename the extension directory: `ext/PBDBMakie/` → `ext/PBDBMakieExt/`

4. Within `ext/PBDBMakieExt/`:
   - Rename `PBDBMakie.jl` → `PBDBMakieExt.jl`
   - Update the module declaration from `module PBDBMakie` to `module PBDBMakieExt`
   - Remove the `__init__()` function and `Core.eval` hack entirely
   - Import all 15 declared functions from `PaleobiologyDB.PBDBMakie` before any
     `include()` call --- this is required so that `@recipe` in `_recipe.jl`
     extends `PBDBMakie.taxonomytreeplot` rather than creating a fresh
     `PBDBMakieExt.taxonomytreeplot` (confirmed by `Makie.jl/src/recipes.jl`
     lines 180--204)
   - Set `PBDBMakie._PhyloPic[] = PhyloPic` after loading the PhyloPic submodule
   - Add 10 catch-all delegation methods for the PhyloPic-sourced symbols
     (required because `using .PhyloPic` aliases them in `PBDBMakieExt`'s
     namespace but does not add methods to `PBDBMakie.*`)
   - Keep all `include` calls to the implementation files unchanged (paths remain
     valid within the renamed directory)
   - Keep `@recipe TaxonomyTreePlot` definition here --- it cannot be pre-defined
     without Makie
   - Remove explicit `export` lines --- `PBDBMakie` owns user-facing exports

5. Update `Project.toml`:
   - Change `[extensions]` entry from `PBDBMakie = "Makie"` to
     `PBDBMakieExt = "Makie"`

6. Apply minimal structural adaptations to `test/taxonomytree_makie.jl` and
   `test/phylopic_makie.jl` required by the rename and the new `_PhyloPic`
   access path (11 mechanical substitutions across both files; see tasking
   document for exact line numbers and replacements).

No other files are to be modified. Do not modify `test/runtests.jl` in this
tranche. The implementation files (`_layout.jl`, `_leaf_overlay.jl`,
`_recipe.jl`, `_augment.jl`, `PhyloPic/src/`) contain the existing working
implementation and must not be changed.

Confirm before beginning: read `STYLE-julia.md` §§1, 2, 4, and 5 (anti-patterns)
to ensure declarations follow the project's functional and naming conventions.

### How to verify

**Automated (run after each structural step, not only at the end):**

1. After creating `src/PBDBMakie.jl` and updating `src/PaleobiologyDB.jl`:
   ```
   julia --project=. -e 'using PaleobiologyDB; @assert isdefined(PaleobiologyDB, :PBDBMakie); println("Submodule visible: OK")'
   ```
2. After renaming the extension and updating `Project.toml`:
   ```
   julia --project=test test/runtests.jl
   ```
   All currently passing tests must continue to pass. No new failures permitted.
3. After completing all changes:
   ```
   julia --project=test test/runaqua.jl
   ```
   Aqua must remain clean. Pay particular attention to: undefined-exports check
   (bare declarations may affect this), method ambiguities (bare declarations
   plus concrete methods must not create ambiguities).

### Acceptance criteria

- [ ] Given `using PaleobiologyDB` with no Makie backend loaded, when
  `isdefined(PaleobiologyDB, :PBDBMakie)` is evaluated, then it returns `true`
  and `PaleobiologyDB.PBDBMakie` is a `Module`.
- [ ] Given `using PaleobiologyDB` with no Makie backend loaded, when any
  declared function such as `PaleobiologyDB.PBDBMakie.taxonomytreeplot()` is
  called, then it throws a `MethodError` --- no methods have been loaded.
- [ ] Given `using CairoMakie; using PaleobiologyDB; using PaleobiologyDB.PBDBMakie`,
  when any tree visualization or PhyloPic bridge function is called with valid
  arguments, then it behaves identically to the pre-migration extension behavior.
- [ ] Given the renamed extension `PBDBMakieExt`, when the full test suite in
  `test/runtests.jl` runs (including `taxonomytree_makie.jl` and `phylopic_makie.jl`),
  then all previously passing tests continue to pass.
- [ ] `test/runaqua.jl` reports clean with no new Aqua failures.
- [ ] The `Core.eval` hack in `__init__` is absent from all source files.
- [ ] `Project.toml` has `PBDBMakieExt = "Makie"` in `[extensions]` and no
  entry for `PBDBMakie`.

### User stories addressed

- User story 1: `using PaleobiologyDB` (no Makie) sees `PBDBMakie` in
  tab-completion and `names(PaleobiologyDB)`
- User story 3: `using PaleobiologyDB.PBDBMakie` works natively via real sub-module
- User story 7: `taxonomytreeplot(tree)` after loading Makie returns `FigureAxisPlot`
  as before
- User story 8: `augment_leaf_phylopic!(ax, p)` after loading Makie renders correctly

## Tranche 2: Add pre-Makie submodule verification and confirm full green state

**Type:** AFK
**Blocked by:** Tranche 1

### Parent PRD

`01_prd.md`

### Governance and required reading

- Mandated line-by-line reading of all governance documents listed in the
  tranches header above.
- Mandated line-by-line reading of `STYLE-verification.md`, with specific
  attention to §§ "Verify the real contract boundary", "Every bug fix should
  add or strengthen verification", and "Green-state requirements must be explicit".
- Mandated reading of the completed state from Tranche 1:
  - `src/PBDBMakie.jl`
  - `ext/PBDBMakieExt/PBDBMakieExt.jl`
  - `test/runtests.jl`
  - `test/runaqua.jl`
- Mandated reading of the existing test files to understand current test
  structure and avoid conflicts:
  - `test/taxonomytree_makie.jl`
  - `test/phylopic_makie.jl`
- Mandated reading of any `examples/` scripts to confirm their runability.

### What to build

Add the new pre-Makie submodule test and confirm all green-state gates per the PRD.

This tranche must:

1. Create `test/pbdbmakie_stub.jl` --- the pre-Makie submodule test. Following the
   test structure from the PRD §"Testing and verification decisions":
   ```julia
   using Test
   using PaleobiologyDB

   @testset "PBDBMakie submodule" begin

       @testset "Module visibility before Makie" begin
           @test isdefined(PaleobiologyDB, :PBDBMakie)
           @test PaleobiologyDB.PBDBMakie isa Module
       end

       @testset "Functions throw MethodError before Makie" begin
           @test_throws MethodError PaleobiologyDB.PBDBMakie.taxonomytreeplot()
           @test_throws MethodError PaleobiologyDB.PBDBMakie.augment_leaf_phylopic!()
           @test_throws MethodError PaleobiologyDB.PBDBMakie.acquire_phylopic()
       end

   end
   ```
   This test must run in a process with no Makie backend loaded. Confirm that
   including it in the main `test/runtests.jl` does not load Makie as a side
   effect.

2. Update `test/runtests.jl` --- include `pbdbmakie_stub.jl` at an appropriate
   point, ensuring it runs before any Makie-loading test file. Also update the
   stale comment at line 29 that references the old `__init__` binding mechanism.
   Read the current `test/runtests.jl` in full before editing.

3. Run the full verification pass described below and confirm all gates are met.

The test file must follow `STYLE-julia.md` naming, formatting, and docstring
conventions. `STYLE-verification.md` §"Verify the real contract boundary"
requires that the submodule test verifies the actual contract boundary
(module visibility and pre-Makie dispatch behavior), not merely internal proxies.

### How to verify

**Automated:**

1. Run the full test suite including the new submodule test:
   ```
   julia --project=test test/runtests.jl
   ```
   All tests must pass, including `pbdbmakie_stub.jl`, `taxonomytree_makie.jl`,
   and `phylopic_makie.jl`.

2. Confirm Aqua clean:
   ```
   julia --project=test test/runaqua.jl
   ```

**Manual:**

3. Confirm that examples scripts run without error. For each script under
   `examples/` (if any), run:
   ```
   julia --project=examples examples/src/<script>.jl
   ```
   and confirm no load errors or runtime errors related to the migration.

4. Confirm that `PBDBMakie` is visible in the REPL without Makie loaded:
   ```julia
   julia> using PaleobiologyDB
   julia> PaleobiologyDB.PBDBMakie
   # should return the module, not an UndefVarError
   julia> names(PaleobiologyDB)
   # should include :PBDBMakie
   ```

5. Confirm that no `Core.eval` or `__init__` binding hack remains anywhere in
   `ext/PBDBMakieExt/`.

### Acceptance criteria

- [ ] `test/pbdbmakie_stub.jl` exists and all its `@test` assertions pass in a
  process with no Makie backend loaded.
- [ ] `test/runtests.jl` includes `pbdbmakie_stub.jl` and the full suite passes:
  all pre-existing tests plus the new submodule test.
- [ ] `test/runaqua.jl` reports clean.
- [ ] `examples/` scripts (if any) run without error after the migration.
- [ ] `PaleobiologyDB.PBDBMakie` is accessible from the REPL without loading
  Makie, and `names(PaleobiologyDB)` includes `:PBDBMakie`.
- [ ] No `Core.eval` or `__init__` binding hack is present in any file under
  `ext/PBDBMakieExt/`.

### User stories addressed

- User story 2: calling a declared function before Makie loads yields a `MethodError`
- User story 5: documentation tool introspects `PaleobiologyDB.PBDBMakie` without
  Makie loaded and sees declared functions
- User story 6: downstream test suite verifies `PBDBMakie` module exists pre-Makie
  and declared functions throw `MethodError`
