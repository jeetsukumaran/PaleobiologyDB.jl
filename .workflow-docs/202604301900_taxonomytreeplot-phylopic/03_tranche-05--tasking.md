# Tasks for Tranche 5: Stabilize verification, docs, and rendered artifacts

Parent tranche: Tranche 5
Parent PRD: `01_prd.md`
Related tranche tasking: `03_tranche-04-fixes--tasking.md`

## Settled user decisions and environment baseline

Implementation must treat the following as fixed input:

- This is a stabilization tranche, not a reopen-the-architecture tranche.
- The approved final public tree surface and import story are already set. Docs must remain truthful to that contract rather than broadening API surface.
- The truthful tree import story is the extension-module path, e.g. `using PaleobiologyDB.TaxonomyMakie: taxonomytreeplot, augment_leaf_phylopic!`.
- The repaired owner boundary from Tranches 3 and 4 must remain intact: generic anchored-overlay ownership stays in `PhyloPicMakie`; `PaleobiologyDB.jl` must not regrow PBDB-side shadow render owners, compatibility shims, or private-internal reach-ins.
- `set_autocaching!(true)` should be used for slow PBDB or PhyloPic-heavy live checks.
- Local generated `Manifest.toml` files are not themselves a tranche failure if they remain ignored and untracked. The real contract is about tracked repository state, documented workflow, and CI expectations. Do not turn local ignored manifests into a fake issue.
- The standalone `PhyloPicMakie.jl` gallery must remain isolated from `PaleobiologyDB.jl` and must continue to exercise only the public `PhyloPicMakie` overlay surface.

Tracked-state and documentation baseline that must remain true:

- `PaleobiologyDB.jl` must not start requiring tracked root or `test` manifests as part of the supported workflow unless the user later changes policy.
- `PhyloPicMakie.jl/examples` must remain a `Project.toml`-driven gallery in tracked state; local generated `examples/Manifest.toml` is acceptable, but the tracked gallery contract must not depend on committing it.
- Docs and README examples must continue to describe the extension-module import story truthfully.
- Placeholder behavior wording must continue to describe a placeholder glyph image, not an old rectangle description.

## Governance

Mandated line-by-line reading applies to all relevant governance documents in both repositories before implementation begins. This tranche is cross-repo stabilization work, so the implementation must preserve the active verification, docs, vocabulary, and owner-boundary authorities throughout.

All tasks must comply with:

- Bundled governance depot under `/home/jeetsukumaran/site/service/env/start/workhost/resources/packages/shared/workhost-resources/configure/coding-agent-skills/development-policies/references`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/CONTRIBUTING.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-architecture.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-docs.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-git.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-julia.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-makie.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-upstream-contracts.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-verification.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-vocabulary.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-workflow-docs.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-writing.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-architecture.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-docs.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-git.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-julia.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-makie.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-upstream-contracts.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-verification.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-vocabulary.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-workflow-docs.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/STYLE-writing.md`

Primary-source owners that must be re-read in full where they constrain this tranche:

- `PaleobiologyDB.jl/test/taxonomytree_makie.jl`
- `PaleobiologyDB.jl/test/phylopic_makie.jl`
- `PaleobiologyDB.jl/test/runtests.jl`
- `PaleobiologyDB.jl/examples/src/taxonomytree.jl`
- `PaleobiologyDB.jl/docs/make.jl`
- `PaleobiologyDB.jl/docs/src/guide/taxonomytree_makie.md`
- `PaleobiologyDB.jl/docs/src/api/taxonomytree_makie.md`
- `PaleobiologyDB.jl/docs/src/guide/phylopic_makie.md`
- `PaleobiologyDB.jl/docs/src/api/phylopic_makie.md`
- `PaleobiologyDB.jl/README.md`
- `PhyloPicMakie.jl/test/test_makie_integration.jl`
- `PhyloPicMakie.jl/examples/README.md`
- `PhyloPicMakie.jl/examples/smoke.jl`
- `PhyloPicMakie.jl/docs/src/examples.md`
- `PhyloPicMakie.jl/README.md`
- `PhyloPicMakie.jl/.github/workflows/CI.yml`

Read-only git and shell commands may be used freely. Mutating git operations such as commit, merge, push, and branch remain the human project owner's responsibility unless the user explicitly instructs otherwise.

## Required revalidation before implementation

- Read Tranche 5 in `02_tranches.md`, the parent PRD in `01_prd.md`, and this tasking file in full.
- Re-read the relevant code, tests, docs, examples, smoke runners, and CI hooks in both repositories in full.
- Re-read the cited upstream and host-framework primary sources where they constrain the work, especially Makie-facing verification and rendering contracts if the tranche touches them.
- Reconfirm that the approved final import story, owner boundary, and vocabulary cleanup are already settled and must not be reopened here.
- Reconfirm that this tranche is stabilization-only: it may strengthen verification and docs, but it must not smuggle in new API, broaden exports, or revive compatibility scaffolding.
- If the tranche diagnosis no longer matches reality, or if a prerequisite tranche turns out not to be honestly green, stop and raise that before changing code.

## Tranche execution rule

This tranche may add or tighten verification, artifact generation, docs, README, smoke runners, and CI-adjacent support for those surfaces, but it must begin and end in an honestly green, policy-compliant state for its scope.

When the tranche is complete:

- the stabilized verification must catch the historical tiny-glyph and placement-class regressions rather than only confirming no-error execution,
- the final docs and README must match the approved end-state exactly,
- the required rendered artifacts must exist for both tree-overlay happy paths and the standalone `PhyloPicMakie.jl` gallery,
- and the repaired owner boundary and truthful import contract must still be intact.

Docs must be brought into truth with the approved API and import contract. This tranche is not authorized to change the public API to satisfy prose.

## Non-negotiable execution rules

- Do not broaden top-level `PaleobiologyDB` exports or import behavior to make docs examples shorter.
- Do not regrow PBDB-side generic anchored-overlay helpers, compatibility fallbacks, or private-internal reach-ins merely to make verification pass.
- Do not treat the existence of an ignored local `Manifest.toml` as a regression by itself.
- Do not convert the standalone `PhyloPicMakie.jl` gallery into a PBDB-coupled example suite.
- Do not weaken existing contract tests or replace them with weaker smoke-only checks.
- Do not let artifact generation become a second rendering path or second owner; it must remain a thin verification wrapper over the public surfaces.
- Do not close the tranche on manual inspection alone; there must be scripted or automated signals that would fail the known bad implementation shapes.

## Concrete anti-patterns or removal targets

The following regression shapes must stay retired or be made impossible to reintroduce without failing verification:

- stale docs or README text implying `using PaleobiologyDB: taxonomytreeplot` works
- stale docs or guide wording implying `TaxonomyMakie` exports automatically enter scope after `using PaleobiologyDB`
- PBDB-side shadow generic anchored-overlay owners in `ext/TaxonomyMakie/PhyloPic/src/_render.jl`
- placeholder wording that says `:placeholder` draws a gray or grey rectangle for the tree overlay path
- verification that only checks that `show_phylopic = true` does not throw, without also checking the intended rendered artifact path
- gallery smoke or docs examples in `PhyloPicMakie.jl` that silently depend on `PaleobiologyDB.jl`
- stabilization work that passes only because of hidden local environment assumptions instead of the tracked documented workflow

## Failure-oriented verification

At minimum, the final verification for this tranche must include checks that would fail if the known bad implementations returned:

- a regression check that would fail if the false top-level import story reappeared in `README.md` or tree docs
- a regression check that would fail if PBDB-side shadow anchored-overlay helpers or other shadow-owner patterns reappeared
- a regression check that would fail if placeholder wording drifted back to rectangle terminology for the tree-overlay path
- a scripted or automated check that the tree rendered-artifact path exists for both one-step and explicit two-step flows
- a verification path that exercises resize or relimit-sensitive overlay behavior rather than only no-error execution
- a standalone `PhyloPicMakie.jl` smoke or artifact path that would fail if the gallery drifted away from the final public overlay interface

## Tasks

### 1. Revalidate the stabilization baseline and retired-regression set

**Type**: REVIEW  
**Output**: A verified Tranche 05 start-state inventory covering current docs truth, current automated regression guards, current artifact and smoke paths, and the exact retired regression classes that must stay dead.  
**Depends on**: none

Read the parent PRD, Tranche 5, the active governance set, and the live verification, docs, example, and CI owners in both repositories in full. Reconfirm the stabilized surfaces already in place in `PaleobiologyDB.jl/test/taxonomytree_makie.jl`, `PaleobiologyDB.jl/test/phylopic_makie.jl`, `PaleobiologyDB.jl/README.md`, `PaleobiologyDB.jl/docs/src/guide/taxonomytree_makie.md`, `PhyloPicMakie.jl/examples/README.md`, `PhyloPicMakie.jl/docs/src/examples.md`, `PhyloPicMakie.jl/examples/smoke.jl`, and `PhyloPicMakie.jl/.github/workflows/CI.yml`. Record the exact regression classes that still need stronger stabilization coverage, but do not mutate production files in this task unless a tiny verification-only probe is truly necessary to establish reality.

### 2. Build a scripted tree rendered-artifact harness for one-step and two-step happy paths

**Type**: WRITE  
**Output**: A thin, reusable artifact-generation path that materializes at least one `show_phylopic = true` tree render and one explicit `augment_leaf_phylopic!` two-step render, with predictable output paths suitable for manual inspection and automated existence checks.  
**Depends on**: 1

Add or refactor a small artifact harness in `PaleobiologyDB.jl` using the existing public tree overlay surfaces rather than inventing a special-case rendering path. Touch `examples/src/taxonomytree.jl` and add a thin helper or smoke runner only if that is the cleanest seam. Use `set_autocaching!(true)` for slow live PBDB or PhyloPic-heavy paths. The output must remain a verification wrapper over the current approved API, not a second example owner and not a second overlay implementation. If this task removes or replaces ad hoc artifact logic, make sure the removed logic truly disappears rather than merely moving elsewhere.

### 3. Harden automated PaleobiologyDB verification against historical and reviewed regressions

**Type**: TEST  
**Output**: Stronger automated checks in `PaleobiologyDB.jl` that would fail the known bad implementations rather than only proving the happy path runs.  
**Depends on**: 2

Strengthen `test/taxonomytree_makie.jl` and `test/phylopic_makie.jl` so the suite would fail if any of the reviewed regression classes return: false top-level import docs, PBDB-side shadow overlay owners, stale placeholder wording, or tree overlay verification that only checks no-error execution. If artifact generation from Task 2 is scripted, add automated checks for expected output paths or other robust signals rather than relying only on manual viewing. Upgrade weak assertions where they still only prove that “a plot was added” if the stabilized contract can support stronger verification. End this task with the touched verification scope green.

### 4. Stabilize the standalone `PhyloPicMakie.jl` gallery, smoke path, and verification contract

**Type**: WRITE  
**Output**: The standalone `PhyloPicMakie.jl` examples gallery, smoke runner, README/docs, and any touched CI or docs hooks stay aligned with the finalized public overlay surface and remain clearly independent of `PaleobiologyDB.jl`.  
**Depends on**: 1

Re-read and, if needed, update `PhyloPicMakie.jl/examples/README.md`, `PhyloPicMakie.jl/docs/src/examples.md`, `PhyloPicMakie.jl/examples/smoke.jl`, and, only where necessary, the examples-related CI or docs wiring. Preserve the current contract that local generated manifests may exist and remain ignored, but the tracked gallery workflow must remain `Project.toml`-driven. Keep the graph example honestly described as a snapshot hand-off unless the public overlay surface has changed enough to support something stronger without private coupling. Do not allow the gallery or smoke path to drift into PBDB-specific assumptions or private-interface reach-ins.

### 5. Align final docs, README, and example prose to the approved end-state

**Type**: WRITE  
**Output**: Cross-repo docs and examples describe the actual final import story, placeholder behavior, caching workflow, standalone gallery policy, and tree overlay surfaces exactly, with no stale pre-fix wording.  
**Depends on**: 3, 4

Update the user-facing prose in both repositories so the final documented contract is exact and stable. Likely touch `PaleobiologyDB.jl/README.md`, `PaleobiologyDB.jl/docs/src/guide/taxonomytree_makie.md`, `PaleobiologyDB.jl/docs/src/api/taxonomytree_makie.md`, `PaleobiologyDB.jl/docs/src/guide/phylopic_makie.md`, `PaleobiologyDB.jl/docs/src/api/phylopic_makie.md`, plus the `PhyloPicMakie.jl` gallery docs or README if needed. Docs must adapt to the approved API and import contract; do not “fix” prose by broadening exports or reopening the public surface.

### 6. Close the tranche with cross-repo end-green verification and artifact review

**Type**: REVIEW  
**Output**: A truthful Tranche 05 closeout showing full required verification, rendered artifacts present, and the known regression classes still retired.  
**Depends on**: 5

Run the tranche gates honestly. In `PaleobiologyDB.jl`, rerun `julia --project=test test/runtests.jl` and `julia --project=docs docs/make.jl`. If this tranche touches `PhyloPicMakie.jl`, rerun `julia --project=. -e 'import Pkg; Pkg.test()'`, `julia --project=docs docs/make.jl`, and the standalone examples smoke path there. Confirm that the rendered tree artifact, explicit two-step artifact, and standalone gallery artifact all exist and match the documented flows. Explicitly verify that stabilization did not reintroduce shadow owners, false import docs, stale placeholder wording, or any tracked-state requirement around ignored manifests. The tranche closes only if the final documented contract, the automated checks, and the scripted artifact paths all agree.

---
