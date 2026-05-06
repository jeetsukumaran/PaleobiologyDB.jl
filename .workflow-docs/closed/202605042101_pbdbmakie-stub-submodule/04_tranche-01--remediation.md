# Tasks: Tranche 1 remediation

Parent tranche: Tranche 1
Parent PRD: `01_prd.md`

## Context and outstanding issues

Tranche 1 implementation is structurally complete: `Core.eval` is absent, the
extension is renamed, import ordering is correct, and `PBDBMakie` is a genuine
compile-time submodule. The following issues remain and must be resolved before
Tranche 2 begins.

### Precompilation constraint (design rationale update)

The original tasking specified `const _PhyloPic = Ref{Union{Module, Nothing}}(nothing)`
in the stub and `PBDBMakie._PhyloPic[] = PhyloPic` in the extension. This design
is incorrect under Julia's precompilation model.

Julia serializes module state to `.ji` cache during precompilation. On subsequent
loads, the cached state is restored; module-level code does not re-run. Only
`__init__` re-runs on every load. A `Ref` set by module-level extension code
is mutated during the extension's precompilation pass, but when both packages
subsequently load from cache, `PaleobiologyDB`'s Ref deserializes to its initial
`nothing` and the extension's assignment is not re-applied. `__init__` was the
mechanism that previously re-applied such state; it was removed by this migration.

`Base.get_extension` is a runtime query against the live module registry. It is
not a precompilation-time operation and returns the correct result after packages
load from cache. A bridge type whose `[]` operator calls `Base.get_extension` is
the correct solution.

The implementation correctly chose the `_PhyloPicBridge` approach. The PRD has
been updated to reflect this. `03_tranche-01--tasking.md` contains the incorrect
Ref specification and is superseded by this remediation document for that design
point.

### Issue inventory

**I-1 (Blocking): `src/PBDBMakie.jl` contains unauthorized `_ExtensionBindingBridge` machinery**

The stub module exports an `_ExtensionBindingBridge` struct, `_extension_binding`
function, and 11 `const` callable proxies for extension-internal symbols:
`_rank_depth`, `_compute_dendrogram_layout`, `_dendrogram_segment_pairs`,
`_leaf_positions`, `_plan_leaf_node_phylopic_overlay`,
`_plan_leaf_label_phylopic_overlay`, `_plan_leaf_plot_phylopic_overlay`,
`_attach_plot_leaf_phylopic_overlay!`, `_leaf_text_plots`,
`_augment_leaf_phylopic!`, `_LeafOverlayPlan`.

These exist because `test/taxonomytree_makie.jl` lines 120--130 had pre-existing
references to extension internals via `PaleobiologyDB.PBDBMakie.*` that worked
through the old `Core.eval` hack. The implementer preserved those references by
routing them through the stub. This inverts the ownership boundary: the
unconditional stub module now encodes knowledge of extension-private symbols and
queries the extension at runtime to expose them.

The correct solution is to update the test references directly. Test code may use
`Base.get_extension` to access extension internals; it is not part of the public
API. The tasking document was incomplete in not identifying these lines as
requiring updates alongside the authorized 11 substitutions.

**I-2 (Blocking): `README.md` destroyed**

The file was reduced from ~390 lines to 3 lines (`# STYLE` followed by two blank
lines). All package documentation, installation guide, and API examples are gone.
This appears to be an accidental overwrite.

**I-3 (Medium): `STYLE-julia.md` heading stripped**

The file heading changed from `# STYLE--julia.md — Julia Functional Design Principles`
to `# STYLE--julia.md`. The title must be restored.

**I-4 (Scope): Governance and project files modified in the tranche commit**

`STYLE-architecture.md`, `STYLE-verification.md`, `STYLE-vocabulary.md`,
`STYLE-workflow-docs.md`, `AGENTS.md`, `STYLE-agent-handoffs.md`, `LICENSE.md`
were added or modified in the tranche commit. These are out of scope for Tranche 1
source work and should be separated into a standalone commit with appropriate
review. Content review of the STYLE additions is out of scope for this remediation.

**I-5 (Accepted with documentation): Additional test file changes**

`test/taxonomy_phylopic_acquire.jl` and `test/taxonomy_phylopic_images.jl` were
modified with the same `.PhyloPic.` → `._PhyloPic[].` substitution pattern. These
files were not in the authorized list — the tasking was incomplete in not
identifying them. The changes are mechanically correct and are accepted. They are
retroactively authorized here.

**I-6 (Accepted): `test/runaqua.jl` modified**

The change (`# using Test` → `using Test`) violates the non-negotiable rule but is
harmless and correct. Accepted.

---

## Non-negotiable execution rules

- Do not modify `_PhyloPicBridge`, `Base.getindex(::_PhyloPicBridge)`, or
  `const _PhyloPic = _PhyloPicBridge()` in `src/PBDBMakie.jl`. These are correct
  and remain.
- Do not touch any of the 15 bare function declarations or export lines in
  `src/PBDBMakie.jl`.
- Do not touch `ext/PBDBMakieExt/PBDBMakieExt.jl` or any implementation file.
- Do not modify `test/runtests.jl`, `test/runaqua.jl`, or any test file not listed
  in the tasks below.
- Do not add `Core.eval` or `__init__` to any source file.

---

## Tasks

### R-1. Restore `README.md`

**Type:** RESTORE
**Output:** `README.md` contains the full package documentation as of `HEAD~1`
**Depends on:** none

Restore `README.md` from the commit immediately before the tranche commit:

```bash
git show HEAD~1:README.md > README.md
```

Verify the file is restored by checking its line count and that it contains the
package title `# PaleobiologyDB` and the CI badge line.

**Positive contract:**
`grep '# PaleobiologyDB' README.md` returns a match.
`wc -l < README.md` returns a value in the range 380--400.

**Negative contract:** No other file modified.

**Files:** `README.md`

**Verification:**
```
grep '# PaleobiologyDB' README.md    # must match
grep 'CI.yml' README.md              # badge line present
wc -l < README.md                    # should be ~390
```

---

### R-2. Restore `STYLE-julia.md` heading

**Type:** EDIT
**Output:** First line of `STYLE-julia.md` is the full original heading
**Depends on:** none (may run in parallel with R-1)

Read `STYLE-julia.md` line 1. It currently reads:
```
# STYLE--julia.md 
```

Replace it with:
```
# STYLE--julia.md — Julia Functional Design Principles
```

No other lines change.

**Positive contract:** `head -1 STYLE-julia.md` returns the full heading.

**Negative contract:** No other line modified.

**Files:** `STYLE-julia.md`

**Verification:**
```
head -1 STYLE-julia.md
# must print: # STYLE--julia.md — Julia Functional Design Principles
```

---

### R-3. Remove `_ExtensionBindingBridge` from `src/PBDBMakie.jl`

**Type:** EDIT
**Output:** `src/PBDBMakie.jl` contains only the authorized content: module
docstring, `_PhyloPicBridge` type and `const _PhyloPic`, 15 bare function
declarations, 15 exports
**Depends on:** none (may run in parallel with R-1, R-2)

Read `src/PBDBMakie.jl` in full. Remove exactly the following blocks, leaving
everything else untouched:

**Block A — `_ExtensionBindingBridge` struct and docstring** (lines ~24--28 of
current file):
```julia
"""
Bridge object for an internal binding owned by `PBDBMakieExt`.
"""
struct _ExtensionBindingBridge
    name::Symbol
end
```

**Block B — `_extension_binding` function and docstring** (lines ~29--43):
```julia
"""
    _extension_binding(name::Symbol) -> Any

Resolve an internal binding from the loaded `PBDBMakieExt` extension.
"""
function _extension_binding(name::Symbol)
    ext = Base.get_extension(parentmodule(@__MODULE__), :PBDBMakieExt)
    isnothing(ext) && throw(
        ErrorException(
            "PBDBMakie internal binding `$(name)` requires the PBDBMakieExt extension to be loaded."
        )
    )
    return getproperty(ext, name)
end
```

**Block C — `_ExtensionBindingBridge` callable override and docstring**
(lines ~57--64):
```julia
"""
    (bridge::_ExtensionBindingBridge)(args...; kwargs...) -> Any

Invoke the resolved extension-owned binding with forwarded arguments.
"""
function (bridge::_ExtensionBindingBridge)(args...; kwargs...)
    target = _extension_binding(bridge.name)
    return target(args...; kwargs...)
end
```

**Block D — all 11 `_ExtensionBindingBridge` `const` bindings** (lines ~67--77):
```julia
const _rank_depth = _ExtensionBindingBridge(:_rank_depth)
const _compute_dendrogram_layout = _ExtensionBindingBridge(:_compute_dendrogram_layout)
const _dendrogram_segment_pairs = _ExtensionBindingBridge(:_dendrogram_segment_pairs)
const _leaf_positions = _ExtensionBindingBridge(:_leaf_positions)
const _plan_leaf_node_phylopic_overlay = _ExtensionBindingBridge(:_plan_leaf_node_phylopic_overlay)
const _plan_leaf_label_phylopic_overlay = _ExtensionBindingBridge(:_plan_leaf_label_phylopic_overlay)
const _plan_leaf_plot_phylopic_overlay = _ExtensionBindingBridge(:_plan_leaf_plot_phylopic_overlay)
const _attach_plot_leaf_phylopic_overlay! = _ExtensionBindingBridge(:_attach_plot_leaf_phylopic_overlay!)
const _leaf_text_plots = _ExtensionBindingBridge(:_leaf_text_plots)
const _augment_leaf_phylopic! = _ExtensionBindingBridge(:_augment_leaf_phylopic!)
const _LeafOverlayPlan = _ExtensionBindingBridge(:_LeafOverlayPlan)
```

After removal, the module body contains, in order:
1. Module-level docstring
2. `module PBDBMakie`
3. `_PhyloPicBridge` struct and its docstring
4. `Base.getindex(::_PhyloPicBridge)` override and its docstring
5. `const _PhyloPic = _PhyloPicBridge()`
6. 15 bare function declarations (`function f end`)
7. 15 `export` statements
8. `end # module PBDBMakie`

**Positive contract:**
`grep '_ExtensionBindingBridge\|_extension_binding' src/PBDBMakie.jl` returns no matches.
`grep '_PhyloPicBridge\|_PhyloPic' src/PBDBMakie.jl` returns matches (bridge kept).
`grep 'function taxonomytreeplot end' src/PBDBMakie.jl` returns a match.

**Negative contract:** `_PhyloPicBridge`, `Base.getindex(::_PhyloPicBridge)`, and
`const _PhyloPic` are unchanged. No bare function declarations removed.

**Files:** `src/PBDBMakie.jl`

**Out of scope:** All other files.

**Verification:**
```
grep -c '_ExtensionBindingBridge' src/PBDBMakie.jl   # must print 0
grep -c '_extension_binding' src/PBDBMakie.jl         # must print 0
grep '_PhyloPicBridge' src/PBDBMakie.jl               # must have matches
grep 'function taxonomytreeplot end' src/PBDBMakie.jl  # must have a match
```

---

### R-4. Update `test/taxonomytree_makie.jl` extension-internal accesses

**Type:** TEST
**Output:** Lines 118--131 of `test/taxonomytree_makie.jl` access extension
internals via `Base.get_extension` rather than through `PaleobiologyDB.PBDBMakie.*`
**Depends on:** R-3 (R-3 removes the bridge constants that currently make these
references work; R-4 must replace them before verification)

Read `test/taxonomytree_makie.jl` in full. Locate the `if _CAIRO_TTM_AVAILABLE`
block beginning at line 118. The current lines 119--130 are:

```julia
    # Access internals through the extension module
    const _rd_fn   = PaleobiologyDB.PBDBMakie._rank_depth
    const _layout  = PaleobiologyDB.PBDBMakie._compute_dendrogram_layout
    const _segpairs = PaleobiologyDB.PBDBMakie._dendrogram_segment_pairs
    const _leaf_positions_fn = PaleobiologyDB.PBDBMakie._leaf_positions
    const _plan_leaf_node_overlay = PaleobiologyDB.PBDBMakie._plan_leaf_node_phylopic_overlay
    const _plan_leaf_label_overlay = PaleobiologyDB.PBDBMakie._plan_leaf_label_phylopic_overlay
    const _plan_leaf_plot_overlay = PaleobiologyDB.PBDBMakie._plan_leaf_plot_phylopic_overlay
    const _attach_plot_leaf_overlay! = PaleobiologyDB.PBDBMakie._attach_plot_leaf_phylopic_overlay!
    const _leaf_text_plots_for_plot = PaleobiologyDB.PBDBMakie._leaf_text_plots
    const _augment_leaf_overlay = PaleobiologyDB.PBDBMakie._augment_leaf_phylopic!
    const _LeafOverlayPlan = PaleobiologyDB.PBDBMakie._LeafOverlayPlan
```

Replace the comment line and all 11 `const` lines with the following 13 lines:

```julia
    # Access internals directly through the loaded extension module.
    # Base.get_extension is safe here: this block is guarded by
    # _CAIRO_TTM_AVAILABLE, which implies CairoMakie (and therefore the
    # PBDBMakieExt extension) is loaded.
    const _ext = Base.get_extension(PaleobiologyDB, :PBDBMakieExt)
    const _rd_fn   = _ext._rank_depth
    const _layout  = _ext._compute_dendrogram_layout
    const _segpairs = _ext._dendrogram_segment_pairs
    const _leaf_positions_fn = _ext._leaf_positions
    const _plan_leaf_node_overlay = _ext._plan_leaf_node_phylopic_overlay
    const _plan_leaf_label_overlay = _ext._plan_leaf_label_phylopic_overlay
    const _plan_leaf_plot_overlay = _ext._plan_leaf_plot_phylopic_overlay
    const _attach_plot_leaf_overlay! = _ext._attach_plot_leaf_phylopic_overlay!
    const _leaf_text_plots_for_plot = _ext._leaf_text_plots
    const _augment_leaf_overlay = _ext._augment_leaf_phylopic!
    const _LeafOverlayPlan = _ext._LeafOverlayPlan
```

Use exact-string replacement. Verify the surrounding `if _CAIRO_TTM_AVAILABLE`
guard is intact before and after. No other lines in this file change.

The `_LeafOverlayPlan` assignment now resolves to the actual type from the
extension (not a callable bridge proxy), so any test that constructs an instance
with `_LeafOverlayPlan(args...)` receives the real type. Type annotations or `isa`
checks against `_LeafOverlayPlan` also work correctly.

**Positive contract:**
`grep 'PaleobiologyDB.PBDBMakie._rank_depth' test/taxonomytree_makie.jl` returns
no matches.
`grep 'Base.get_extension(PaleobiologyDB' test/taxonomytree_makie.jl` returns
a match.

**Negative contract:** Lines 227, 269, and 359 (the three authorized substitutions
from the original tasking) are untouched. No `@testset` structure or assertions
modified.

**Files:** `test/taxonomytree_makie.jl`

**Out of scope:** All other test files; all source and extension files.

**Verification:**
```
grep 'PaleobiologyDB.PBDBMakie\._rank_depth' test/taxonomytree_makie.jl   # must return nothing
grep 'PaleobiologyDB.PBDBMakie\._layout' test/taxonomytree_makie.jl        # must return nothing
grep 'Base.get_extension(PaleobiologyDB' test/taxonomytree_makie.jl        # must match
grep '_CAIRO_TTM_AVAILABLE' test/taxonomytree_makie.jl | head -3           # guard intact
```

---

### R-5. Run full verification pass

**Type:** TEST
**Output:** All automated acceptance criteria met; full test suite and Aqua clean
**Depends on:** R-1, R-2, R-3, R-4

Run the following verification commands in order. Each must pass before proceeding.

**Step 1 --- submodule visible and no bridge contamination:**
```
julia --project=. -e '
using PaleobiologyDB
@assert isdefined(PaleobiologyDB, :PBDBMakie) "PBDBMakie not bound"
@assert PaleobiologyDB.PBDBMakie isa Module "not a Module"
@assert !isdefined(PaleobiologyDB.PBDBMakie, :_ExtensionBindingBridge) \
    "_ExtensionBindingBridge must not be in stub"
@assert !isdefined(PaleobiologyDB.PBDBMakie, :_rank_depth) \
    "_rank_depth must not be in stub"
println("Submodule clean: OK")
'
```

**Step 2 --- declared functions yield MethodError before Makie loads:**
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

**Step 3 --- _PhyloPic bridge resolves after Makie loads:**
```
julia --project=. -e '
using CairoMakie, PaleobiologyDB
@assert !isnothing(PaleobiologyDB.PBDBMakie._PhyloPic[]) "_PhyloPic[] is nothing after Makie"
@assert PaleobiologyDB.PBDBMakie._PhyloPic[] isa Module "_PhyloPic[] is not a Module"
println("_PhyloPic bridge: OK")
'
```

**Step 4 --- Core.eval and __init__ absent:**
```
grep -r 'Core.eval' ext/PBDBMakieExt/ src/   # must return nothing
grep -r '__init__' ext/PBDBMakieExt/           # must return nothing
```

**Step 5 --- full test suite:**
```
julia --project=test test/runtests.jl
```
All tests that were passing before the migration must pass. Any new failure is a
blocker.

**Step 6 --- Aqua clean:**
```
julia --project=test test/runaqua.jl
```

**Positive contract:** All six steps complete without error or new failure.

**Files:** None modified; read-only verification run.

---

### R-6. Separate governance file changes into a standalone commit (human owner)

**Type:** GIT (human action required)
**Depends on:** R-1 through R-5 passing

The following files were modified in the tranche commit but are not Tranche 1
source changes. They should be committed separately so the tranche commit contains
only the source migration:

- `STYLE-architecture.md` (content added to §"One public semantic, one normalization point")
- `STYLE-verification.md`
- `STYLE-vocabulary.md`
- `STYLE-workflow-docs.md`
- `AGENTS.md` (new file, 87 lines)
- `STYLE-agent-handoffs.md` (new file, 130 lines)
- `LICENSE.md` (new file, 181 lines)

Review each file for content before committing. Confirm that the additions to
STYLE files do not conflict with any governance mandates in effect for Tranche 2.

This task requires human judgment on commit strategy (amend, separate commit, or
accept as-is). It does not block the automated remediation tasks.

---

## Summary of authorized state after remediation

`src/PBDBMakie.jl` contains: module docstring, `module PBDBMakie`,
`_PhyloPicBridge` struct + `Base.getindex` override + `const _PhyloPic`, 15 bare
function declarations, 15 exports, `end # module`.

`ext/PBDBMakieExt/PBDBMakieExt.jl` is unchanged from the tranche implementation.

`test/taxonomytree_makie.jl` lines 118--131: `const _ext = Base.get_extension(...)`
followed by 11 direct `_ext.*` accesses; `_CAIRO_TTM_AVAILABLE` guard intact.

All other files are at the state left by the tranche commit.
