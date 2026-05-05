---
date-created: 2026-05-04T21:01:00
---

# PRD: PBDBMakie unconditional stub submodule

## User statement

Treat the third extension pattern option as the product to be delivered: the
main package exports a public submodule `PBDBMakie` unconditionally (not as an
extension), and the extension mechanism adds concrete method implementations to
the function stubs defined in that submodule.

## Problem statement

`PBDBMakie` is a Julia package extension (`ext/PBDBMakie/`) triggered when any
Makie backend is loaded. The extension provides all tree-visualization and
PhyloPic bridge functions. Because Julia's extension system does not
automatically make extension modules accessible as sub-module bindings of the
parent package, the extension's `__init__` function uses an undocumented hack:

```julia
function __init__()
    Core.eval(PaleobiologyDB, :(PBDBMakie = $(@__MODULE__)))
end
```

This injects the extension module itself as a runtime binding into
`PaleobiologyDB`, making `using PaleobiologyDB.PBDBMakie` work.

The hack has four concrete problems:

1. **Undocumented**: `Core.eval` mutation of a foreign module's namespace is not
   a supported API. Its continued behavior is not guaranteed.
2. **Tooling-invisible**: before the hack runs (i.e., before Makie is loaded),
   `PBDBMakie` does not exist as a binding in `PaleobiologyDB`. Tab-completion,
   `names()`, documentation generators, and IDE introspection cannot see it.
3. **Fragile**: the binding is injected at extension load time, not at package
   definition time. Any tool that inspects `PaleobiologyDB` before loading Makie
   sees no `PBDBMakie` submodule.
4. **Migration-hostile**: promoting `PBDBMakie` to a separately registered
   package requires a redesign regardless; the hack buys nothing toward that goal.

## Target outcome

When this work is complete:

- `src/PBDBMakie.jl` unconditionally defines `module PBDBMakie` as a genuine
  compile-time sub-module of `PaleobiologyDB`
- `src/PaleobiologyDB.jl` includes `PBDBMakie.jl`, so the binding exists
  from the moment `PaleobiologyDB` is loaded
- All public API functions (`taxonomytreeplot`, `taxonomytreeplot!`,
  `set_rank_axis_ticks!`, `leaf_positions`, `augment_leaf_phylopic!`,
  `acquire_phylopic`, `augment_phylopic`, `augment_phylopic!`,
  `augment_phylopic_ranges`, `augment_phylopic_ranges!`,
  `phylopic_images_dataframe`, `phylopic_node`, `phylopic_images`,
  `pbdb_phylopic_grid`, `pbdb_phylopic_grid!`) are stubbed in the unconditional
  module and throw a user-friendly error before Makie is loaded
- The extension is renamed `PBDBMakieExt` and adds concrete method
  implementations to those stubs when Makie loads
- The `Core.eval` hack is removed entirely
- `using PaleobiologyDB.PBDBMakie` works natively via the real sub-module binding
- A new test verifies pre-Makie stub accessibility and error behavior
- All existing tests continue to pass

## User stories

1. A user runs `using PaleobiologyDB` (no Makie loaded) and sees `PBDBMakie`
   in tab-completion and `names(PaleobiologyDB)`.
2. A user calls `PaleobiologyDB.PBDBMakie.taxonomytreeplot(tree)` before loading
   any Makie backend and receives: `ERROR: Load a Makie backend first:
   \`using CairoMakie\``.
3. A user calls `using CairoMakie; using PaleobiologyDB;
   using PaleobiologyDB.PBDBMakie` and all tree visualization and PhyloPic
   bridge functions work identically to the current behavior.
4. A user writes `using PBDBMakie` (bare package name, no module path) and
   receives Julia's standard package-not-found error. This is the documented
   limitation until `PBDBMakie` is separately registered; it is out of scope
   for this PRD.
5. A documentation tool introspects `PaleobiologyDB.PBDBMakie` without Makie
   loaded and sees the exported stub functions and their docstrings.
6. A downstream test suite verifies that `PBDBMakie` is defined as a module
   before Makie is loaded and that stubs throw the expected error.
7. A user calls `taxonomytreeplot(tree)` after loading Makie and receives a
   `FigureAxisPlot` exactly as before.
8. A user calls `augment_leaf_phylopic!(ax, p)` after loading Makie and the
   PhyloPic overlay renders correctly, exactly as before.
9. A user attempts to type-annotate `::TaxonomyTreePlot` without loading Makie
   and receives an `UndefVarError` --- this is an accepted limitation since
   `TaxonomyTreePlot` is a `@recipe`-generated type that cannot exist without
   Makie.

## Authorized disruption boundary

- **Internal redesign allowed**: rename extension module from `PBDBMakie` to
  `PBDBMakieExt`; rename directory `ext/PBDBMakie/` to `ext/PBDBMakieExt/`;
  update `Project.toml [extensions]` entry; add `src/PBDBMakie.jl`; modify
  `src/PaleobiologyDB.jl` to include it; restructure extension to extend stub
  functions rather than define them from scratch; remove `__init__` hack
- **Internal redesign forbidden**: no changes to public API function names,
  argument signatures, or behaviors; no changes to the taxonomy or PBDB data API
- **External breaking changes allowed**: none --- `using PaleobiologyDB.PBDBMakie`
  continues to work; all user-facing behavior is preserved
- **Required migration or compatibility obligations**: none for end users;
  the package is at `2.0.0-DEV`
- **Non-negotiable protections**: all existing `taxonomytree_makie.jl` and
  `phylopic_makie.jl` tests must continue to pass; `runaqua.jl` must remain clean

## Current-state architecture

### Existing owners and structure

```
src/
├── PaleobiologyDB.jl          # no mention of PBDBMakie
├── dbapi.jl
├── pbdbdocs.jl
└── pbdbtools/
    └── _taxonomy/
        └── _taxonomygraphs.jl # defines TaxonomyTree, TaxonNode, taxon_subtree

ext/PBDBMakie/
├── PBDBMakie.jl               # module PBDBMakie; __init__ hack here
├── _layout.jl                 # pure layout math
├── _leaf_overlay.jl           # leaf overlay planning
├── _recipe.jl                 # @recipe TaxonomyTreePlot
├── _augment.jl                # augment_leaf_phylopic!
└── PhyloPic/src/
    ├── PhyloPic.jl
    ├── _phylopic_core.jl      # data API; no Makie dependency
    ├── _resolve.jl            # Makie-dependent
    ├── _render.jl             # Makie-dependent
    └── _pbdb_phylopic_grid.jl # Makie-dependent
```

`Project.toml`:

```toml
[extensions]
PBDBMakie = "Makie"
```

### Failure modes

- `Core.eval` on a foreign module's namespace: undocumented, unsupported
- `PBDBMakie` is invisible to tooling before Makie is loaded
- No migration path toward separate package registration without redesign
- Users get `MethodError` (no context) if stubs are called before the extension
  loads through any path that bypasses the `__init__` binding

## Target architecture

### Major modules

**`src/PBDBMakie.jl`** --- new file

- Declares `module PBDBMakie`
- Unconditionally loaded by `PaleobiologyDB.jl` via `include("PBDBMakie.jl")`
- Defines function stubs for all public API symbols (see module design below)
- Each stub is a catch-all varargs function that throws a user-friendly error
- Exports the same symbol list as the current extension, excluding
  `TaxonomyTreePlot` (which is `@recipe`-generated and cannot be pre-defined)
- No Makie import; no dependency on any optional package

**`ext/PBDBMakieExt/PBDBMakieExt.jl`** --- renamed from `ext/PBDBMakie/PBDBMakie.jl`

- Extension module name: `PBDBMakieExt` (renamed to avoid collision with the
  stub module `PBDBMakie`)
- Triggered when any Makie backend is loaded
- Imports `PaleobiologyDB.PBDBMakie` and adds concrete method implementations
  to the stubs defined there
- Contains `@recipe` definition for `TaxonomyTreePlot`
- Includes same implementation files (`_layout.jl`, `_leaf_overlay.jl`,
  `_recipe.jl`, `_augment.jl`, `PhyloPic/src/`)
- No `__init__` function; no `Core.eval` hack

**`src/PaleobiologyDB.jl`** --- modified

- Adds `include("PBDBMakie.jl")` after existing includes
- `PBDBMakie` becomes a genuine compile-time sub-module binding

**`Project.toml`** --- modified

```toml
[extensions]
PBDBMakieExt = "Makie"
```

### Ownership boundaries

| Owner | Owns |
|---|---|
| `PBDBMakie` (stub submodule) | Public API symbol definitions; stub error behavior; exports |
| `PBDBMakieExt` (extension) | Concrete implementations; `@recipe` type; Makie integration; PhyloPic bridge |

### Shared contracts and invariants

- `using PaleobiologyDB.PBDBMakie` is the canonical user-facing import form
- All stub functions must throw an `ErrorException` with a message containing
  `` `using CairoMakie` `` before Makie is loaded
- After Makie is loaded, the extension's concrete methods take dispatch precedence
  over the catch-all stubs; no stubs are manually removed or replaced
- `TaxonomyTreePlot` is defined only in `PBDBMakieExt` and is accessible only
  after Makie is loaded

## Implementation decisions

1. **No type stubs**: `TaxonomyTreePlot` is a `@recipe`-generated type and
   cannot be pre-defined without Makie. It is not exported from the stub module.
   Users who need to reference it must have Makie loaded.

2. **PhyloPic stays extension-only**: `acquire_phylopic`, `augment_phylopic!`,
   and all other PhyloPic bridge functions remain inside `PBDBMakieExt`. Moving
   the data API to unconditional loading is out of scope for this PRD.

3. **Catch-all stub pattern**: Each stub is defined as:

   ```julia
   function taxonomytreeplot(args...; kwargs...)
       error("Load a Makie backend first: `using CairoMakie`")
   end
   ```

   After Makie loads, the extension adds concrete typed methods that take
   dispatch precedence over the catch-all. This is valid Julia: concrete-type
   methods win over `args...`.

4. **Extension renamed to `PBDBMakieExt`**: Avoids a naming collision between
   the stub sub-module (`module PBDBMakie` in `src/`) and the extension
   implementation module. Follows the conventional Julia `XExt` naming for
   package extensions.

5. **`PBDBMakie` not in `PaleobiologyDB` exports**: Users write
   `using PaleobiologyDB.PBDBMakie` explicitly. The sub-module is accessible
   via dot-notation without polluting the main `using PaleobiologyDB` namespace.

6. **`using PBDBMakie` (bare) not supported**: Bare package-name access requires
   separate registration. Out of scope. Documented as a future migration path.

## Module design

### PBDBMakie --- `src/PBDBMakie.jl`

**Responsibility**: Unconditional stub module; makes `PaleobiologyDB.PBDBMakie`
a real compile-time binding visible to tooling without Makie.

**Interface --- exported stubs** (catch-all, throw error before Makie):

Tree visualization:

- `taxonomytreeplot`
- `taxonomytreeplot!`
- `set_rank_axis_ticks!`
- `leaf_positions`
- `augment_leaf_phylopic!`

PhyloPic bridge:

- `acquire_phylopic`
- `augment_phylopic`
- `augment_phylopic!`
- `augment_phylopic_ranges`
- `augment_phylopic_ranges!`
- `phylopic_images_dataframe`
- `phylopic_node`
- `phylopic_images`
- `pbdb_phylopic_grid`
- `pbdb_phylopic_grid!`

Not stubbed (type, requires `@recipe`): `TaxonomyTreePlot`

**Tested**: Pre-Makie stub test (new); post-Makie regression tests verify stubs
are superseded by extension methods.

### PBDBMakieExt --- `ext/PBDBMakieExt/PBDBMakieExt.jl`

**Responsibility**: Concrete Makie implementations; `@recipe` type definition;
PhyloPic bridge (vendored); adds methods to `PBDBMakie.*` stubs.

**Interface**: Extends `PBDBMakie.taxonomytreeplot`, `PBDBMakie.taxonomytreeplot!`,
etc. with typed concrete methods; defines `TaxonomyTreePlot` via `@recipe`.

**Tested**: All existing `taxonomytree_makie.jl` and `phylopic_makie.jl` tests.

## Governance and controlled vocabulary

All downstream tranche and tasking documents must require line-by-line reading of:

- `STYLE-julia.md` --- functional design, naming, mutation contract, anti-patterns
- `STYLE-architecture.md` --- ownership, invariant repair, anti-fixes, authorization boundaries
- `STYLE-makie.md` --- Makie host-framework contract, entrypoint semantics, recipe ownership
- `STYLE-upstream-contracts.md` --- upstream primary source reading, divergence approval
- `STYLE-verification.md` --- verification artifacts, green-state gates
- `STYLE-workflow-docs.md` --- pass-forward mandates
- `CONTRIBUTING.md` --- PR guidelines, test requirements
- Global `CLAUDE.md` --- meta-principles, pre-implementation protocol

Vocabulary notes:

- `STYLE-vocabulary.md` entries are LineagesMakie.jl-domain-specific and do not
  directly constrain PBDBMakie API names. General governance obligations
  (pass-forward, no unilateral amendments) still apply.
- Module name `PBDBMakie` refers exclusively to the stub submodule (`src/`).
- Module name `PBDBMakieExt` refers exclusively to the extension (`ext/`).
- Proscribed in all downstream documents: `Core.eval` applied to foreign module
  namespaces as a binding mechanism (the anti-pattern being removed).

## Primary upstream references

The following must be read from primary sources during tranche implementation
(no `codebases-and-documentation` directory is present in this repo):

- **Julia extension system**: `base/loading.jl` in the Julia source tree;
  official Pkg.jl documentation on package extensions
  (https://pkgdocs.julialang.org/stable/creating-packages/#Conditional-loading-of-code-in-packages-(Extensions))
- **Makie `@recipe` macro**: Makie.jl source, `src/recipes.jl`; Makie
  documentation on plot recipes

These sources constrain: how extension modules are named and loaded; how `@recipe`
creates and registers types; what happens when multiple modules define functions
with the same name (dispatch, not redefinition).

## Tranche gates

Every tranche must:

- Begin from a green state (full test suite passing, Aqua clean)
- End with:
  - Full test suite passing (including new pre-Makie stub test)
  - `runaqua.jl` clean
  - `examples/` scripts runnable without error
  - No new undefined bindings or method ambiguities introduced

Required verification artifacts:

- Pre-Makie stub test passing (see below)
- `taxonomytree_makie.jl` tests passing (regression)
- `phylopic_makie.jl` tests passing (regression)
- Aqua clean

## Testing and verification decisions

**Pre-Makie stub test** (new, to be added in `test/`):
Load `PaleobiologyDB` in a process with no Makie backend loaded. Verify:

```julia
using PaleobiologyDB

@test isdefined(PaleobiologyDB, :PBDBMakie)
@test PaleobiologyDB.PBDBMakie isa Module

# Representative stubs throw the expected error
@test_throws ErrorException PaleobiologyDB.PBDBMakie.taxonomytreeplot()
@test_throws ErrorException PaleobiologyDB.PBDBMakie.augment_leaf_phylopic!()
@test_throws ErrorException PaleobiologyDB.PBDBMakie.acquire_phylopic()

# Error messages contain the expected hint
try
    PaleobiologyDB.PBDBMakie.taxonomytreeplot()
catch e
    @test occursin("CairoMakie", e.msg)
end
```

**Regression gate**: All existing tests in `taxonomytree_makie.jl` and
`phylopic_makie.jl` must pass after loading `CairoMakie; PaleobiologyDB;
PaleobiologyDB.PBDBMakie`. The user-facing load sequence is unchanged.

**Aqua**: `runaqua.jl` must remain clean. Introducing stubs may affect Aqua's
undefined-exports check; this must be confirmed and addressed.

## Out of scope

- Separately registering `PBDBMakie` as an independent Julia package
- Making `using PBDBMakie` (bare package name) work without registration
- Moving PhyloPic data API (`acquire_phylopic`, etc.) to unconditional loading
- Stubbing the `TaxonomyTreePlot` type (requires `@recipe`; cannot pre-exist Makie)
- Any changes to the taxonomy API, PBDB data API, or non-Makie functionality
- Changes to docs build structure or documentation content

## Open questions

None. All decisions resolved during interview.

## Further notes

- The package is at `2.0.0-DEV`. Internal breaking changes are acceptable
  within the authorized boundary.
- `STYLE-makie.md:4` references "LineagesMakie.jl" by name --- this is a
  carryover from a shared governance corpus. Its principles apply to PBDBMakie
  extension work in this project.
- No `codebases-and-documentation` directory is present. Julia and Makie primary
  sources must be consulted from their upstream repositories during implementation.
- The stub-submodule design is explicitly chosen to make future migration to a
  separately registered `PBDBMakie` package mechanical: extract `src/PBDBMakie.jl`
  into its own package, update the extension to target that package. No redesign
  needed at that point.
