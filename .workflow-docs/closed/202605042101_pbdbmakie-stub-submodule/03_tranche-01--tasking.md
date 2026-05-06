# Tasks for Tranche 1: Establish PBDBMakie submodule and rename extension

Parent tranche: Tranche 1
Parent PRD: `01_prd.md`

## Settled user decisions and environment baseline

- **No `Core.eval` in any source file.** The entire migration is motivated by removing
  the `Core.eval(PaleobiologyDB, :(PBDBMakie = $(@__MODULE__)))` hack in the extension's
  `__init__`. This constraint is absolute and non-negotiable.
- **Implementation files are frozen.** `_layout.jl`, `_leaf_overlay.jl`, `_recipe.jl`,
  `_augment.jl`, and all files under `PhyloPic/src/` must not be modified.
- **`TaxonomyTreePlot` is not declared in the submodule.** The `@recipe` macro cannot
  define a plot type without Makie; `TaxonomyTreePlot` is defined only in the extension.
  This is an explicit PRD decision. It is a known breakage for LIVE-gated tests
  (`PBDB_LIVE=1 julia --project=test test/runtests.jl`) that reference `TaxonomyTreePlot`
  directly; those tests are not part of standard CI and are accepted as out-of-scope.
- **15 public API symbols are declared and exported**, matching the extension's current
  export list minus `TaxonomyTreePlot`:
  `taxonomytreeplot`, `taxonomytreeplot!`, `set_rank_axis_ticks!`, `leaf_positions`,
  `augment_leaf_phylopic!`, `acquire_phylopic`, `augment_phylopic`, `augment_phylopic!`,
  `augment_phylopic_ranges`, `augment_phylopic_ranges!`, `phylopic_images_dataframe`,
  `phylopic_node`, `phylopic_images`, `pbdb_phylopic_grid`, `pbdb_phylopic_grid!`
- **Bare declarations are mechanically necessary for all 15.** Julia's extension system
  can only add methods to functions that already exist. If `PBDBMakie.f` does not exist
  before the extension loads, the extension cannot extend it via
  `import PBDBMakie: f` + new method definition. Creating bindings in `PBDBMakie` from
  the extension without a pre-existing declaration would require `Core.eval` --- the
  anti-pattern being removed.
- **10 catch-all delegations are necessary** for the PhyloPic-sourced symbols
  (`acquire_phylopic`, `augment_phylopic`, `augment_phylopic!`, `augment_phylopic_ranges`,
  `augment_phylopic_ranges!`, `phylopic_images_dataframe`, `phylopic_node`,
  `phylopic_images`, `pbdb_phylopic_grid`, `pbdb_phylopic_grid!`).
  These functions are defined in the `PhyloPic` submodule and brought into
  `PBDBMakieExt` via `using .PhyloPic`. That `using` does NOT add methods to
  `PBDBMakie.*`; it only aliases them in `PBDBMakieExt`'s namespace. Without explicit
  delegations, calling `PBDBMakie.acquire_phylopic(...)` yields a `MethodError` even
  after Makie loads.
- **Import order is critical.** All 15 declared symbols must be imported from `PBDBMakie`
  into `PBDBMakieExt` **before** any `include()` call. The reason: `@recipe` in
  `_recipe.jl` expands with `esc(funcname_sym)` --- scoped to the calling module. If
  `taxonomytreeplot` is already imported from `PBDBMakie` when `_recipe.jl` is included,
  the `@recipe` expansion extends `PBDBMakie.taxonomytreeplot`. If `_recipe.jl` is
  included first, `@recipe` creates a new `PBDBMakieExt.taxonomytreeplot` instead,
  which does not add methods to the declared function. This is confirmed by reading
  `Makie.jl/Makie/src/recipes.jl` lines 180--204.
- **`_PhyloPic` Ref bridge.** The submodule declares
  `const _PhyloPic = Ref{Union{Module, Nothing}}(nothing)`. The extension sets
  `PBDBMakie._PhyloPic[] = PhyloPic` after loading the PhyloPic submodule. This
  exposes the PhyloPic module to tests without `Core.eval`. Setting the contents of
  a `Ref` does not require `Core.eval` --- only the `Ref` constant itself is immutable.
  `_PhyloPic` is **not exported** from the submodule.
- **Minimal test adaptations are authorized in Tranche 1.** Three independent
  path/access references in two test files are structurally incompatible with the new
  architecture. The minimal mechanical updates listed in Task 5 are authorized as a
  necessary consequence of the rename. No test logic, assertions, or `@testset`
  structure may change beyond what is listed.
- **`test/runtests.jl` stale comment is NOT touched in Tranche 1.** Line 29
  (`# PBDBMakie is bound into PaleobiologyDB by the extension's __init__.`) is
  Tranche 2 work and must not be updated here.
- **Aqua `stale_deps` exclusion for `PhyloPicMakie` remains valid.** `PhyloPicMakie`
  is in `[deps]` (hard dep) and is used inside `ext/PBDBMakieExt/PhyloPic/src/`.
  The exclusion in `test/runaqua.jl` does not change.
- **`PBDBMakieExt` exports are irrelevant to users.** The extension is never directly
  `using`-ed; `@recipe` auto-generates `export TaxonomyTreePlot, taxonomytreeplot,
  taxonomytreeplot!` within `PBDBMakieExt`'s own namespace, which is harmless but
  does not affect user-facing API. The explicit export lines from the original
  `PBDBMakie.jl` (extension) are removed in the rewrite.

## Governance

All tasks must comply with:

- `CONTRIBUTING.md` (project-local)
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

Read each document line by line before beginning. Do not summarize or substitute
recollection for the source text.

Upstream primary sources --- read before implementation:

- `Makie.jl/Makie/src/recipes.jl` --- confirms `@recipe` expansion uses `esc(funcname_sym)`,
  making import order the determinant of whether the extension extends the declared
  function or creates a fresh one.
- Pkg.jl extension documentation at
  `https://pkgdocs.julialang.org/stable/creating-packages/#Conditional-loading-of-code-in-packages-(Extensions)` ---
  confirms extension naming convention and loading contract.

Read-only git and shell commands may be used freely. Mutating git operations
(commit, merge, push, branch) remain the human project owner's responsibility
unless explicitly instructed otherwise.

## Required revalidation before implementation

- Read the tranche (`02_tranches.md` §"Tranche 1") and parent PRD (`01_prd.md`)
  in full before touching any file.
- Read the current state of every file that will be touched:
  - `src/PaleobiologyDB.jl`
  - `src/PBDBMakie.jl` (does not yet exist --- confirm with `ls src/`)
  - `ext/PBDBMakie/PBDBMakie.jl`
  - `ext/PBDBMakie/_layout.jl`, `_leaf_overlay.jl`, `_recipe.jl`, `_augment.jl`
  - `ext/PBDBMakie/PhyloPic/src/PhyloPic.jl`
  - `Project.toml`
  - `test/taxonomytree_makie.jl`
  - `test/phylopic_makie.jl`
  - `test/runtests.jl`
  - `test/runaqua.jl`
- Re-read `Makie.jl/Makie/src/recipes.jl` lines 180--204 to confirm the `@recipe`
  import-order constraint before writing `PBDBMakieExt.jl`.
- If anything has changed since this task file was written, stop and raise that
  before modifying code.

## Tranche execution rule

All work must begin and end in the tranche's required green, policy-compliant state.
The full test suite and Aqua must pass at the end of the tranche. Partial green
states are permitted between tasks within a single session, but the session must
not conclude with any failing test or Aqua error.

The `Core.eval` hack in the extension's `__init__` must be absent from all source
files when the tranche is complete. The presence of `Core.eval` in any file under
`src/` or `ext/` is a blocking failure.

## Non-negotiable execution rules

- Do not modify any file under `ext/PBDBMakieExt/` other than `PBDBMakieExt.jl`.
  The implementation files contain the existing working implementation.
- Do not add `Core.eval` to any source file for any reason.
- Do not recreate `__init__()` in `PBDBMakieExt.jl`.
- Do not add Makie imports or any optional-package imports to `src/PBDBMakie.jl`.
- Do not export `TaxonomyTreePlot` from the submodule.
- Do not export `_PhyloPic` from the submodule.
- Do not touch `test/runtests.jl` in Tranche 1.
- Do not make any change to test files beyond the exact three groups of substitutions
  listed in Task 5.
- Do not add new `@testset` blocks or `@test` assertions to any existing test file.
- Do not change the Aqua exclusion in `test/runaqua.jl`.

## Concrete anti-patterns and removal targets

- **`Core.eval(PaleobiologyDB, :(PBDBMakie = $(@__MODULE__)))`** in
  `ext/PBDBMakieExt/PBDBMakieExt.jl` --- must be absent; its removal is the
  entire point of this tranche.
- **`function __init__()`** in `PBDBMakieExt.jl` --- must be absent.
- **`ext/PBDBMakie/` directory** --- must not exist after Task 4a. The rename is
  permanent; no backwards-compatibility alias is introduced.
- **Fresh function definitions for the 15 symbols in `PBDBMakieExt.jl`** --- after the
  import block, the extension must extend `PBDBMakie.*` declarations, not define new
  `PBDBMakieExt.*` functions. If the import block is missing or misplaced, `@recipe`
  and the implementation-file definitions create fresh functions in the wrong namespace.
- **Explicit `export` lines in `PBDBMakieExt.jl`** (other than what `@recipe`
  auto-generates) --- remove; `PBDBMakie` owns the user-facing exports.

## Failure-oriented verification

The following checks must FAIL on the known bad state (pre-migration) and PASS
on the correct post-migration state:

1. `julia --project=. -e 'using PaleobiologyDB; @assert isdefined(PaleobiologyDB, :PBDBMakie) "PBDBMakie not defined before Makie loads"'`
   --- fails before migration (the submodule does not exist); passes after Task 3.

2. `julia --project=. -e 'using PaleobiologyDB; try PaleobiologyDB.PBDBMakie.taxonomytreeplot(); catch e; @assert e isa MethodError "Wrong error type: $(typeof(e))"; println("OK"); end'`
   --- fails before migration (`PBDBMakie` not defined); passes after Tasks 2--3.

3. `grep -r "Core.eval" ext/PBDBMakieExt/` --- returns no matches after Task 4a+4b;
   any match is a blocking failure.

4. `grep '__init__' ext/PBDBMakieExt/PBDBMakieExt.jl` --- returns no matches after
   Task 4a+4b; any match is a blocking failure.

5. `grep 'PBDBMakie = "Makie"' Project.toml` --- returns no matches after Task 1;
   any match means the old entry survived.

6. `ls ext/PBDBMakie/` --- must return a non-zero exit code (directory gone) after
   Task 4a; zero exit means the rename did not happen.

7. Full test suite and Aqua (Task 6) --- all tests that passed before migration must
   pass after. Any new failure is a blocker.

---

## Tasks

### 1. Update `Project.toml` extension entry

**Type:** CONFIG
**Output:** `[extensions]` block contains `PBDBMakieExt = "Makie"` and no entry
for `PBDBMakie`; `julia --project=. -e 'using Pkg; Pkg.resolve()'` does not error
**Depends on:** none

Read `Project.toml` in full. In the `[extensions]` block, replace the single line
`PBDBMakie = "Makie"` with `PBDBMakieExt = "Makie"`. No other line in `Project.toml`
changes. The `[weakdeps]` entry `Makie = "ee78f7c6-..."` is unchanged. The
`[compat]` entry `Makie = "0.21, 0.22, 0.23, 0.24"` is unchanged.

**Positive contract:** `grep 'PBDBMakieExt = "Makie"' Project.toml` exits 0;
the `[extensions]` block has exactly one entry.

**Negative contract:** `grep -c 'PBDBMakie = "Makie"' Project.toml` returns 0.
No other block or entry in `Project.toml` is modified.

**Files:** `Project.toml`

**Out of scope:** All other files.

**Verification:**
```
grep 'PBDBMakieExt = "Makie"' Project.toml
grep -c 'PBDBMakie = "Makie"' Project.toml   # must print 0
```

---

### 2. Create `src/PBDBMakie.jl` submodule

**Type:** WRITE
**Output:** `src/PBDBMakie.jl` exists and contains a valid `module PBDBMakie` with
15 bare function declarations, a `_PhyloPic` Ref, and 15 exports
**Depends on:** none (may run in parallel with Task 1)

Create `src/PBDBMakie.jl`. Its complete content must be, in order:

1. A module-level docstring (triple-quoted) on the module `PBDBMakie` explaining
   its role. It should state:
   - that it is the unconditional compile-time submodule of `PaleobiologyDB`,
     always present regardless of whether a Makie backend is loaded;
   - that it declares the public API for tree visualization and PhyloPic bridge
     functions;
   - that when a Makie backend is loaded, the extension `PBDBMakieExt` adds
     concrete method implementations via dispatch;
   - that `TaxonomyTreePlot` (the Makie plot type) is not declared here because
     the `@recipe` macro requires Makie.
   Follow `STYLE-docs.md` conventions for module docstrings.

2. `module PBDBMakie`

3. `const _PhyloPic = Ref{Union{Module, Nothing}}(nothing)` --- internal bridge
   that the extension sets to the loaded `PhyloPic` submodule. Not exported.

4. Exactly 15 bare function declarations, one per public symbol:
   ```julia
   function taxonomytreeplot end
   function taxonomytreeplot! end
   function set_rank_axis_ticks! end
   function leaf_positions end
   function augment_leaf_phylopic! end
   function acquire_phylopic end
   function augment_phylopic end
   function augment_phylopic! end
   function augment_phylopic_ranges end
   function augment_phylopic_ranges! end
   function phylopic_images_dataframe end
   function phylopic_node end
   function phylopic_images end
   function pbdb_phylopic_grid end
   function pbdb_phylopic_grid! end
   ```
   No docstrings on individual declarations --- the module-level docstring covers
   the role. No Makie imports, no optional-package imports, no `using`, no `import`.

5. `export` statement exporting exactly the same 15 symbols and no others.
   `_PhyloPic` is NOT exported. `TaxonomyTreePlot` is NOT exported.

6. `end # module PBDBMakie`

Before creating the file, confirm with `ls src/` that `PBDBMakie.jl` does not
already exist.

**Positive contract:** The file compiles without error when included standalone.
All 15 symbols are exported. Calling any declared function with zero arguments
throws `MethodError` (no methods defined). `_PhyloPic[]` is `nothing` (before
extension loads). No Makie or optional-package dependencies.

**Negative contract:** No `TaxonomyTreePlot`. No `export _PhyloPic`. No `using` or
`import` in the module body. No `__init__`. No `Core.eval`. No function bodies ---
only bare `function f end` declarations.

**Files:** `src/PBDBMakie.jl` (new)

**Out of scope:** All other files.

**Verification** (run after Task 3 wires the include):
```
julia --project=. -e '
using PaleobiologyDB
@assert isdefined(PaleobiologyDB, :PBDBMakie) "PBDBMakie not bound"
@assert PaleobiologyDB.PBDBMakie isa Module "PBDBMakie is not a Module"
try
    PaleobiologyDB.PBDBMakie.taxonomytreeplot()
catch e
    @assert e isa MethodError "wrong error type: $(typeof(e))"
    println("Submodule and bare declaration verified: OK")
end
'
```

---

### 3. Update `src/PaleobiologyDB.jl` to include the submodule

**Type:** WRITE
**Output:** `include("PBDBMakie.jl")` present in `src/PaleobiologyDB.jl`;
`PBDBMakie` is a compile-time sub-module binding of `PaleobiologyDB`
**Depends on:** Task 2

Read `src/PaleobiologyDB.jl` in full. The current file is:
```julia
module PaleobiologyDB
using DataCaches
export DataCaches
include("dbapi.jl")
include("pbdbdocs.jl")
include("pbdbtools/pbdbtools.jl")
end # module
```

Add `include("PBDBMakie.jl")` as a new line immediately after
`include("pbdbtools/pbdbtools.jl")` and before `end # module`. No other lines
are added, removed, or reordered. The `include` call (not `using` or `import`)
is correct: including a file containing `module PBDBMakie ... end` creates the
sub-module binding in the parent module's namespace at compile time.

**Positive contract:** `isdefined(PaleobiologyDB, :PBDBMakie)` is `true` after
`using PaleobiologyDB` with no Makie backend loaded.

**Negative contract:** No `using PBDBMakie`, no `import PBDBMakie`. No other
lines modified.

**Files:** `src/PaleobiologyDB.jl`

**Out of scope:** All other files.

**Verification:**
```
julia --project=. -e '
using PaleobiologyDB
@assert isdefined(PaleobiologyDB, :PBDBMakie) "PBDBMakie not defined"
@assert PaleobiologyDB.PBDBMakie isa Module "not a Module"
println("Submodule visible: OK")
'
```

---

### 4a. Rename extension directory, rename entry file, and strip `__init__` from module declaration

**Type:** MIGRATE
**Output:** `ext/PBDBMakieExt/PBDBMakieExt.jl` exists with `module PBDBMakieExt`
declaration and no `__init__`; `ext/PBDBMakie/` no longer exists
**Depends on:** Tasks 1, 2, 3

Perform the two git renames and the module-declaration edit. No other content
changes belong in this task.

**Step 1 --- rename directory:**
```
git mv ext/PBDBMakie ext/PBDBMakieExt
```
After this step, all files previously at `ext/PBDBMakie/*` are now at
`ext/PBDBMakieExt/*`, including the implementation files and the PhyloPic
submodule tree. Their content is unchanged.

**Step 2 --- rename entry file:**
```
git mv ext/PBDBMakieExt/PBDBMakie.jl ext/PBDBMakieExt/PBDBMakieExt.jl
```

**Step 3 --- update module declaration:**
Read `ext/PBDBMakieExt/PBDBMakieExt.jl` in full (it is the old `PBDBMakie.jl`
with the new file name). Make exactly two content changes:
- Change `module PBDBMakie` → `module PBDBMakieExt`
- Remove the `function __init__() ... end` block entirely (lines containing
  `function __init__()`, `Core.eval(PaleobiologyDB, :(PBDBMakie = $(@__MODULE__)))`,
  and `end` closing the function). The module-level docstring at the top of the
  file should be updated to reference `PBDBMakieExt` where it previously said
  `PBDBMakie`. No other lines change in this task.

After Step 3, the file still has all its original `import` and `using` statements,
all its `include` calls, and all its `export` lines --- only the module declaration
and `__init__` change. The full content rewrite happens in Task 4b.

**Positive contract:** `ls ext/PBDBMakieExt/PBDBMakieExt.jl` exits 0.
`grep 'module PBDBMakieExt' ext/PBDBMakieExt/PBDBMakieExt.jl` exits 0.
`grep '__init__' ext/PBDBMakieExt/PBDBMakieExt.jl` exits non-zero (absent).
`grep 'Core.eval' ext/PBDBMakieExt/PBDBMakieExt.jl` exits non-zero (absent).

**Negative contract:** `ls ext/PBDBMakie/` exits non-zero (directory gone).
`ls ext/PBDBMakie/PBDBMakie.jl` exits non-zero (old entry file gone).
No implementation files modified. `Project.toml` untouched (already done in Task 1).

**Files:** `ext/PBDBMakie/` (directory rename via `git mv`);
`ext/PBDBMakieExt/PBDBMakieExt.jl` (declaration and `__init__` changes only)

**Out of scope:** Content of `PBDBMakieExt.jl` beyond the declaration line and
`__init__` block; all implementation files; all test files; `src/`.

**Verification:**
```
ls ext/PBDBMakieExt/PBDBMakieExt.jl             # must succeed
ls ext/PBDBMakie/ 2>&1 | grep "No such"         # must show directory gone
grep 'module PBDBMakieExt' ext/PBDBMakieExt/PBDBMakieExt.jl
grep -c '__init__' ext/PBDBMakieExt/PBDBMakieExt.jl      # must print 0
grep -c 'Core.eval' ext/PBDBMakieExt/PBDBMakieExt.jl     # must print 0
```

---

### 4b. Rewrite `PBDBMakieExt.jl` to extend declarations and bridge PhyloPic

**Type:** MIGRATE
**Output:** `ext/PBDBMakieExt/PBDBMakieExt.jl` fully rewritten with correct import
order, PhyloPic bridge, and 10 catch-all delegations; all tests pass with Makie
loaded
**Depends on:** Task 4a

Read `ext/PBDBMakieExt/PBDBMakieExt.jl` (the state left by Task 4a) in full.
Rewrite its body --- between `module PBDBMakieExt` and `end # module PBDBMakieExt` ---
with the following content, in exactly this order:

**Section 1 --- existing imports (unchanged from original):**
```julia
import Makie
import PhyloPicMakie
using Makie: @recipe, Attributes
import Graphs

using PaleobiologyDB
using PaleobiologyDB.Taxonomy: TaxonomyTree, TaxonNode, taxon_subtree
```

**Section 2 --- declaration import block (NEW; must precede ALL include calls):**
```julia
import PaleobiologyDB.PBDBMakie
import PaleobiologyDB.PBDBMakie:
    taxonomytreeplot, taxonomytreeplot!, set_rank_axis_ticks!,
    leaf_positions, augment_leaf_phylopic!,
    acquire_phylopic, augment_phylopic, augment_phylopic!,
    augment_phylopic_ranges, augment_phylopic_ranges!,
    phylopic_images_dataframe, phylopic_node, phylopic_images,
    pbdb_phylopic_grid, pbdb_phylopic_grid!
```
All 15 symbols imported on a single `import` statement. This import is the
critical enabler: when `_recipe.jl` is subsequently included and `@recipe`
expands, `taxonomytreeplot` in `PBDBMakieExt`'s namespace already refers to
`PBDBMakie.taxonomytreeplot`, so `@recipe`'s method is added to the declared
function rather than creating a fresh `PBDBMakieExt.taxonomytreeplot`.
The same mechanism applies to all definitions in the implementation files.

**Section 3 --- PhyloPic submodule and bridge (unchanged include + using + NEW Ref set):**
```julia
include("PhyloPic/src/PhyloPic.jl")
using .PhyloPic
PBDBMakie._PhyloPic[] = PhyloPic
```
The `_PhyloPic[]` assignment sets the Ref declared in the submodule (see Task 2).
This assignment does not use `Core.eval`; setting the contents of a `Ref` is
ordinary mutation, not module-namespace mutation.

**Section 4 --- catch-all delegations for the 10 PhyloPic-sourced symbols (NEW):**
These delegations are necessary because `using .PhyloPic` only aliases
`PhyloPic.*` functions in `PBDBMakieExt`'s namespace; it does not add methods to
`PBDBMakie.*`. Without these delegations, calling `PBDBMakie.acquire_phylopic(...)`
yields a `MethodError` even after Makie loads. Write one function per symbol using
the already-imported names so that each definition is a method extension on the
`PBDBMakie.*` declaration:
```julia
acquire_phylopic(args...; kwargs...)          = PhyloPic.acquire_phylopic(args...; kwargs...)
augment_phylopic(args...; kwargs...)          = PhyloPic.augment_phylopic(args...; kwargs...)
augment_phylopic!(args...; kwargs...)         = PhyloPic.augment_phylopic!(args...; kwargs...)
augment_phylopic_ranges(args...; kwargs...)   = PhyloPic.augment_phylopic_ranges(args...; kwargs...)
augment_phylopic_ranges!(args...; kwargs...)  = PhyloPic.augment_phylopic_ranges!(args...; kwargs...)
phylopic_images_dataframe(args...; kwargs...) = PhyloPic.phylopic_images_dataframe(args...; kwargs...)
phylopic_node(args...; kwargs...)             = PhyloPic.phylopic_node(args...; kwargs...)
phylopic_images(args...; kwargs...)           = PhyloPic.phylopic_images(args...; kwargs...)
pbdb_phylopic_grid(args...; kwargs...)        = PhyloPic.pbdb_phylopic_grid(args...; kwargs...)
pbdb_phylopic_grid!(args...; kwargs...)       = PhyloPic.pbdb_phylopic_grid!(args...; kwargs...)
```

**Section 5 --- implementation file includes (unchanged paths):**
```julia
include("_layout.jl")
include("_leaf_overlay.jl")
include("_recipe.jl")
include("_augment.jl")
```
Because Section 2 imported the 15 declarations before these includes, every
function definition and the `@recipe` expansion in these files extend `PBDBMakie.*`
rather than creating fresh functions in `PBDBMakieExt`.

**Section 6 --- export lines:**
Remove all explicit `export` lines that were present in the original file. The
submodule (`src/PBDBMakie.jl`) owns user-facing exports. The `@recipe` macro
auto-generates `export TaxonomyTreePlot, taxonomytreeplot, taxonomytreeplot!`
within `PBDBMakieExt`'s namespace; that is harmless and not repeated explicitly.

End the module with `end # module PBDBMakieExt`.

**Positive contract:**
- `using CairoMakie; using PaleobiologyDB` loads without error.
- After loading, `PaleobiologyDB.PBDBMakie.taxonomytreeplot` dispatches to the
  Makie-powered implementation.
- `PaleobiologyDB.PBDBMakie._PhyloPic[]` is the `PhyloPic` module (not `nothing`).
- `PaleobiologyDB.PBDBMakie.acquire_phylopic` dispatches to the PhyloPic
  implementation.

**Negative contract:**
- No `Core.eval` anywhere in `PBDBMakieExt.jl`.
- No `__init__` anywhere in `PBDBMakieExt.jl`.
- The import block (Section 2) precedes all `include()` calls (Section 3+).
  If any `include()` call appears before the import block, the `@recipe` and
  implementation-file definitions land in the wrong namespace.
- No implementation files modified.
- No explicit `export` lines for the 15 public symbols (owned by the submodule).

**Files:** `ext/PBDBMakieExt/PBDBMakieExt.jl`

**Out of scope:** All implementation files (`_layout.jl`, `_leaf_overlay.jl`,
`_recipe.jl`, `_augment.jl`, `PhyloPic/src/*`); all test files; `src/`.

**Verification:**
```
grep -c 'Core.eval' ext/PBDBMakieExt/PBDBMakieExt.jl     # must print 0
grep -c '__init__' ext/PBDBMakieExt/PBDBMakieExt.jl       # must print 0
grep 'import PaleobiologyDB.PBDBMakie' ext/PBDBMakieExt/PBDBMakieExt.jl
# Confirm import block precedes first include:
grep -n 'import PaleobiologyDB.PBDBMakie\|^include(' ext/PBDBMakieExt/PBDBMakieExt.jl
# The import line number must be smaller than all include line numbers.
```

---

### 5. Minimal structural adaptations to `test/taxonomytree_makie.jl` and `test/phylopic_makie.jl`

**Type:** TEST
**Output:** Both test files updated to use new access paths; no test logic changed
**Depends on:** Task 4b

**Context --- authorized changes:**
Three groups of references in the test files are structurally incompatible with
the new architecture:
- `PaleobiologyDB.PBDBMakie.PhyloPic` was the extension module's `PhyloPic`
  submodule (accessible because the `Core.eval` hack made `PBDBMakie` the extension
  itself). After migration, `PaleobiologyDB.PBDBMakie` is the unconditional
  submodule, which has no `PhyloPic` field --- only `_PhyloPic` (the Ref bridge
  from Task 2).
- The hardcoded path `"ext", "PBDBMakie", "PhyloPic", "src", "_render.jl"` points
  to the old directory and must be updated to the renamed one.
The following minimal mechanical updates are authorized. No test logic, no new
assertions, no `@testset` additions or removals.

**`test/taxonomytree_makie.jl` --- exactly 3 line changes:**

Line 227 (in `_install_taxon_overlay_stub!`):
```
# BEFORE:
Core.eval(PaleobiologyDB.PBDBMakie.PhyloPic, quote
# AFTER:
Core.eval(PaleobiologyDB.PBDBMakie._PhyloPic[], quote
```

Line 269 (in `_restore_taxon_overlay_impl!`):
```
# BEFORE:
Core.eval(PaleobiologyDB.PBDBMakie.PhyloPic, quote
# AFTER:
Core.eval(PaleobiologyDB.PBDBMakie._PhyloPic[], quote
```

Line 359 (in the `"PBDBMakie --- PBDB bridge delegates anchored overlays"` testset):
```
# BEFORE:
render_source = _read_repo_file("ext", "PBDBMakie", "PhyloPic", "src", "_render.jl")
# AFTER:
render_source = _read_repo_file("ext", "PBDBMakieExt", "PhyloPic", "src", "_render.jl")
```

**`test/phylopic_makie.jl` --- exactly 8 line changes in lines 54--61:**

Line 54:
```
# BEFORE:
@test isdefined(PaleobiologyDB.PBDBMakie, :PhyloPic)
# AFTER:
@test isdefined(PaleobiologyDB.PBDBMakie, :_PhyloPic) && !isnothing(PaleobiologyDB.PBDBMakie._PhyloPic[])
```

Line 55:
```
# BEFORE:
@test PaleobiologyDB.PBDBMakie.PhyloPic isa Module
# AFTER:
@test PaleobiologyDB.PBDBMakie._PhyloPic[] isa Module
```

Lines 56--61 (six lines, each substituting `.PhyloPic)` → `._PhyloPic[])`):
```
# BEFORE (each):
@test :<symbol> ∈ names(PaleobiologyDB.PBDBMakie.PhyloPic)
# AFTER (each):
@test :<symbol> ∈ names(PaleobiologyDB.PBDBMakie._PhyloPic[])
```

Read `test/taxonomytree_makie.jl` and `test/phylopic_makie.jl` in full before
editing. Confirm the exact line numbers and content match what is listed above.
Use exact-string replacement (do not alter surrounding code).

**`test/runtests.jl`** --- do NOT modify. The stale comment at line 29 is Tranche 2 work.

**Positive contract:** After these changes,
`grep 'PBDBMakie\.PhyloPic[^_]' test/taxonomytree_makie.jl test/phylopic_makie.jl`
returns no matches. `grep 'ext.*PBDBMakieExt.*_render' test/taxonomytree_makie.jl`
returns 1 match.

**Negative contract:** No lines changed beyond the 11 listed above (3 in
`taxonomytree_makie.jl`, 8 in `phylopic_makie.jl`). No new `@testset` or `@test`
lines. No changes to `test/runtests.jl` or `test/runaqua.jl`. The LIVE-gated tests
in `taxonomytree_makie.jl` that reference `TaxonomyTreePlot` directly remain
as-is --- their breakage under `PBDB_LIVE=1` is accepted per the settled decision
above.

**Files:** `test/taxonomytree_makie.jl`, `test/phylopic_makie.jl`

**Out of scope:** `test/runtests.jl`, `test/runaqua.jl`, all source and extension files.

**Verification:**
```
grep 'PBDBMakie\.PhyloPic[^_]' test/taxonomytree_makie.jl test/phylopic_makie.jl
# must return no output (old bare access path gone)
grep '_PhyloPic\[\]' test/taxonomytree_makie.jl test/phylopic_makie.jl
# must return 10 matches (2 in taxonomytree, 8 in phylopic)
grep 'PBDBMakieExt' test/taxonomytree_makie.jl
# must return 1 match (the updated _render.jl path)
```

---

### 6. Run full verification pass

**Type:** TEST
**Output:** All automated acceptance criteria met; full test suite and Aqua clean
**Depends on:** Tasks 1--5

Run the following verification commands in order. Each must pass before proceeding
to the next. Do not declare this task complete if any command fails.

**Step 1 --- submodule visible before Makie loads:**
```
julia --project=. -e '
using PaleobiologyDB
@assert isdefined(PaleobiologyDB, :PBDBMakie) "PBDBMakie not bound"
@assert PaleobiologyDB.PBDBMakie isa Module "not a Module"
println("Submodule visible: OK")
'
```

**Step 2 --- declared function yields MethodError before Makie loads:**
```
julia --project=. -e '
using PaleobiologyDB
try
    PaleobiologyDB.PBDBMakie.taxonomytreeplot()
catch e
    @assert e isa MethodError "wrong error type: $(typeof(e))"
    println("MethodError before Makie: OK")
end
'
```

**Step 3 --- absence of Core.eval and __init__ in extension and source:**
```
grep -r 'Core.eval' ext/PBDBMakieExt/ src/   # must return nothing
grep -r '__init__' ext/PBDBMakieExt/           # must return nothing
```

**Step 4 --- full test suite:**
```
julia --project=test test/runtests.jl
```
All tests that were passing before the migration must pass. Any new failure is a
blocker. The LIVE-gated `TaxonomyTreePlot` tests are excluded from standard CI
and need not pass here.

**Step 5 --- Aqua clean:**
```
julia --project=test test/runaqua.jl
```
No new Aqua failures. The pre-existing `stale_deps` exclusion for `PhyloPicMakie`
is still valid and must remain.

**Positive contract:** All five steps complete without error or new failure.

**Negative contract:** Do not mark this task complete if any test that previously
passed now fails. Do not treat a reduced test count as acceptable.

**Files:** None modified; read-only verification run.

**Out of scope:** Writing new tests, modifying sources, committing.

---
