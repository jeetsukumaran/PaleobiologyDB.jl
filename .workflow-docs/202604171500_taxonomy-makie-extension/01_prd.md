---
date-created: 2026-04-17T15:00:00
---

# PRD: TaxonomyMakie Package Extension

## User statement

> Paleobiology.jl currently:
> - has PhyloPicMakie as a hard dep
> - bundles TaxonomyTreeMakie and PhyloPicPBDB as source submodules
>
> After:
> - PhyloPicMakie will be a weak dep
> - TaxonomyMakie is a PaleobiologyDB.jl package extension that is triggered on Makie
>     - has PhyloPicMakie as hard dependency

## Problem statement

PaleobiologyDB.jl forces every user to compile the full Makie stack (via the
PhyloPicMakie hard dependency), even users who only need the PBDB data API.
Makie is large and slow to precompile. This imposes an unnecessary compile-time
and install-time cost on the majority of users, who do not use any visualization
features.

Additionally, TaxonomyTreeMakie and PhyloPicPBDB are embedded as source submodules
inside the main package tree (`src/`), making them structurally inseparable from the
core package even though they depend on the Makie stack.

## Solution

When the feature is complete, the following will be true:

1. `PaleobiologyDB.jl` has no Makie dependency. Users who only use the data API
   install and precompile only the lightweight core.
2. A Julia package extension named `TaxonomyMakie` lives in `ext/TaxonomyMakie/`
   and activates automatically when both `Makie` and `PhyloPicMakie` are loaded
   alongside `PaleobiologyDB`.
3. `TaxonomyMakie` contains the full tree-visualization API (moved from
   `TaxonomyTreeMakie`) and the PBDB–PhyloPic bridge (moved from `PhyloPicPBDB`,
   vendored as a submodule inside the extension).
4. `PhyloPicMakie` is declared in `[weakdeps]`; `Makie` is also in `[weakdeps]`
   as the co-trigger.
5. All existing functionality is preserved — users who do load PhyloPicMakie get
   the same API as before.
6. The test suite runs all tests (including Makie-based extension tests) by default,
   because the test environment explicitly loads PhyloPicMakie.

## User stories

1. As a data-API user, I want `using PaleobiologyDB` to not require Makie, so that
   installation and precompilation are fast.
2. As a data-API user, I want all taxonomy, occurrence, collection, specimen, and
   reference query functions to work without loading Makie, so that I can use the
   full PBDB data API immediately.
3. As a visualization user, I want the full TaxonomyTreeMakie and PhyloPicPBDB API
   to be available after `using PaleobiologyDB, PhyloPicMakie` without any
   additional setup, so that the extension is transparent to me.
4. As a visualization user, I want `taxonomytreeplot`, `taxonomytreeplot!`,
   `set_rank_axis_ticks!`, `tip_positions`, and `augment_tip_phylopic!` to be
   exported and callable after the extension loads, so that my existing code
   continues to work.
5. As a visualization user, I want `acquire_phylopic`, `augment_phylopic`,
   `augment_phylopic!`, `augment_phylopic_ranges!`, `phylopic_thumbnail_grid`,
   and related PBDB–PhyloPic functions to be available after the extension loads,
   so that my existing code continues to work.
6. As a contributor, I want the extension to follow STYLE-julia.md conventions
   (module file = module name, separate files per concept, 400–600 LOC limit),
   so that the codebase remains consistent.
7. As a contributor, I want the vendored `PhyloPicPBDB` submodule inside the
   extension to be laid out as a full package (`PhyloPicPBDB/src/PhyloPicPBDB.jl`
   + included files), so that it is easy to read and maintain.
8. As a contributor, I want tests to be organized per STYLE-julia.md §3.4
   (one test file per source file), so that Makie-based and non-Makie tests
   are clearly separated.
9. As a contributor, I want the test environment to always load PhyloPicMakie, so
   that all tests including extension tests run by default without special flags.
10. As a CI system, I want tests to be independently runnable per module (e.g.,
    sourcing only taxonomy tests or only Makie tests), so that test suites can
    be decoupled when needed.
11. As a new contributor, I want the extension trigger to fail safely (not load
    if PhyloPicMakie is missing), so that partial-environment errors produce clear
    diagnostics rather than cryptic method-not-found errors.

## Implementation decisions

### Dependency topology

- `PhyloPicMakie` moves from `[deps]` to `[weakdeps]` in `Project.toml`.
- `Makie` is added to `[weakdeps]` in `Project.toml` as the primary semantic
  trigger.
- `[extensions]` declares: `TaxonomyMakie = ["Makie", "PhyloPicMakie"]`.
  The co-trigger ensures the extension only loads when both packages are
  available, preventing runtime errors if only one is loaded.
- `[compat]` retains entries for both `Makie` and `PhyloPicMakie`.
- No Makie-related packages remain in `[deps]`.

### Extension layout

The extension follows the "full package layout" convention from STYLE-julia.md:

```
ext/
  TaxonomyMakie/
    src/
      TaxonomyMakie.jl          ← module declaration + imports + includes
      _layout.jl                ← tree layout algorithms (from TaxonomyTreeMakie)
      _recipe.jl                ← Makie @recipe (from TaxonomyTreeMakie)
      _augment.jl               ← augmentation helpers (from TaxonomyTreeMakie)
      _phylopic.jl              ← phylopic-tree integration (from TaxonomyTreeMakie)
      PhyloPicPBDB/             ← vendored submodule (full package layout)
        src/
          PhyloPicPBDB.jl       ← module declaration
          _phylopic_core.jl     ← data API (no Makie)
          _resolve.jl           ← PBDB → PhyloPic resolution
          _render.jl            ← Makie rendering
          _phylopic_thumbnail_grid.jl ← gallery UI
```

Per STYLE-julia.md §2.2 the module declaration file name matches the module name
(`TaxonomyMakie.jl`, `PhyloPicPBDB.jl`). Per §8, module files declare the module
and its imports only; all implementation code lives in included files.

### Module structure

`TaxonomyMakie` is the extension module. It:
- Imports `Makie`, `PhyloPicMakie`, `Graphs`, and accesses `PaleobiologyDB.Taxonomy`
  via the implicit parent package relationship.
- Includes `PhyloPicPBDB/src/PhyloPicPBDB.jl` as a vendored submodule.
- Includes `_layout.jl`, `_recipe.jl`, `_augment.jl`, `_phylopic.jl`.
- Exports all public symbols from both the former `TaxonomyTreeMakie` and
  `PhyloPicPBDB` modules combined.

`PhyloPicPBDB` is a named submodule inside `TaxonomyMakie`. Its public API is
re-exported from `TaxonomyMakie` directly to preserve the flat API surface users
expect from `using PaleobiologyDB, PhyloPicMakie`.

### What stays in the main package

- `src/PaleobiologyDB.jl` — removes `import PhyloPicMakie`, removes
  `include("PhyloPicPBDB/...")`, removes `include("TaxonomyTreeMakie/...")`.
- `src/dbapi.jl` — unchanged.
- `src/pbdbdocs.jl` — unchanged.
- `src/pbdbtools/` (taxonomy) — unchanged.

### What is removed from src/

- `src/TaxonomyTreeMakie/` — entire directory deleted.
- `src/PhyloPicPBDB/` — entire directory deleted.

### Test environment

- `test/Project.toml` gains explicit `Makie` dependency (if not already present)
  and retains `PhyloPicMakie`.
- `test/runtests.jl`: removes `const PhyloPicDB = PaleobiologyDB.PhyloPicMakie.PhyloPicDB`
  (no longer accessible via parent); replaces with direct import from PhyloPicMakie.
- Test files for Makie features (`phylopic_makie.jl`, `taxonomytree_makie.jl`)
  are included after PhyloPicMakie is loaded in `runtests.jl`, triggering the
  extension before the tests execute.
- All tests run by default; no gating flag needed since the test environment always
  has PhyloPicMakie.
- File-per-module correspondence (STYLE-julia.md §3.4): test files mirror extension
  source files (e.g., `test/taxonomytree_makie.jl` covers `_recipe.jl` and related
  files; `test/phylopic_makie.jl` covers PhyloPicPBDB rendering).

### STYLE-julia.md compliance

All changes follow STYLE-julia.md:
- §2.2: module file name = module name (`TaxonomyMakie.jl`, `PhyloPicPBDB.jl`)
- §8: module files declare module + imports only; implementation in included files
- §8: files target 400–600 LOC; existing files are within range
- §3.4: one test file per source module
- §3.6: vendored submodule laid out as a package

## Module design

### TaxonomyMakie (extension root module)

- **Name**: `TaxonomyMakie`
- **Responsibility**: Package extension entry point; aggregates tree visualization
  and PBDB–PhyloPic bridge; exports the combined public API.
- **Interface**: Exports `TaxonomyTreePlot`, `taxonomytreeplot`, `taxonomytreeplot!`,
  `set_rank_axis_ticks!`, `tip_positions`, `augment_tip_phylopic!`, plus all
  PhyloPicPBDB symbols (`acquire_phylopic`, `augment_phylopic`, `augment_phylopic!`,
  `augment_phylopic_ranges!`, `augment_phylopic_ranges`, `phylopic_images_dataframe`,
  `phylopic_node`, `phylopic_images`, `phylopic_thumbnail_grid!`,
  `phylopic_thumbnail_grid`).
- **Failure mode**: Does not load if either `Makie` or `PhyloPicMakie` is absent.
  Users get a standard `MethodError` rather than a cryptic import failure.
- **Tested**: Yes.

### PhyloPicPBDB (vendored submodule inside TaxonomyMakie)

- **Name**: `PhyloPicPBDB`
- **Responsibility**: PBDB-specific PhyloPic integration — data API (name resolution,
  metadata acquisition) and Makie rendering wrappers.
- **Interface**: Same exports as the current `PhyloPicPBDB` source submodule.
  Re-exported from `TaxonomyMakie`.
- **Failure mode**: Never instantiated independently; always loaded through
  `TaxonomyMakie`.
- **Tested**: Yes (via `phylopic_makie.jl`, `taxonomy_phylopic_acquire.jl`,
  `taxonomy_phylopic_images.jl`).

### Included files in TaxonomyMakie (not separate modules)

- `_layout.jl` — tree layout algorithms; no exported symbols; called internally
  by `_recipe.jl`.
- `_recipe.jl` — defines `TaxonomyTreePlot` `@recipe` and `taxonomytreeplot[!]`.
- `_augment.jl` — defines `augment_tip_phylopic!` and helpers.
- `_phylopic.jl` — PhyloPic silhouette placement at tree leaf tips.

## Testing decisions

A good test for this feature verifies:
1. `using PaleobiologyDB` loads without error and does NOT expose Makie symbols.
2. `using PaleobiologyDB, PhyloPicMakie` triggers the extension and exposes
   `taxonomytreeplot`, `augment_phylopic!`, etc.
3. All existing tree-plot and phylopic tests continue to pass unchanged.

Modules with tests:
- `TaxonomyMakie` — `test/taxonomytree_makie.jl`
- `PhyloPicPBDB` — `test/phylopic_makie.jl`, `test/taxonomy_phylopic_acquire.jl`,
  `test/taxonomy_phylopic_images.jl`

Prior art: existing test files under `test/` are the reference; their structure is
preserved and only import paths change.

## Out of scope

- Splitting `PhyloPicPBDB` data layer into a separate top-level package.
- Removing `Graphs` from the main package (it is used by the taxonomy module).
- Adding any new visualization features.
- Changes to the PBDB data API (`dbapi.jl`, `pbdbtools/`).
- Moving `DataCaches` to a weak dependency.
- Changes to docs build or Quarto notebooks.

## Open questions

None. All questions resolved during the interview session (2026-04-17).

## Further notes

- The `[sources]` entry for `PhyloPicMakie` moves with it from `[deps]` to
  `[weakdeps]` — it remains a git-URL source dep.
- The `Makie` UUID must be verified before editing `Project.toml` directly
  (per STYLE-julia.md §7 and §8, do not assume UUIDs). The UUID
  `"ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"` appears in the General registry but
  must be confirmed.
- STYLE-julia.md §7 prefers `Pkg.add`/`Pkg.rm` over direct `Project.toml` edits.
  However, the `[weakdeps]`, `[extensions]`, and `[sources]` table entries cannot
  be managed via `Pkg` commands alone; direct edits are required and are acceptable
  per the "unless there is no other way" clause.
- After the refactor, `PaleobiologyDB.PhyloPicMakie` is no longer accessible
  (PhyloPicMakie is a weakdep, not a dep). Any code or tests that navigated
  `PaleobiologyDB.PhyloPicMakie.*` must be updated to import PhyloPicMakie
  directly.
