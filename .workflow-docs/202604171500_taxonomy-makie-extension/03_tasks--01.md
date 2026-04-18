---
date-created: 2026-04-17T15:30:00
issue: 02_issues.md#issue-1-strip-makie-hard-dep-and-scaffold-empty-extension
parent-prd: 01_prd.md
---

# Tasks for Issue 1: Strip Makie hard-dep and scaffold empty extension

Parent issue: Issue 1 — `02_issues.md`
Parent PRD: `01_prd.md`

## Tasks

### 1. Update Project.toml: declare weak dependencies and extension

**Type**: WRITE
**Output**: `Project.toml` has `[weakdeps]` containing both `PhyloPicMakie` and `Makie`, an `[extensions]` table declaring `TaxonomyMakie = ["Makie", "PhyloPicMakie"]`, no Makie-related entries in `[deps]`, and all existing `[compat]` and `[sources]` entries intact.
**Depends on**: none

Read `Project.toml` in full before editing. Move the `PhyloPicMakie` entry from `[deps]` to a new `[weakdeps]` section. Add `Makie` to `[weakdeps]` using the UUID `"ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"` — this UUID is already confirmed in `test/Project.toml` and must be verified against that file before writing (do not assume it). Add an `[extensions]` section with a single entry: `TaxonomyMakie = ["Makie", "PhyloPicMakie"]`. Leave the `[compat]` entries for both `Makie` and `PhyloPicMakie` exactly as they are. Leave the `[sources]` entry for `PhyloPicMakie` exactly as it is — the `[sources]` table is separate from `[deps]`/`[weakdeps]` and is unaffected by this move. Do not add, remove, or reorder any other entries.

---

### 2. Strip Makie imports from src/PaleobiologyDB.jl

**Type**: WRITE
**Output**: `src/PaleobiologyDB.jl` contains no reference to `PhyloPicMakie`, `PhyloPicPBDB`, or `TaxonomyTreeMakie`; the file otherwise unchanged; source directories left in place.
**Depends on**: 1

Read `src/PaleobiologyDB.jl` in full before editing. Remove the line `import PhyloPicMakie`. Remove the line `include("PhyloPicPBDB/PhyloPicPBDB.jl")`. Remove the line `include("TaxonomyTreeMakie/TaxonomyTreeMakie.jl")`. Do not touch any other lines, including the commented-out line above `import PhyloPicMakie` — leave it as-is. Do not delete or modify `src/PhyloPicPBDB/` or `src/TaxonomyTreeMakie/`; those directories are removed in Issue 2.

---

### 3. Create ext/TaxonomyMakie/src/TaxonomyMakie.jl skeleton

**Type**: WRITE
**Output**: `ext/TaxonomyMakie/src/TaxonomyMakie.jl` exists as a bare module wrapper with no imports, exports, or implementation.
**Depends on**: 1

Create the directory path `ext/TaxonomyMakie/src/` under the project root. Inside it, create `TaxonomyMakie.jl` containing only a module declaration: `module TaxonomyMakie … end` with nothing inside the module body. Follow STYLE-julia.md §2.2 (module file name must match module name exactly: `TaxonomyMakie.jl`) and §8 (module file body is empty beyond the wrapper at this stage — no imports, no includes, no exports).

---

### 4. Verify non-Makie load and run baseline tests

**Type**: TEST
**Output**: `using PaleobiologyDB` loads without Makie; the non-Makie test sets pass; Makie-dependent test files fail or error as expected in this intermediate state.
**Depends on**: 2, 3

Run each of the following and report the actual output, not a prediction:

```
julia --project -e 'using PaleobiologyDB'
```
Must complete without error.

```
julia --project -e 'using PaleobiologyDB; @assert !isdefined(PaleobiologyDB, :Makie)'
```
Must pass (no AssertionError).

```
julia --project -e 'using Pkg; Pkg.test()'
```
The test sets `taxonomy_resolution`, `taxonomy_namevalidation`, `taxonomy_queries_basic`, `taxonomy_queries_hierarchy`, and `taxonomy_graphs` must pass. The four Makie-dependent test files (`phylopic_makie.jl`, `taxonomytree_makie.jl`, `taxonomy_phylopic_acquire.jl`, `taxonomy_phylopic_images.jl`) are expected to fail or error in this intermediate state — that is acceptable and documented in the issue. Report which test sets pass and which fail.
