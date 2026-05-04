# Tasks for Tranche 2: Build standalone PhyloPicMakie examples environment and MWE gallery

Parent tranche: Tranche 2
Parent PRD: `01_prd.md`

## Governance

Mandated line-by-line reading applies to all relevant governance documents for both repositories named by the tranche, even though the implementation work for this tranche should stay inside `PhyloPicMakie.jl`.

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

Important tranche-2 notes:

- `PhyloPicMakie.jl` has no repo-local `CONTRIBUTING.md`; its repo-local `STYLE*.md` files remain active authorities.
- `STYLE-makie.md` and `STYLE-verification.md` are especially controlling here. The examples are not throwaway scripts; they are verification artifacts for a Makie-sensitive public surface.
- `STYLE-docs.md` applies to the examples README and any docs updates. Use sentence case headings, no separator rules, and consistent list grammar.
- `STYLE-vocabulary.md` remains controlling, but exact third-party API names from `Graphs.jl`, `MetaGraphsNext.jl`, `GraphMakie.jl`, and Makie may be used when referring to those external APIs precisely.

Read-only git and shell commands may be used freely. Mutating git operations such as commit, merge, push, and branch remain the human project owner's responsibility unless the user explicitly instructs otherwise.

## Required revalidation before implementation

- Read Tranche 2 in `02_tranches.md` and the parent PRD in `01_prd.md` in full.
- Read the current `PhyloPicMakie.jl` public-surface, docs, and verification owners in full:
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/Project.toml`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/README.md`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/PhyloPicMakie.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_augment_api.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_render_core.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_coordinates.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/test/test_makie_integration.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/docs/make.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/docs/src/index.md`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/docs/src/api/rendering.md`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/.github/workflows/CI.yml`
- Read the graph-stack upstream primary sources in full where they constrain this tranche:
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Graphs.jl/README.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Graphs.jl/docs/src/first_steps/construction.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/Graphs.jl/docs/src/first_steps/plotting.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/MetaGraphsNext.jl/README.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/MetaGraphsNext.jl/docs/src/index.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/MetaGraphsNext.jl/docs/src/api.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/MetaGraphsNext.jl/src/metagraph.jl`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/GraphMakie.jl/README.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/GraphMakie.jl/docs/src/index.md`
  - `/home/jeetsukumaran/site/storage/local/00_resources/codebases-and-documentation/GraphMakie.jl/src/recipes.jl`
- Re-check the live repository layout before changing code. At tasking time, `PhyloPicMakie.jl` has no `examples/` directory yet, so this tranche still describes real missing surface rather than stale cleanup.
- If the tranche diagnosis no longer matches reality, stop and raise that before changing code.

## Tranche execution rule

This tranche is user-facing and verification-sensitive. It must:

- keep the `examples` environment isolated from `PaleobiologyDB.jl`,
- demonstrate the approved public `PhyloPicMakie.jl` surface rather than private internals,
- use deterministic, headless-friendly example execution for required smoke verification,
- and leave behind examples that are both runnable by humans and defensible as regression artifacts.

Design decisions already fixed by upstream contracts and current repository patterns:

- Use a dedicated `examples` environment with committed `Project.toml` and `Manifest.toml`, following the repository's existing `docs` environment pattern rather than inventing an untracked or implicit setup.
- Use `CairoMakie` as the backend in required example scripts and smoke verification, because the examples must run headlessly in CI-like environments and produce saveable artifacts without interactive backend assumptions.
- Use public APIs only in the gallery scripts: `augment_phylopic!`, `augment_phylopic_ranges!`, `phylopic_thumbnail_grid`, and other documented public surface. Do not showcase `_augment_phylopic_anchored!` or other `_`-prefixed helpers in the user-facing examples.
- Keep automated smoke examples deterministic and offline-friendly. If a live UUID-based showcase script is added, it must be clearly marked as manual or opt-in and must not be the only verification artifact for this tranche.
- For graph-oriented examples, use `GraphMakie.graphplot` as the rendering owner and consume its exposed `p[:node_pos]` observable or equivalent documented surface for node anchors. Do not reach into private GraphMakie internals.
- Use fixed layouts or explicitly supplied node positions in graph MWEs instead of random or unstable layout defaults, because rendered artifacts and smoke checks must be repeatable.

## Tasks

### 1. Revalidate the examples baseline and lock the example strategy

**Type**: REVIEW
**Output**: A verified start-state diagnosis for Tranche 2, including confirmation that `PhyloPicMakie.jl` still lacks an `examples` environment, and a recorded implementation strategy covering backend choice, public-surface boundaries, deterministic smoke policy, and graph-example hand-off pattern.
**Depends on**: none

Read the tranche, parent PRD, and the active governance files in full, then re-check the live `PhyloPicMakie.jl` surface, docs, CI, and graph-stack sources. Confirm that no `examples/` project exists yet, that the current public surface is still centered on explicit-coordinate overlays and thumbnail-grid functions, and that `GraphMakie.graphplot` exposes `p[:node_pos]` as the correct node-anchor hand-off surface. Record the already-resolved execution strategy from this tasking document as the implementation baseline: isolated `examples` project, `CairoMakie` backend, deterministic offline smoke examples, and fixed graph layouts. Do not edit production code in this task unless a tiny verification-only note is required to make the baseline diagnosable.

### 2. Create the isolated examples environment and shared runner scaffolding

**Type**: CONFIG
**Output**: A committed `examples` environment in `PhyloPicMakie.jl` with reproducible dependency files, shared runner conventions, and a clean place for generated example artifacts.
**Depends on**: 1

Create `examples/Project.toml` and `examples/Manifest.toml` in `PhyloPicMakie.jl`, following the repository's existing auxiliary-environment pattern from `docs/`. The `examples` project must include `PhyloPicMakie` via a local path source to `..`, plus `CairoMakie`, `Graphs`, `GraphMakie`, and `MetaGraphsNext`; do not add `PaleobiologyDB.jl`. Add shared scaffolding such as `examples/src/_common.jl`, `examples/build/.gitignore`, and an `examples/README.md` or equivalent index if that keeps the gallery coherent. Encode a common script pattern that lets each example run both as `julia --project=examples examples/src/<name>.jl` and from a lightweight smoke runner through a `main`-style entry point. End the task with the environment files valid and the repository green for the touched scope.

### 3. Add deterministic public-surface MWEs for explicit overlays and grid rendering

**Type**: WRITE
**Output**: At least two standalone runnable example scripts that demonstrate `PhyloPicMakie.jl` public APIs without network dependence: one overlay example and one grid example.
**Depends on**: 2

Add compact, show-off example scripts under `examples/src` that exercise the public surface without touching private helpers. One script must demonstrate explicit-coordinate overlays through public `augment_phylopic!` or `augment_phylopic_ranges!` entry points using deterministic pre-resolved image matrices or equivalent offline-safe inputs. A second script must demonstrate the thumbnail-gallery surface through public `phylopic_thumbnail_grid` or `phylopic_thumbnail_grid!` APIs, again in a deterministic way suitable for automated smoke checks. Save render outputs into `examples/build` or another clearly designated artifact directory. Keep the scripts visually credible, not bare smoke stubs, but do not introduce network dependence as the only path. End the task with each script runnable via its documented `julia --project=examples examples/src/<name>.jl` command.

### 4. Add a graph-oriented MWE using GraphMakie and MetaGraphsNext

**Type**: WRITE
**Output**: A standalone graph-based example script that demonstrates `PhyloPicMakie.jl` in a non-tree context using `Graphs.jl`, `MetaGraphsNext.jl`, and `GraphMakie.jl`.
**Depends on**: 3

Create a graph-oriented example under `examples/src` that uses `Graphs.jl` for graph structure, `MetaGraphsNext.jl` for node metadata, and `GraphMakie.graphplot` as the Makie rendering owner. The graph layout must be deterministic: either provide fixed `Point` positions directly or otherwise use an explicitly stable layout, rather than a random spring layout. Use GraphMakie's documented exposed node positions (`p[:node_pos]`) as the hand-off surface for overlay anchors, then route the silhouettes through public `PhyloPicMakie` APIs rather than private anchored-overlay internals. Keep the example independent of `PaleobiologyDB.jl`; the goal is to prove that a graph client can integrate with `PhyloPicMakie.jl` cleanly without tree-specific coupling. End the task with the graph example runnable and producing a saved artifact.

### 5. Add an optional live UUID showcase and classify it correctly

**Type**: WRITE
**Output**: If included, a clearly labeled manual or opt-in example script that demonstrates live `node_uuid`-driven PhyloPic fetching without becoming a required smoke dependency.
**Depends on**: 4

Add a live PhyloPic showcase script only if it materially improves the gallery. If you add one, keep it clearly separate from the deterministic smoke examples and mark it as manual or opt-in in the example index and docs. Use public UUID-driven APIs, and if caching helpers are needed for repeated runs, use the appropriate public dependency surface explicitly rather than inventing local cache toggles. Do not let this script become the only proof that the gallery works; automated verification for the tranche must still succeed without live network dependence. If a live showcase does not improve the gallery enough to justify its maintenance cost, document that decision in the examples index and omit it.

### 6. Wire the example gallery into docs, smoke verification, and CI

**Type**: CONFIG
**Output**: A lightweight, CI-friendly verification path for the deterministic examples, plus docs or README links that tell users how to run the gallery.
**Depends on**: 5

Add a small smoke runner for the deterministic examples, such as `examples/smoke.jl`, that includes the gallery scripts, executes their `main`-style entry points, and checks that expected output artifacts are produced. Keep this smoke path inside the isolated `examples` environment rather than folding it into the root package test environment. Update `.github/workflows/CI.yml` or an equivalent verification hook so the deterministic example smoke path runs automatically without requiring `PaleobiologyDB.jl` or interactive backends. Update `README.md`, `docs/src/index.md`, and any appropriate docs pages so users can discover the example gallery, understand which examples are deterministic versus manual/live, and run them using `julia --project=examples examples/src/<name>.jl`. End the task with the touched verification path green, including the examples smoke run and docs build if docs pages changed materially.
