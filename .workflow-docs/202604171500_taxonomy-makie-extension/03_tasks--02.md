---
date-created: 2026-04-17T15:30:00
issue: 02_issues.md#issue-2-move-all-makie-code-into-the-extension
parent-prd: 01_prd.md
---

# Tasks for Issue 2: Move all Makie code into the extension

Parent issue: Issue 2 — `02_issues.md`
Parent PRD: `01_prd.md`

**Prerequisite**: Issue 1 must be complete before beginning this issue.

## Tasks

### 1. Relocate both src/ visualization directories into the extension

**Type**: WRITE
**Output**: `ext/TaxonomyMakie/src/PhyloPicPBDB/src/` contains all 5 PhyloPicPBDB files with adapted imports; `ext/TaxonomyMakie/src/` contains `_layout.jl`, `_recipe.jl`, `_augment.jl`, `_phylopic.jl`; `src/TaxonomyTreeMakie/` is deleted; `src/PhyloPicPBDB/` still exists (deleted in task 2).
**Depends on**: none (Issue 1 complete)

Read every file in `src/PhyloPicPBDB/` and `src/TaxonomyTreeMakie/` in full before moving anything.

**PhyloPicPBDB relocation:** Create `ext/TaxonomyMakie/src/PhyloPicPBDB/src/`. Move the five files — `PhyloPicPBDB.jl`, `_phylopic_core.jl`, `_resolve.jl`, `_render.jl`, `_phylopic_thumbnail_grid.jl` — from `src/PhyloPicPBDB/` to `ext/TaxonomyMakie/src/PhyloPicPBDB/src/`. In the relocated `PhyloPicPBDB.jl`, update any `import PhyloPicMakie` or equivalent top-level import so that `PhyloPicMakie` is accessed via the parent extension module's already-imported binding using the relative path `..PhyloPicMakie` (i.e., `using ..PhyloPicMakie` or `import ..PhyloPicMakie`). The existing aliasing pattern (`const Makie = PhyloPicMakie.Makie`, `const PhyloPicDB = PhyloPicMakie.PhyloPicDB`) is preserved; only the source of the `PhyloPicMakie` binding changes from a fresh package import to a reference to the parent scope. Do not modify any other files in `PhyloPicPBDB/src/`. Do not yet delete `src/PhyloPicPBDB/` — that is done in task 2.

**TaxonomyTreeMakie relocation:** Move `_layout.jl`, `_recipe.jl`, `_augment.jl`, and `_phylopic.jl` from `src/TaxonomyTreeMakie/` to `ext/TaxonomyMakie/src/`. Do not move `TaxonomyTreeMakie.jl` — it is superseded by the new `TaxonomyMakie.jl` and will not be reused. After moving the four implementation files, delete the entire `src/TaxonomyTreeMakie/` directory including the leftover `TaxonomyTreeMakie.jl`.

---

### 2. Populate TaxonomyMakie.jl and delete src/PhyloPicPBDB/

**Type**: WRITE
**Output**: `ext/TaxonomyMakie/src/TaxonomyMakie.jl` is the full module declaration with imports, includes, and combined exports; `src/PhyloPicPBDB/` is deleted.
**Depends on**: 1

Read `ext/TaxonomyMakie/src/TaxonomyMakie.jl` (the skeleton from Issue 1, task 3) and read the relocated implementation files before writing. Replace the skeleton with the full module declaration following STYLE-julia.md §8 — module files declare the module and its imports/includes only; no implementation code in this file.

Structure the module body in this order:

1. **Imports**: `using Makie`, `using PhyloPicMakie`, `using Graphs`. Access `PaleobiologyDB.Taxonomy` through the implicit parent package relationship (do not import PaleobiologyDB explicitly — it is the parent module and its submodules are reachable via the extension relationship).
2. **Includes**: `include("PhyloPicPBDB/src/PhyloPicPBDB.jl")`, then `include("_layout.jl")`, `include("_recipe.jl")`, `include("_augment.jl")`, `include("_phylopic.jl")`.
3. **Exports**: Export the combined public API — all symbols formerly exported by `TaxonomyTreeMakie` (`TaxonomyTreePlot`, `taxonomytreeplot`, `taxonomytreeplot!`, `set_rank_axis_ticks!`, `tip_positions`, `augment_tip_phylopic!`) plus all symbols formerly exported by `PhyloPicPBDB` (`acquire_phylopic`, `augment_phylopic`, `augment_phylopic!`, `augment_phylopic_ranges!`, `augment_phylopic_ranges`, `phylopic_images_dataframe`, `phylopic_node`, `phylopic_images`, `phylopic_thumbnail_grid!`, `phylopic_thumbnail_grid`). Re-export the `PhyloPicPBDB` submodule symbols so users get a flat API surface from `using PaleobiologyDB, PhyloPicMakie`. Verify the exact export lists by reading the existing `src/TaxonomyTreeMakie/TaxonomyTreeMakie.jl` and `src/PhyloPicPBDB/PhyloPicPBDB.jl` before writing — do not rely solely on the PRD list.

After saving `TaxonomyMakie.jl`, delete `src/PhyloPicPBDB/` and all its contents.

---

### 3. Run full verification suite

**Type**: TEST
**Output**: All three automated verification assertions pass; `Pkg.test()` runs to completion; any remaining failures are import-path issues scoped to Issue 3.
**Depends on**: 2

Run each of the following and report the actual output:

```
julia --project -e '
    using PaleobiologyDB, PhyloPicMakie
    @assert isdefined(PaleobiologyDB, :TaxonomyMakie)
    @assert isdefined(PaleobiologyDB.TaxonomyMakie, :PhyloPicPBDB)
'
```

```
julia --project -e '
    using PaleobiologyDB, PhyloPicMakie
    @assert isdefined(Main, :acquire_phylopic)
    @assert isdefined(Main, :phylopic_thumbnail_grid)
'
```

```
julia --project -e '
    using PaleobiologyDB, PaleobiologyDB.Taxonomy, PhyloPicMakie
    @assert isdefined(Main, :taxonomytreeplot)
    @assert isdefined(Main, :set_rank_axis_ticks!)
'
```

Run `julia --project -e 'using Pkg; Pkg.test()'` and report which test sets pass and which fail. Failures in `runtests.jl` due to the broken `PaleobiologyDB.PhyloPicMakie.PhyloPicDB` reference are expected and are fixed in Issue 3 — note them but do not fix them here.

Verify filesystem state:
- `src/TaxonomyTreeMakie/` does not exist
- `src/PhyloPicPBDB/` does not exist
- `ext/TaxonomyMakie/src/PhyloPicPBDB/src/PhyloPicPBDB.jl` exists
- No file in `ext/TaxonomyMakie/src/` exceeds 600 lines (check with `wc -l`)
