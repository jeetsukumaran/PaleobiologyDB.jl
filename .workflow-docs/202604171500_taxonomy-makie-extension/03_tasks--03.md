---
date-created: 2026-04-17T15:30:00
issue: 02_issues.md#issue-3-fix-test-suite-for-extension-architecture
parent-prd: 01_prd.md
---

# Tasks for Issue 3: Fix test suite for extension architecture

Parent issue: Issue 3 — `02_issues.md`
Parent PRD: `01_prd.md`

**Prerequisite**: Issue 2 must be complete before beginning this issue.

## Tasks

### 1. Fix PhyloPicDB import path and extension load order in test/runtests.jl

**Type**: WRITE
**Output**: `test/runtests.jl` loads `PhyloPicMakie` directly (triggering the extension), `PhyloPicDB` is re-bound from `PhyloPicMakie` directly, and all Makie-dependent `include` calls occur after the extension is loaded. `test/Project.toml` is unchanged (Makie is already listed).
**Depends on**: none (Issue 2 complete)

Read `test/runtests.jl` in full before editing. Make the following targeted changes — do not alter any test logic, test set structure, or any other lines:

1. Remove the line `const PhyloPicDB = PaleobiologyDB.PhyloPicMakie.PhyloPicDB`. This path is invalid after the refactor: `PhyloPicMakie` is no longer a field of the `PaleobiologyDB` module.
2. Add `import PhyloPicMakie` immediately after the existing `using PaleobiologyDB` line. This triggers the `TaxonomyMakie` extension so that all extension symbols are defined before any Makie-dependent test files are included.
3. Add `const PhyloPicDB = PhyloPicMakie.PhyloPicDB` in place of the removed line, using the now-directly-imported `PhyloPicMakie` binding.
4. Confirm that all four Makie-dependent test includes (`taxonomy_phylopic_acquire.jl`, `taxonomy_phylopic_images.jl`, `phylopic_makie.jl`, `taxonomytree_makie.jl`) appear after the `import PhyloPicMakie` line. If any appear before it, move them to after it.

Read `test/Project.toml` and confirm `Makie` is already listed as a dependency. No edit is required.

---

### 2. Run full test suite and confirm all sets pass

**Type**: TEST
**Output**: `Pkg.test()` completes with zero failures and zero errors; non-Makie and Makie subsets confirmed independently runnable; no reference to `PaleobiologyDB.PhyloPicMakie` remains in `test/runtests.jl`.
**Depends on**: 1

Run the full suite and report the actual output:

```
julia --project=test -e 'using Pkg; Pkg.test("PaleobiologyDB")'
```
All test sets must be green — zero failures, zero errors.

Confirm the non-Makie subset passes independently (no PhyloPicMakie loaded):

```
julia --project -e '
    using Test, PaleobiologyDB
    include("test/taxonomy_resolution.jl")
    include("test/taxonomy_namevalidation.jl")
    include("test/taxonomy_queries_basic.jl")
    include("test/taxonomy_queries_hierarchy.jl")
    include("test/taxonomy_graphs.jl")
'
```

Confirm the Makie subset passes after loading PhyloPicMakie:

```
julia --project -e '
    using Test, PaleobiologyDB, PhyloPicMakie
    include("test/phylopic_makie.jl")
    include("test/taxonomytree_makie.jl")
    include("test/taxonomy_phylopic_acquire.jl")
    include("test/taxonomy_phylopic_images.jl")
'
```

Grep `test/runtests.jl` for `PaleobiologyDB.PhyloPicMakie` and confirm zero matches.
