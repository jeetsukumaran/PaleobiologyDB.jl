# Focused Tasking: Reset `PhyloPicMakie.jl` Examples To User-Facing Examples

## Scope

This tasking is intentionally narrow and disruptive within that narrow scope.

It covers the `PhyloPicMakie.jl/examples` surface and every place where that
surface was co-opted into CI, smoke verification, docs-as-artifact-pipeline,
or tracked gallery-output responsibilities.

It does not reopen the broader `PhyloPicMakie.jl` rendering architecture. It
reclaims `examples/` as a user-facing show-off and how-to surface.

## Settled user decisions

Implementation must treat the following as fixed input:

- `examples/` is for users, not for CI gating, smoke verification ownership, or artifact-pipeline ownership.
- The current examples coupling is considered a design failure, not a contract to preserve.
- Strip examples out of CI and smoke-verification ownership.
- Delete `examples/smoke.jl`.
- Reframe the examples as idiomatic user-facing scripts rather than moduleized artifact factories.
- Keep the examples coherent as a gallery, but prioritize direct, runnable user examples over deterministic regression machinery.
- This reset is scoped to `PhyloPicMakie.jl`; do not reopen `PaleobiologyDB.jl` architecture as part of it.

## Governance

Mandated line-by-line reading applies before implementation begins.

All tasks must comply with:

- Bundled governance depot under `/home/jeetsukumaran/site/service/env/start/workhost/resources/packages/shared/workhost-resources/configure/coding-agent-skills/development-policies/references`
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
- `PaleobiologyDB.jl` governance files only where touched docs or cross-repo references require a minimal adjacent cleanup

Primary current-state owners that must be re-read in full before editing:

- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/README.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/Project.toml`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/Manifest.toml`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/smoke.jl`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/src/_common.jl`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/src/explicit_overlays.jl`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/src/thumbnail_gallery.jl`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/src/graph_anchors.jl`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/README.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/docs/src/examples.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/docs/src/index.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/.github/workflows/CI.yml`

## Current-state diagnosis

The current `PhyloPicMakie.jl` examples surface is more polished than the
recent `PaleobiologyDB.jl` tree example, but it still mixes incompatible
responsibilities:

- `examples/smoke.jl` turns the examples gallery into a smoke-verification owner.
- CI runs the examples smoke gallery directly.
- README and docs present the gallery partly as user examples and partly as a
  deterministic artifact-production path for CI-friendly verification.
- the example scripts are moduleized artifact writers that save PNGs into
  `examples/build/` instead of reading primarily as direct runnable examples.
- tracked gallery outputs currently exist in `examples/build/`, which makes the
  examples surface carry artifact-state baggage as well as example logic.

This is exactly the coupling the user wants removed.

## Non-negotiable execution rules

- Do not replace `examples/smoke.jl` with a renamed smoke harness that keeps examples in CI.
- Do not leave examples as moduleized artifact factories whose primary contract is “return a saved PNG path.”
- Do not keep README or docs language that presents the gallery as deterministic CI verification infrastructure.
- Do not keep tracked gallery-output files merely because the old smoke flow wrote them.
- Do not let cross-repo references to `PaleobiologyDB.jl` creep back into the examples story except where public docs explicitly need to point to a separate integrating client.
- Do not add new CI or test coupling around examples while removing the current one.

## Concrete anti-patterns or removal targets

The following items are explicit removal or demotion targets:

- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/smoke.jl`
- the `Run examples smoke gallery` step in `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/.github/workflows/CI.yml`
- README and docs wording that advertise `examples/smoke.jl` or `examples/build/` as the supported gallery story
- the module-wrapped artifact-writer shape in:
  - `examples/src/explicit_overlays.jl`
  - `examples/src/thumbnail_gallery.jl`
  - `examples/src/graph_anchors.jl`
- tracked gallery PNG outputs in `examples/build/` if they exist only to support the old smoke or CI story
- any examples-environment dependency or tracked file whose role is primarily smoke/CI/tooling rather than user-facing example execution

## Failure-oriented verification

The final implementation must include checks that would fail if the bad gallery architecture came back:

- CI config must no longer invoke `examples/smoke.jl` or any direct replacement examples smoke runner.
- README and docs must no longer frame the examples gallery as CI-friendly deterministic artifact verification.
- the example scripts must be readable as direct user examples rather than helper modules whose main job is writing output files.
- the examples directory must still offer a coherent manual run story after the cleanup.
- if tracked build artifacts are removed, the gallery must remain understandable and runnable without them.

## Tasks

### 1. Revalidate and inventory the `PhyloPicMakie.jl` examples entanglement surface

**Type**: REVIEW  
**Output**: A verified inventory of every place where `PhyloPicMakie.jl/examples` is currently coupled into CI, smoke verification, tracked artifact outputs, docs, README guidance, or environment/tooling baggage.  
**Depends on**: none

Re-read the current examples, README, docs, CI workflow, and examples environment files in full. Confirm exactly which aspects of the current gallery are genuinely user-facing and which are artifact or verification accretions. Record whether tracked build outputs and tracked `examples/Manifest.toml` are still justified for a user-facing gallery or are carrying smoke-era baggage. Do not edit production files in this task unless a tiny inspection-only probe is required.

### 2. Remove examples from CI and smoke-verification ownership

**Type**: MIGRATE  
**Output**: `PhyloPicMakie.jl` CI no longer treats the examples gallery as a smoke-verification owner.  
**Depends on**: 1

Remove the examples-driven smoke step from `.github/workflows/CI.yml`. If any docs or adjacent verification text in the repo exists only to justify or mirror that CI step, remove or rewrite it rather than renaming the smoke flow. The result should be that package verification stands on tests and docs, not on the user-facing examples gallery.

### 3. Delete `examples/smoke.jl` and purge smoke-oriented gallery scaffolding

**Type**: MIGRATE  
**Output**: `examples/smoke.jl` is gone, and the gallery no longer owns a deterministic smoke-entrypoint contract.  
**Depends on**: 2

Delete `examples/smoke.jl`. Remove any gallery-wide wording, helper structure, or file-level assumption that exists only because that smoke entrypoint existed. If any tracked gallery outputs or artifact-oriented references survive only because of the smoke story, delete or demote them too. The bad structure must actually disappear, not merely move into another helper file.

### 4. Rewrite the gallery scripts as idiomatic user-facing examples

**Type**: WRITE  
**Output**: The example scripts in `examples/src` read as direct, runnable user examples rather than moduleized artifact writers.  
**Depends on**: 3

Rewrite `examples/src/explicit_overlays.jl`, `examples/src/thumbnail_gallery.jl`, and `examples/src/graph_anchors.jl` so they primarily serve as human-readable examples. Shared visual helper code in `_common.jl` may survive if it still deepens the example surface rather than turning the gallery back into infrastructure. Remove unnecessary module wrapping, “return saved path” shaped APIs, and output-pipeline ownership if those remain only because of the old smoke architecture. Keep the examples coherent as a gallery, but optimize for clarity and direct run experience.

### 5. Re-scope the examples environment, tracked gallery outputs, and surrounding prose

**Type**: WRITE  
**Output**: The examples environment and gallery docs support user-facing examples rather than artifact-pipeline ownership.  
**Depends on**: 4

Audit `examples/Project.toml`, `examples/Manifest.toml`, `examples/README.md`, `README.md`, and `docs/src/examples.md` from the perspective of a user running examples. Remove references to smoke verification, deterministic CI artifact generation, and `examples/build/` if those are no longer part of the supported story. If tracked gallery PNGs in `examples/build/` exist only to support the old smoke pipeline, remove them and keep only what is necessary for a clean user-facing examples directory. Keep any environment files only if they are justified by the new examples story rather than by old CI needs.

### 6. Close with user-facing verification rather than gallery-as-smoke-harness

**Type**: REVIEW  
**Output**: A truthful closeout showing that `PhyloPicMakie.jl` examples are decoupled from CI smoke ownership and still runnable as user examples.  
**Depends on**: 5

Run the package’s real verification paths without any examples smoke gate. Then manually verify the intended user-facing example commands in the examples environment. Confirm that CI no longer invokes the gallery, docs no longer present the examples directory as deterministic verification infrastructure, and the gallery now reads and behaves like a user-facing examples surface rather than a hybrid showcase/test harness system.

