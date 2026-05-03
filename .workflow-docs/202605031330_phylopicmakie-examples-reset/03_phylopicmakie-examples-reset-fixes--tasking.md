# Focused Repair Tasking: Keep `PhyloPicMakie.jl` Examples User-Facing

## Scope

This repair tasking is narrowly scoped to the `PhyloPicMakie.jl/examples`
reset.

It exists to prevent a fake cleanup where the old smoke harness disappears but
the examples still behave like infrastructure: moduleized artifact writers,
path-returning scripts, build-directory contracts, or docs/CI string-policing
that merely enforces the absence of the old machinery.

It does not reopen `PhyloPicMakie.jl` rendering architecture. It repairs the
example-reset tasking boundary so the result is a genuinely better examples
surface for users.

## Settled user decisions

Implementation must treat the following as fixed input:

- `examples/` is a user-facing gallery and how-to surface, not a smoke or CI
  owner.
- deleting `examples/smoke.jl` is necessary but not sufficient.
- the gallery scripts should be direct, legible examples rather than
  module-wrapped artifact factories.
- the reset must not be paid for by moving example ownership into tests, docs
  string assertions, or CI YAML policing.
- a good outcome is positive and user-facing: when run manually, the example
  commands must do something visibly useful.

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

Primary current-state owners that must be re-read in full before editing:

- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/src/_common.jl`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/src/explicit_overlays.jl`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/src/thumbnail_gallery.jl`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/src/graph_anchors.jl`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/README.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/docs/src/examples.md`
- `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/.github/workflows/CI.yml`

## Current-state diagnosis

The current `PhyloPicMakie.jl` gallery still has the exact shapes that can make
an examples reset fail superficially:

- each script is module-wrapped and oriented around `main(; output_dir = ...)`
  returning a saved artifact path.
- `_common.jl` owns build-directory and save-path infrastructure.
- README and docs still present the gallery as deterministic artifact
  generation for smoke or regression purposes.
- `graph_anchors.jl` already contains nuanced explanatory prose, which means a
  bad reset could preserve the same infrastructure shape while only improving
  wording.

The central failure risk is therefore not only “forget to delete `smoke.jl`.”
It is “delete `smoke.jl` but keep the gallery as infrastructure.”

## Non-negotiable execution rules

- Do not replace deleted smoke ownership with new docs-string assertions,
  README-string assertions, CI-YAML assertions, or source-text policing.
- Do not move example logic, rendering logic, or gallery-truth enforcement into
  package tests or docs-build helpers.
- Do not keep module wrappers or `return saved path` contracts unless a script
  is clearly recast as a user-directed save example rather than hidden
  infrastructure.
- Do not preserve `examples/build/` as a contract merely because it was used by
  the old smoke flow.
- Do not accept a cleanup that leaves the scripts runnable only as artifact
  emitters with no direct user-facing payoff.

## Concrete anti-patterns or removal targets

The following items are explicit removal or demotion targets:

- `examples/smoke.jl`
- the `module ... end` wrapper shape in:
  - `examples/src/explicit_overlays.jl`
  - `examples/src/thumbnail_gallery.jl`
  - `examples/src/graph_anchors.jl`
- `_common.jl` helpers whose main role is build-directory ownership or
  path-returning save contracts
- README or docs prose that centers deterministic artifacts, `examples/build/`,
  or smoke verification as the gallery story
- any new assertions whose main role is to lock down example command strings,
  docs wording, or CI-text absence rather than verify a positive user outcome

## Failure-oriented and positive verification

The final implementation must include checks that would fail if the bad reset
happened:

- CI must no longer invoke `examples/smoke.jl` or any renamed equivalent.
- package verification must not gain new ownership over example prose or command
  strings.
- the examples must read as direct scripts, not infrastructure modules.
- the manual run story must be coherent and obvious from the docs.
- the example commands must produce a positive user-facing outcome when run
  manually: a visible figure in an interactive session, or a clearly
  user-directed save result that is part of the example itself rather than a
  hidden artifact-pipeline contract.

## Tasks

### 1. Revalidate the gallery reset against the current `PhyloPicMakie.jl` example owners

**Type**: REVIEW  
**Output**: A verified inventory of where the gallery is still infrastructure-shaped and where a fake cleanup could hide.  
**Depends on**: none

Re-read the current examples, shared helper layer, README, docs, and CI files
in full. Identify the exact places where the current gallery still behaves like
artifact infrastructure rather than direct examples. Record whether any package
tests or docs helpers already touch example ownership, and make sure this fix
pass does not expand that boundary.

### 2. Remove smoke ownership without recreating it as text-policing

**Type**: MIGRATE  
**Output**: Examples are no longer CI-owned or smoke-owned, and that coupling has not been recreated elsewhere.  
**Depends on**: 1

Delete `examples/smoke.jl` if it still exists and remove any CI hook or docs
story that exists only to support it. Do not replace the removed smoke contract
with new source-text assertions or policing over docs, README, or YAML. The
result should be genuine decoupling, not a renamed enforcement mechanism.

### 3. Simplify the shared helper layer and script shape

**Type**: WRITE  
**Output**: Shared helper code, if any remains, supports direct examples rather than artifact-pipeline ownership.  
**Depends on**: 2

Refactor `examples/src/_common.jl` and the three example scripts so the gallery
stops centering build-directory ownership, `output_dir` plumbing, and
path-returning script contracts. Some shared helper code may survive, but only
if it genuinely improves legibility for readers. Remove module wrappers and
artifact-factory structure unless a specific example is explicitly and
transparently a save-to-file example for users.

### 4. Rewrite the gallery as direct user-facing examples with positive outcomes

**Type**: WRITE  
**Output**: Each example script is readable, runnable, and clearly useful to a human user.  
**Depends on**: 3

Rewrite `examples/src/explicit_overlays.jl`,
`examples/src/thumbnail_gallery.jl`, and `examples/src/graph_anchors.jl` so
they read as direct examples first. Preserve the good explanatory content where
it helps, but make the runtime outcome user-facing: the scripts should either
display figures directly in an interactive context or save results in a way
that is explicit and useful to the user rather than hidden infrastructure.
This task fails if the scripts still mainly act like artifact emitters.

### 5. Rewrite the examples docs and environment story around the new surface

**Type**: WRITE  
**Output**: README/docs/examples prose matches a simple, user-facing gallery rather than a regression-artifact pipeline.  
**Depends on**: 4

Update `examples/README.md`, `README.md`, `docs/src/examples.md`, and any
touched examples-environment files so the documented story is “how a user runs
these examples,” not “how CI or smoke verification consumes deterministic
artifacts.” Keep local manifest behavior truthful, but do not make manifests or
build outputs the center of the gallery contract.

### 6. Close with real user-facing verification

**Type**: REVIEW  
**Output**: A truthful closeout showing that the gallery is simpler, decoupled, and actually good to run.  
**Depends on**: 5

Run the package’s real verification paths without any examples smoke gate, then
manually run the supported example commands. Confirm that the examples are
legible, decoupled from CI ownership, and produce genuinely useful results when
run by a user. This repair fails if the end state is mostly anti-goal cleanup
without a clear positive example experience.
