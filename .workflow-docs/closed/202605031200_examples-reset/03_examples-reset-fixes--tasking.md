# Focused Repair Tasking: Fix the Broken `PaleobiologyDB.jl` Examples Reset

## Scope

This tasking repairs the current bad implementation of the
`PaleobiologyDB.jl` examples reset from the current repository state.

It is not a fresh redesign from scratch. It is a corrective pass over a reset
that went wrong in two main ways:

- it overfit the cleanup by adding new docs and CI string-policing assertions in
  `test/taxonomytree_makie.jl`, and
- it replaced the old tree harness with a nominally simple example that does
  not yet have a strong positive user-facing success contract.

## Settled user decisions

Implementation must treat the following as fixed input:

- The reset direction itself was correct: examples should not be CI or package-test owners.
- The implementation quality of that reset was not acceptable.
- Do not revert the whole reset wholesale if that would restore the deleted smoke harness and CI coupling.
- Repair from the current state surgically.
- Remove the example-reset-specific overfitting from `test/taxonomytree_makie.jl`.
- Do not turn the examples reset into a broader docs-truth, import-contract, or CI-text policing exercise.
- The desired outcome is positive, not merely subtractive:
  - examples are user-facing again,
  - `examples/src/taxonomytree.jl` is actually useful when run,
  - and the examples story is simpler without becoming blank or noop-like.

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

Current-state owners that must be re-read in full before editing:

- [`examples/src/taxonomytree.jl`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/examples/src/taxonomytree.jl)
- [`examples/src/phylopicgallery.jl`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/examples/src/phylopicgallery.jl)
- [`examples/Project.toml`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/examples/Project.toml)
- [`README.md`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/README.md)
- [`docs/src/guide/taxonomytree_makie.md`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/docs/src/guide/taxonomytree_makie.md)
- [`test/taxonomytree_makie.jl`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/test/taxonomytree_makie.jl)
- [`.github/workflows/CI.yml`](/home/jeetsukumaran/site/storage/local/computing/research/20250825_PaleobiologyDB.jl/PaleobiologyDB.jl/.github/workflows/CI.yml)

## Current-state diagnosis

The reset currently fails in two ways:

1. It introduced new negative string-locking in `test/taxonomytree_makie.jl`
   around docs prose, example commands, and CI text.

2. It did not define or verify a strong positive success condition for the new
   `examples/src/taxonomytree.jl` script, so the cleanup can be “simple” while
   still being blank, noop-like, or otherwise not useful to a user.

Those are the repair targets. The smoke harness removal itself is not the
problem.

## Non-negotiable execution rules

- Do not reintroduce `examples/smoke.jl`.
- Do not reintroduce examples-driven CI gating.
- Do not fix the overfitting by deleting all example-related test coverage indiscriminately if some broader non-example tests legitimately belong there.
- Do not add any new source-text assertions over README, guide prose, CI YAML, or example command strings as part of this repair.
- Do not move example logic, rendering logic, or example execution ownership into `test/taxonomytree_makie.jl`.
- Do not “fix” the blank/useless example by rebuilding artifact-harness machinery.
- Do not close the repair on “it runs without error” alone. The tree example must have a positive, user-obvious outcome.

## Concrete anti-patterns or removal targets

The following are explicit repair targets:

- the example-reset-specific assertions in `test/taxonomytree_makie.jl` that lock in:
  - exact example commands,
  - absence of `examples/smoke.jl`,
  - absence of `examples/build/`,
  - or absence of CI step text
- any example-reset-specific docs or README wording that exists only to satisfy those assertions rather than help users
- any current `examples/src/taxonomytree.jl` behavior that leaves the user without a clear visible result when running the script in the intended examples environment

## Failure-oriented verification

The final repair must include checks that would fail if the bad repair pattern came back:

- `test/taxonomytree_makie.jl` must no longer own the examples reset by policing docs text, CI text, or exact example commands
- `.github/workflows/CI.yml` must still remain free of the deleted example-smoke gate
- `examples/src/taxonomytree.jl` must be manually runnable in the intended examples environment and must produce a clearly useful user-facing result
- the repaired example must remain simple and idiomatic rather than drifting back toward moduleized harness logic

## Tasks

### 1. Revalidate the current bad reset state and isolate the repair surface

**Type**: REVIEW  
**Output**: A verified inventory of exactly which current files and behaviors are bad because of the broken reset implementation, separated from the parts of the reset that should remain.  
**Depends on**: none

Read the current example files, docs, CI workflow, and `test/taxonomytree_makie.jl` in full. Separate the healthy parts of the reset from the broken ones. In particular, identify which test assertions were added only to lock in cleanup prose or CI text, and identify the actual user-facing failure mode of the current `examples/src/taxonomytree.jl` script. Do not edit files in this task unless a tiny inspection-only probe is required.

### 2. Remove the reset-specific overfitting from `test/taxonomytree_makie.jl`

**Type**: MIGRATE  
**Output**: The package test suite no longer owns the examples reset through docs-string, CI-string, or example-command policing.  
**Depends on**: 1

Delete or simplify the example-reset-specific assertions in `test/taxonomytree_makie.jl` that only lock in source text or cleanup anti-goals. Preserve broader legitimate tests that belong to extension import truth or owner-boundary behavior, but do not let this file remain the owner of the examples story. The result should be a clear reduction in overfit negative checks rather than a rewrite of them into slightly different string assertions.

### 3. Repair `examples/src/taxonomytree.jl` into a positively successful happy-path example

**Type**: WRITE  
**Output**: `examples/src/taxonomytree.jl` is short, idiomatic, and manually runnable with a clearly useful user-facing result.  
**Depends on**: 2

Keep the current simplified direction, but repair the actual user experience. The example should be obviously an example and should do something visibly useful when run in the intended examples environment. If the current backend and script mode require an explicit output choice to make the result user-visible, make that choice intentionally and document it simply. Do not reintroduce artifact harnesses, fake trees, save-helper modules, build directories, or smoke-shaped branching.

### 4. Reconcile the surrounding docs and README to the repaired example story

**Type**: WRITE  
**Output**: README and guide prose describe the repaired example honestly, without CI-harness baggage and without overfitted cleanup wording.  
**Depends on**: 3

Update `README.md` and `docs/src/guide/taxonomytree_makie.md` only as needed to match the repaired example story. Optimize for useful user guidance, not for tests. Keep the examples section simple and human-facing. Do not add new wording whose only purpose is to support negative source-text assertions.

### 5. Close with manual user-facing verification and minimal regression sanity checks

**Type**: REVIEW  
**Output**: A truthful closeout showing that the examples reset remains decoupled from CI/tests and that the tree example is actually useful again.  
**Depends on**: 4

Verify that the deleted examples-driven CI gate is still gone. Verify that the package tests no longer own the examples reset through string-policing. Then manually run the repaired example in the intended examples environment and confirm it produces a clearly useful user-facing result. The repair is complete only if the examples surface stays simple, the smoke harness stays dead, and the example is positively good rather than merely less bad.

