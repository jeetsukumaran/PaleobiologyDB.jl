# Focused Tasking: Reset `PaleobiologyDB.jl` Examples To User-Facing Examples

## Scope

This tasking is intentionally narrow and disruptive within that narrow scope.

It covers the `PaleobiologyDB.jl/examples` surface and every place where that
surface was co-opted into CI, tests, docs-as-verification, or artifact-harness
responsibilities.

It does not reopen the broader tree-overlay architecture. It reclaims
`examples/` as a user-facing show-off and how-to surface.

## Settled user decisions

Implementation must treat the following as fixed input:

- `examples/` is for users, not for CI crunching, tranche verification, or test harness ownership.
- The current example entanglement is considered a design failure, not a feature to preserve.
- Strip examples out of CI, package tests, and other verification gates.
- Delete `examples/smoke.jl`.
- Replace the current `examples/src/taxonomytree.jl` with an idiomatic happy-path example.
- The resulting examples should be short, direct, and recognizable as examples rather than harnesses.
- `PaleobiologyDB.jl` is the only required scope for this reset unless touched docs or links force a minimal adjacent cleanup elsewhere.

## Governance

Mandated line-by-line reading applies before implementation begins.

All tasks must comply with:

- Bundled governance depot under `/home/jeetsukumaran/site/service/env/start/workhost/resources/packages/shared/workhost-resources/configure/coding-agent-skills/development-policies/references`
- [`CONTRIBUTING.md`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/CONTRIBUTING.md)
- [`STYLE-architecture.md`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-architecture.md)
- [`STYLE-docs.md`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-docs.md)
- [`STYLE-git.md`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-git.md)
- [`STYLE-julia.md`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-julia.md)
- [`STYLE-makie.md`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-makie.md)
- [`STYLE-upstream-contracts.md`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-upstream-contracts.md)
- [`STYLE-verification.md`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-verification.md)
- [`STYLE-vocabulary.md`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-vocabulary.md)
- [`STYLE-workflow-docs.md`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-workflow-docs.md)
- [`STYLE-writing.md`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/STYLE-writing.md)

Primary current-state owners that must be re-read in full before editing:

- [`examples/src/taxonomytree.jl`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/examples/src/taxonomytree.jl)
- [`examples/src/phylopicgallery.jl`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/examples/src/phylopicgallery.jl)
- [`examples/smoke.jl`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/examples/smoke.jl)
- [`examples/Project.toml`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/examples/Project.toml)
- [`examples/Manifest.toml`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/examples/Manifest.toml)
- [`test/taxonomytree_makie.jl`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/test/taxonomytree_makie.jl)
- [`docs/src/guide/taxonomytree_makie.md`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/docs/src/guide/taxonomytree_makie.md)
- [`README.md`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/README.md)
- [`docs/make.jl`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/docs/make.jl)
- [`.github/workflows/CI.yml`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/.github/workflows/CI.yml)

## Current-state diagnosis

The current examples surface is split across incompatible responsibilities:

- `examples/src/taxonomytree.jl` is no longer an example. It is a moduleized artifact harness with helper constructors, deterministic placeholder trees, build-directory output, and smoke-oriented entrypoints.
- `examples/smoke.jl` promotes examples into a verification owner.
- CI runs the example smoke harness directly.
- tests assert the smoke command and artifact-harness wording.
- user-facing docs describe the example directory partly as manual user guidance and partly as stabilization infrastructure.
- the `examples` environment itself likely needs audit because it currently includes tooling-oriented dependencies such as `Documenter`.

This is exactly the coupling the user wants removed.

## Non-negotiable execution rules

- Do not replace the deleted smoke harness with another examples-based CI or test gate under a different name.
- Do not leave `examples/src/taxonomytree.jl` as a module, artifact factory, or build-output owner.
- Do not preserve deterministic placeholder artifact generation inside user-facing examples.
- Do not make examples responsible for proving rendering correctness in CI.
- Do not keep docs language that presents examples as stabilization machinery.
- Do not keep test assertions that codify example smoke commands or artifact names as part of the supported contract.
- Do not add new tooling-oriented dependencies to the examples environment without a direct user-facing reason.

## Concrete anti-patterns or removal targets

The following items are explicit removal or demotion targets:

- `examples/smoke.jl`
- the `TaxonomyTreeExample` module wrapper in `examples/src/taxonomytree.jl`
- helper functions in `examples/src/taxonomytree.jl` that exist only to generate deterministic artifacts or write CI smoke outputs
- the CI step `Run taxonomy tree artifact smoke` in `.github/workflows/CI.yml`
- test assertions in `test/taxonomytree_makie.jl` that enforce `examples/smoke.jl`, placeholder artifact names, or docs wording about deterministic artifact harnesses
- guide prose in `docs/src/guide/taxonomytree_makie.md` that advertises `examples/smoke.jl`, `examples/build/`, or stabilization-oriented artifact generation as part of the example story
- any examples-environment dependency whose purpose is documentation or CI plumbing rather than running examples

## Failure-oriented verification

The final implementation must include checks that would fail if the bad example architecture came back:

- CI config must no longer invoke `examples/smoke.jl` or any replacement examples smoke harness.
- package tests must no longer assert example smoke commands, placeholder artifact filenames, or artifact-harness guide language.
- docs must no longer describe the examples directory as a stabilization or artifact-generation system.
- `examples/src/taxonomytree.jl` must be readable as a short happy-path example rather than a helper module or test harness.
- the user-facing examples must still be runnable manually in their intended environment after the cleanup.

## Tasks

### 1. Revalidate and inventory the examples entanglement surface

**Type**: REVIEW  
**Output**: A verified inventory of every place where `examples/` is currently coupled into CI, tests, docs, tracked artifacts, environment setup, or other non-example responsibilities.  
**Depends on**: none

Re-read the current example owners, CI workflow, tests, docs, and examples environment files in full. Confirm exactly which responsibilities belong to user-facing examples and which ones are accidental testing or CI accretions. Record whether `examples/Manifest.toml` and the `examples` dependency set are still justified for a user-facing examples story or are carrying tooling baggage. Do not edit production files in this task unless a tiny inspection-only probe is required.

### 2. Remove examples from CI and package-test ownership

**Type**: MIGRATE  
**Output**: CI and package tests no longer treat examples as a verification owner or artifact smoke system.  
**Depends on**: 1

Remove the examples-driven CI hook from `.github/workflows/CI.yml`. Remove or rewrite the corresponding example-smoke assertions from `test/taxonomytree_makie.jl` so the package test suite no longer codifies example harness behavior. If a docs or test assertion only exists to keep `examples/smoke.jl` alive, delete it rather than renaming it. The result should be that package verification stands on tests and docs builds, not on user-facing examples.

### 3. Delete the smoke harness and purge harness-oriented example scaffolding

**Type**: MIGRATE  
**Output**: `examples/smoke.jl` is gone, and the tree example surface no longer owns deterministic artifact generation or build-output plumbing.  
**Depends on**: 2

Delete `examples/smoke.jl`. Remove the harness-only machinery from `examples/src/taxonomytree.jl`, including module wrapping, build-directory management, placeholder-tree fabrication, artifact save helpers, and separate smoke entrypoints. If any tracked example outputs or references survive only because of this harness shape, delete or demote them too. The bad structure must actually disappear, not merely move into another helper file.

### 4. Rewrite `examples/src/taxonomytree.jl` as an idiomatic happy-path example

**Type**: WRITE  
**Output**: `examples/src/taxonomytree.jl` is a direct, readable user example for the intended tree-plus-PhyloPic happy path.  
**Depends on**: 3

Replace the current tree example with a simple example script that a user can run to see the intended experience. It should read like an example, not like infrastructure: load the required backend and extension surface, enable caching if that is part of the happy path, make the plot, and display or return the figure. Keep it short and idiomatic. Do not reintroduce helper modules, fake trees, artifact-writing branches, or dual-purpose smoke entrypoints.

### 5. Re-scope the examples environment and surrounding example prose

**Type**: WRITE  
**Output**: The examples environment and docs around it support user-facing examples rather than test or docs tooling.  
**Depends on**: 4

Audit `examples/Project.toml`, `examples/Manifest.toml`, `README.md`, and `docs/src/guide/taxonomytree_makie.md` from the perspective of a user running examples. Remove references to smoke harnesses, deterministic artifact generation, and `examples/build/` if those are no longer part of the story. If `Documenter` or other non-example dependencies in the examples environment are no longer justified, remove them. If `examples/Manifest.toml` remains, make sure its role is user-facing environment support rather than hidden verification coupling. Also audit `examples/src/phylopicgallery.jl` so the examples directory presents a coherent user-facing story rather than a half-example, half-tooling bundle.

### 6. Close with user-facing verification rather than examples-as-tests

**Type**: REVIEW  
**Output**: A truthful closeout showing that examples are decoupled from CI/tests and still runnable as user examples.  
**Depends on**: 5

Run the package’s real verification paths without any example-smoke gate. Then manually verify the intended user-facing example commands in the examples environment. Confirm that CI no longer invokes examples, tests no longer enforce example harness behavior, and docs no longer present the examples directory as stabilization infrastructure. This effort closes only if the examples surface is simpler, more user-facing, and no longer a Frankenstein blend of showcase and CI harness.

