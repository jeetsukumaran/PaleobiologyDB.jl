---
date-created: 2026-04-17T15:30:00
product-requirements: 01_prd.md
---

# Issues: TaxonomyMakie Package Extension

## Issue 1: Strip Makie hard-dep and scaffold empty extension

**Type**: AFK
**Blocked by**: None — can start immediately

### Parent PRD

`01_prd.md`

### What to build

Make `PaleobiologyDB` loadable without the Makie stack. This is a pure structural
change: no visualization functionality is delivered yet.

- Move `PhyloPicMakie` from `[deps]` to `[weakdeps]` in `Project.toml`.
- Add `Makie` to `[weakdeps]` in `Project.toml` (verify UUID via `Pkg` — do not
  assume; see STYLE-julia.md §8).
- Add `[extensions]` section: `TaxonomyMakie = ["Makie", "PhyloPicMakie"]`.
- Retain `[compat]` entries for both `Makie` and `PhyloPicMakie`. Retain the
  `[sources]` git-URL entry for `PhyloPicMakie` (it moves with it to `[weakdeps]`
  but the `[sources]` table is separate).
- Remove `import PhyloPicMakie` from `src/PaleobiologyDB.jl`.
- Remove `include("PhyloPicPBDB/PhyloPicPBDB.jl")` from `src/PaleobiologyDB.jl`.
- Remove `include("TaxonomyTreeMakie/TaxonomyTreeMakie.jl")` from
  `src/PaleobiologyDB.jl`.
- Create `ext/TaxonomyMakie/src/TaxonomyMakie.jl` as a skeleton: `module
  TaxonomyMakie … end` with no imports or exports yet.

`src/TaxonomyTreeMakie/` and `src/PhyloPicPBDB/` are left in place (deleted in
Issue 2). The Makie-dependent tests will be broken after this issue and remain so
until Issue 2 completes.

**STYLE-julia.md constraints:**
- §2.2: the extension module file must be named `TaxonomyMakie.jl`.
- §8: module files declare module + imports only; the skeleton file body is empty
  beyond the module wrapper.
- §7 / §8: do not hand-write UUIDs. Use `Pkg` in a REPL to resolve the Makie UUID
  before editing `Project.toml` directly. Direct `Project.toml` edits are required
  here because `[weakdeps]`, `[extensions]`, and `[sources]` cannot be managed via
  `Pkg` commands — this is the documented exception.

### How to verify

**Automated:**
```
julia --project -e 'using PaleobiologyDB'
```
Must complete without loading Makie (confirm with `julia --project -e 'using
PaleobiologyDB; @assert !isdefined(PaleobiologyDB, :Makie)'`).

**Automated:**
```
julia --project -e 'using Pkg; Pkg.test()'
```
All non-Makie tests pass. Makie-dependent tests (`phylopic_makie.jl`,
`taxonomytree_makie.jl`, `taxonomy_phylopic_acquire.jl`,
`taxonomy_phylopic_images.jl`) are expected to fail/error in this intermediate
state.

### Acceptance criteria

- [ ] Given `using PaleobiologyDB`, the Makie package is not loaded into the Julia
  session.
- [ ] Given `using PaleobiologyDB`, all data-API functions (`pbdb_occurrences`,
  `pbdb_taxa`, `pbdb_taxon`, and taxonomy module functions) are callable.
- [ ] Given `using PaleobiologyDB, PhyloPicMakie`, the extension loads without
  error (empty module — no symbols yet, but no crash).
- [ ] Given `using PaleobiologyDB` without PhyloPicMakie, no error or warning is
  raised about the missing extension.
- [ ] `Project.toml` has no Makie-related entries in `[deps]`.

### User stories addressed

- User story 1: data-API user — no Makie on plain load
- User story 2: data-API user — full data API works without Makie
- User story 11: extension fails safely when PhyloPicMakie absent

---

## Issue 2: Move all Makie code into the extension

**Type**: AFK
**Blocked by**: Issue 1

### Parent PRD

`01_prd.md`

### What to build

Populate the skeleton extension with the full visualization API. This covers both
the PBDB–PhyloPic bridge (formerly `PhyloPicPBDB`) and the tree-visualization code
(formerly `TaxonomyTreeMakie`), and removes both directories from `src/`.

**PhyloPicPBDB — vendor into extension:**

- Create `ext/TaxonomyMakie/src/PhyloPicPBDB/src/`.
- Move the five source files from `src/PhyloPicPBDB/` to
  `ext/TaxonomyMakie/src/PhyloPicPBDB/src/`:
  `PhyloPicPBDB.jl`, `_phylopic_core.jl`, `_resolve.jl`, `_render.jl`,
  `_phylopic_thumbnail_grid.jl`.
- Adapt `PhyloPicPBDB.jl` imports: `Makie` and `PhyloPicDB` are now reached
  through `PhyloPicMakie`, which is available in extension scope — the existing
  aliasing pattern (`const Makie = PhyloPicMakie.Makie`) is preserved, but the
  `import PhyloPicMakie` at the top of `PhyloPicPBDB.jl` may need to become a
  reference to the parent extension's already-imported binding rather than a
  fresh `import`.
- Delete `src/PhyloPicPBDB/`.

**TaxonomyTreeMakie — move into extension:**

- Move `_layout.jl`, `_recipe.jl`, `_augment.jl`, `_phylopic.jl` from
  `src/TaxonomyTreeMakie/` to `ext/TaxonomyMakie/src/`.
- Delete `src/TaxonomyTreeMakie/` (including `TaxonomyTreeMakie.jl`, which is
  superseded by the new `TaxonomyMakie.jl`).

**Wire everything in `TaxonomyMakie.jl`:**

- Replace the skeleton with the full module declaration following STYLE-julia.md §8:
  imports (`Makie`, `PhyloPicMakie`, `Graphs`; access `PaleobiologyDB.Taxonomy`
  via the parent package relationship), then `include` statements, then `export`
  declarations.
- `include("PhyloPicPBDB/src/PhyloPicPBDB.jl")` — loads the vendored submodule.
- `include` the four tree-visualization files.
- Export the combined public API: everything exported by the former
  `TaxonomyTreeMakie` plus everything exported by the former `PhyloPicPBDB`
  (re-export PhyloPicPBDB symbols so users get a flat API surface from
  `using PaleobiologyDB, PhyloPicMakie`).

**STYLE-julia.md constraints:**
- §2.2: `TaxonomyMakie.jl` and `PhyloPicPBDB.jl` are module declaration files;
  their names match their module names exactly.
- §8: module files must only declare the module and its imports/includes. No
  implementation code in the module declaration file itself.
- §8: individual implementation files should stay within 400–600 LOC. The moved
  files are all within range; do not restructure them unless a file exceeds the
  limit.
- §3.6: the vendored `PhyloPicPBDB` is laid out as a full package
  (`PhyloPicPBDB/src/PhyloPicPBDB.jl`), not as a flat file.

### How to verify

**Automated:**
```
julia --project -e '
    using PaleobiologyDB, PhyloPicMakie
    @assert isdefined(PaleobiologyDB, :TaxonomyMakie)
    @assert isdefined(PaleobiologyDB.TaxonomyMakie, :PhyloPicPBDB)
'
```

**Automated (data-bridge):**
```
julia --project -e '
    using PaleobiologyDB, PhyloPicMakie
    # PhyloPicPBDB data API available without a live network call
    @assert isdefined(Main, :acquire_phylopic)
    @assert isdefined(Main, :phylopic_thumbnail_grid)
'
```

**Automated (tree-plot):**
```
julia --project -e '
    using PaleobiologyDB, PaleobiologyDB.Taxonomy, PhyloPicMakie
    @assert isdefined(Main, :taxonomytreeplot)
    @assert isdefined(Main, :set_rank_axis_ticks!)
'
```

**Automated:**
```
julia --project -e 'using Pkg; Pkg.test()'
```
All Makie-dependent test files must now pass (pending the test-suite fix in
Issue 3, the tests themselves may still have import-path errors — see Issue 3).

**Manual:**
```
using PaleobiologyDB, PaleobiologyDB.Taxonomy, PhyloPicMakie, CairoMakie
tree = taxon_subtree("Carnivora"; leaf_rank = "family")
fig, ax, p = taxonomytreeplot(tree; showtips = true)
display(fig)
```
Must produce a dendrogram figure without error.

**Filesystem:**
- `src/TaxonomyTreeMakie/` does not exist.
- `src/PhyloPicPBDB/` does not exist.
- `ext/TaxonomyMakie/src/PhyloPicPBDB/src/PhyloPicPBDB.jl` exists.

### Acceptance criteria

- [ ] Given `using PaleobiologyDB, PhyloPicMakie`, all symbols formerly exported
  by `TaxonomyTreeMakie` are available in `Main`.
- [ ] Given `using PaleobiologyDB, PhyloPicMakie`, all symbols formerly exported
  by `PhyloPicPBDB` are available in `Main`.
- [ ] Given `using PaleobiologyDB` without PhyloPicMakie, none of the Makie
  symbols are defined and no error is raised.
- [ ] `src/TaxonomyTreeMakie/` is deleted.
- [ ] `src/PhyloPicPBDB/` is deleted.
- [ ] `ext/TaxonomyMakie/src/PhyloPicPBDB/` follows the full package layout
  (`src/PhyloPicPBDB.jl` + included implementation files).
- [ ] No file in `ext/TaxonomyMakie/src/` exceeds 600 LOC.

### User stories addressed

- User story 3: extension transparent to visualization user
- User story 4: tree-plot API available after extension loads
- User story 5: PhyloPicPBDB API available after extension loads
- User story 6: STYLE-julia.md conventions followed
- User story 7: vendored PhyloPicPBDB full package layout

---

## Issue 3: Fix test suite for extension architecture

**Type**: AFK
**Blocked by**: Issue 2

### Parent PRD

`01_prd.md`

### What to build

Update the test suite so all tests pass under the new extension architecture.
No test logic changes — only import paths and load order.

- `test/runtests.jl`: remove `const PhyloPicDB = PaleobiologyDB.PhyloPicMakie.PhyloPicDB`
  (this path is invalid — `PhyloPicMakie` is no longer a field of the
  `PaleobiologyDB` module). Replace with a direct import: `import PhyloPicMakie`
  followed by `const PhyloPicDB = PhyloPicMakie.PhyloPicDB`.
- `test/runtests.jl`: ensure `using PaleobiologyDB, PhyloPicMakie` (or equivalent)
  is evaluated before the Makie-dependent test files are `include`d, so the
  extension is loaded and its symbols are defined when those tests run.
- `test/Project.toml`: confirm `Makie` appears as an explicit dependency (add it
  if absent); `PhyloPicMakie` must remain present.
- No test files are deleted or renamed. Test logic inside individual files is
  preserved as-is unless an import path is broken by the refactor.

**STYLE-julia.md constraints:**
- §3.4: one test file per source file. The existing correspondence is already
  correct; this issue preserves it.

### How to verify

**Automated (full suite):**
```
julia --project=test -e 'using Pkg; Pkg.test("PaleobiologyDB")'
```
All test sets green. Zero failures, zero errors.

**Automated (non-Makie subset):**
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
Must pass independently without loading Makie.

**Automated (Makie subset):**
```
julia --project -e '
    using Test, PaleobiologyDB, PhyloPicMakie
    include("test/phylopic_makie.jl")
    include("test/taxonomytree_makie.jl")
    include("test/taxonomy_phylopic_acquire.jl")
    include("test/taxonomy_phylopic_images.jl")
'
```
Must pass after loading PhyloPicMakie (which triggers the extension).

### Acceptance criteria

- [ ] `Pkg.test()` runs all test sets with zero failures and zero errors.
- [ ] Non-Makie test files can be sourced in a session without PhyloPicMakie
  present, without error.
- [ ] Makie-dependent test files can be sourced after `using PhyloPicMakie`,
  without error.
- [ ] `test/runtests.jl` contains no reference to `PaleobiologyDB.PhyloPicMakie`.
- [ ] `test/Project.toml` lists `Makie` as an explicit dependency.

### User stories addressed

- User story 8: tests organized per module
- User story 9: test environment always loads PhyloPicMakie
- User story 10: tests independently runnable per module
