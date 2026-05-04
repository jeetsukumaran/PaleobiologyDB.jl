# Tasks for Tranche 2 fixes: examples environment and graph example contract repair

Parent tranche: Tranche 2
Parent PRD: `01_prd.md`
Related tranche tasking: `03_tranche-02--tasking.md`

## Governance

Mandated line-by-line reading applies to all relevant governance documents for both repositories named by the tranche, even though the implementation work for this fix pass should stay inside `PhyloPicMakie.jl`.

All tasks must comply with:

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

Important fix-pass notes:

- The prior tranche-2 tasking instruction to commit `examples/Manifest.toml` is superseded by an explicit user-ratified correction. This project should keep the `examples` environment `Project.toml`-driven, allow a fresh manifest to be resolved from the latest project constraints, and keep `Manifest.toml` ignored and untracked.
- `STYLE-verification.md` still applies. In this tranche, "deterministic" means headless-friendly, offline-safe example data and stable example behavior, not a repository-committed examples manifest.
- The current public `PhyloPicMakie.jl` overlay surface is not a clean reactive example surface. Public `augment_phylopic!` and `augment_phylopic_ranges!` accept concrete coordinate vectors; the reactive/projected-anchor owner remains `_`-prefixed internal machinery. This fix pass must not imply that the public example is reactive when it is only a snapshot hand-off.
- `STYLE-makie.md` remains controlling. Do not backfill a fake reactive example by reaching into private Makie or GraphMakie internals simply to make the gallery look more advanced.

Read-only git and shell commands may be used freely. Mutating git operations such as commit, merge, push, and branch remain the human project owner's responsibility unless the user explicitly instructs otherwise.

## Required revalidation before implementation

- Read Tranche 2 in `02_tranches.md`, the parent PRD in `01_prd.md`, and `03_tranche-02--tasking.md` in full.
- Read this fixes tasking file in full before starting implementation.
- Re-read the current `PhyloPicMakie.jl` gallery and public-surface files in full:
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/.gitignore`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/Project.toml`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/README.md`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/PhyloPicMakie.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_augment_api.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/Project.toml`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/README.md`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/smoke.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/src/_common.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/src/explicit_overlays.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/src/graph_anchors.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/src/thumbnail_gallery.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/docs/make.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/docs/src/index.md`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/docs/src/examples.md`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/.github/workflows/CI.yml`
- Re-read the upstream sources that constrain the snapshot-versus-reactive decision:
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/GraphMakie.jl/src/recipes.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/GraphMakie.jl/docs/src/index.md`
- Re-check the current public API boundary before changing code. At this fix-pass starting point, the public `PhyloPicMakie.jl` overlay APIs accept explicit coordinate vectors, while the reactive/projected-anchor owner is still internal. Unless that public boundary changes first, the graph example must remain a documented snapshot hand-off rather than a claimed reactive example.
- If the diagnosis no longer matches reality, stop and raise that before changing code.

## Fix scope established by review and user ratification

This fix pass must repair the tranche-2 review issues under the user's clarified intent:

- The examples environment should remain `Project.toml`-only. Do not add, track, or require `examples/Manifest.toml`. Instead, align the docs and workflow expectations with the intentional "fresh manifest from current project constraints" policy.
- The gallery should stop depending on incidental `PhyloPicMakie.RGBA` and `PhyloPicMakie.N0f8` namespace leakage. Example code should import exact color types from the appropriate owner package rather than teaching users to rely on undocumented module internals.
- The graph example should stop implying reactivity. Titles, docs, and explanatory text must describe it as a `GraphMakie` node-position snapshot hand-off unless and until a clean public reactive surface exists.
- No reactive example should be added in this fix pass, because the current public project surface does not provide a clean public reactive overlay API. If a future tranche introduces such infrastructure explicitly, a reactive gallery example can then be added honestly.

## Tranche execution rule

This fix pass remains inside Tranche 2 and should stay within `PhyloPicMakie.jl`. It must end with:

- the examples environment and docs aligned with the user-ratified `Project.toml`-only policy,
- no public-gallery dependence on non-public `PhyloPicMakie` namespace details,
- a graph example whose framing matches its actual snapshot behavior,
- and the touched examples smoke path and docs build green.

Do not broaden this fix pass into a public reactive overlay feature. That would be owner-level new functionality, not a truthful examples cleanup.

## Tasks

### 1. Revalidate the fix-pass baseline and encode the user-ratified environment policy

**Type**: REVIEW
**Output**: A verified start-state diagnosis for the Tranche 2 fix pass, including confirmation that the examples environment is intentionally `Project.toml`-only and that the current public overlay API does not yet provide a clean reactive graph-example surface.
**Depends on**: none

Read the tranche, parent PRD, prior tranche-2 tasking, this fixes tasking file, and the active governance set in full. Reconfirm the current examples layout and smoke path in `PhyloPicMakie.jl`, then explicitly record the user-ratified correction that `examples/Manifest.toml` must remain untracked and ignored. Reconfirm from the current public API and graph example surface that any reactive/projected-anchor behavior is still internal rather than public. Do not edit production code in this task unless a tiny verification-only note is needed to make the baseline diagnosable.

---

### 2. Align docs and workflow-facing text with the `Project.toml`-only examples policy

**Type**: WRITE
**Output**: The gallery docs, example README, and any relevant comments or notes describe the examples environment accurately as an intentionally unpinned `Project.toml`-driven environment, without implying a committed examples manifest.
**Depends on**: 1

Update the touched docs and gallery-facing text in `README.md`, `examples/README.md`, `docs/src/index.md`, `docs/src/examples.md`, and any relevant CI comments or workflow-facing notes so the examples policy is truthful. The examples should still be described as deterministic in the sense required by `STYLE-verification.md`: offline-safe inputs, headless execution, and stable smoke behavior. But the text must also make clear that the environment intentionally resolves a fresh manifest from the current `examples/Project.toml` constraints rather than relying on a checked-in `examples/Manifest.toml`. Do not add or track an examples manifest in this task.

---

### 3. Remove non-public namespace leakage from the gallery helpers

**Type**: WRITE
**Output**: Example helper and gallery scripts use the correct owner package for color types and no longer teach users to depend on undocumented `PhyloPicMakie` namespace details.
**Depends on**: 2

Refactor `examples/src/_common.jl` and any example scripts that currently rely on `PhyloPicMakie.RGBA` or `PhyloPicMakie.N0f8`. Import the exact types from the appropriate owner package directly and keep `PhyloPicMakie` usage limited to its documented public plotting functions. Preserve the current example renders and smoke behavior while cleaning up the dependency boundary. End the task with the deterministic smoke path green for the touched scope.

---

### 4. Reframe the graph example as a snapshot hand-off and drop reactive wording

**Type**: WRITE
**Output**: The graph example's title, docs, and explanatory text describe it accurately as a `GraphMakie` node-position snapshot example, not as a reactive overlay example.
**Depends on**: 3

Update `examples/src/graph_anchors.jl`, `examples/README.md`, `README.md`, `docs/src/examples.md`, and any other touched gallery references so the graph example no longer suggests live reactive tracking. Keep the example implementation on the public `PhyloPicMakie` surface and the documented `GraphMakie` hand-off surface, but explicitly describe the behavior as a one-time snapshot of `p[:node_pos]` routed into a public explicit-coordinate overlay call. Do not add a reactive example in this task, because the current public surface does not yet support one cleanly.

---

### 5. Re-run examples smoke and docs verification for the fix pass

**Type**: REVIEW
**Output**: A truthful end-state verification result for the Tranche 2 fix pass, covering examples smoke, docs build, and the updated gallery/documentation contract.
**Depends on**: 4

Run the deterministic examples smoke path and the docs build again in `PhyloPicMakie.jl`. Confirm that the output artifacts are still produced, the docs still build cleanly, and the updated wording now matches the actual behavior and policy of the examples environment. This task closes the fix pass and must leave the repository green for the touched verification scope.

---
