# Tasks for Tranche 4: Finalize public surface and vocabulary cleanup

Parent tranche: Tranche 4
Parent PRD: `01_prd.md`
Related tranche tasking: `03_tranche-03-fixes--tasking.md`

## Governance

Mandated line-by-line reading applies to all relevant governance documents for both repositories. This tranche is the explicit public-break tranche for the tree-overlay surface, so downstream implementation must preserve the cross-repo governance set, the controlled vocabulary, the Tranche 4 HITL approval boundary, and the public-surface verification gates.

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

Controlled-vocabulary constraints that must be passed forward explicitly:

- `tip` is proscribed in code, docs, tests, examples, symbols, and public API names.
- Tranche 4 is not a blind string-replacement pass. Public names must distinguish leaf-node concepts from leaf-label concepts where the current `tip*` names blur them.
- No default deprecation shims or compatibility aliases are permitted unless the user explicitly approves an exception.

Current start-state notes that must not be dropped downstream:

- `PaleobiologyDB.jl/Project.toml` was updated in commit `b2bc796` so the main package source is no longer pinned to the old `PhyloPicMakie` development branch.
- `test/Project.toml` and the committed manifests still require revalidation against the currently approved `PhyloPicMakie` surface. This dependency-alignment follow-up should be treated as an early checkpoint in this tranche rather than silently ignored.
- The public tree surface is still heavily `tip*`-based in exports, recipe attributes, anchor symbols, README, guide docs, API docs, tests, and examples.

Read-only git and shell commands may be used freely. Mutating git operations such as commit, merge, push, and branch remain the human project owner's responsibility unless the user explicitly instructs otherwise.

## Required revalidation before implementation

- Read Tranche 4 in `02_tranches.md`, the parent PRD in `01_prd.md`, and this tasking file in full.
- Re-read the current public-surface owners in full:
  - `ext/TaxonomyMakie/TaxonomyMakie.jl`
  - `ext/TaxonomyMakie/_augment.jl`
  - `ext/TaxonomyMakie/_layout.jl`
  - `ext/TaxonomyMakie/_recipe.jl`
  - `ext/TaxonomyMakie/_leaf_overlay.jl`
  - `README.md`
  - `docs/src/api/taxonomytree_makie.md`
  - `docs/src/guide/taxonomytree_makie.md`
  - `docs/src/guide/caching.md`
  - `examples/src/taxonomytree.jl`
  - `test/taxonomytree_makie.jl`
  - `Project.toml`
  - `test/Project.toml`
  - `Manifest.toml`
  - `test/Manifest.toml`
- Re-read the relevant `PhyloPicMakie.jl` public-surface owners if this tranche proposes public-name or doc changes there:
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/README.md`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/docs/src/index.md`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/docs/src/examples.md`
- Reconfirm the current exported and documented `tip*` surface, including:
  - `tip_positions`
  - `augment_tip_phylopic!`
  - `showtips`
  - `tip_fontsize`
  - `tip_color`
  - `tip_xoffset`
  - `tip_yoffset`
  - anchor symbols such as `:tip` and `:tip_label_origin`
- Reconfirm the remaining dependency/source state honestly:
  - `Project.toml` is no longer branch-pinned and must stay that way unless the user later approves a new pin.
  - `test/Project.toml` and the manifests must be checked for stale branch or stale tree-state assumptions before public rename work proceeds.
- If the tranche diagnosis no longer matches reality, or if Tranche 3 still is not honestly green enough for a public-break follow-on, stop and raise that before changing code.

## Tranche execution rule

This is the explicit public-break tranche. It may hard-rename the current unreleased `tip*`-heavy tree surface with no deprecation aliases by default, but it must not guess at the final public vocabulary. The work must:

- produce a concrete break matrix,
- distinguish leaf-node names from leaf-label names rather than performing a mechanical `tip -> leaf` substitution,
- obtain explicit user approval of that break matrix before the public code rename closes,
- preserve the repaired owner boundary from Tranche 3 rather than regrowing shadow APIs,
- and end with the approved final surface reflected consistently across code, tests, docs, README, and examples.

If a clean fix appears to require a public `PhyloPicMakie.jl` rename or doc break in addition to the `PaleobiologyDB.jl` tree-surface cleanup, surface that in the break matrix and include the corresponding cross-repo verification. Do not smuggle it in implicitly.

## Tasks

### 1. Revalidate the public surface, vocabulary scope, and dependency baseline

**Type**: REVIEW  
**Output**: A verified Tranche 4 start-state inventory covering the public `tip*` surface, the distinction between leaf-node and leaf-label semantics, the files that still describe the old surface, and the current `PhyloPicMakie` source and manifest alignment state in package and test environments.  
**Depends on**: none

Read the parent PRD, Tranche 4, the active governance set, and the current public-surface owner files in full. Reproduce the public inventory honestly rather than relying on prior tranche assumptions. Confirm that `Project.toml` is now unpinned from the old branch, and check whether `test/Project.toml`, `Manifest.toml`, or `test/Manifest.toml` still lag behind the approved upstream state. Identify which current names are truly leaf-node concepts and which are really leaf-label concepts so the later rename set is semantically correct. Do not edit production files in this task unless a tiny verification-only probe is required to establish reality.

### 2. Align the package and test dependency state with the approved upstream surface

**Type**: CONFIG  
**Output**: `PaleobiologyDB.jl` package and test environments resolve against the currently approved `PhyloPicMakie` surface without stale branch pinning or stale manifest state that would make the public-surface rename tranche dishonest.  
**Depends on**: 1

Preserve the new unpinned main-package source policy from `Project.toml`, and fix any remaining stale dependency declarations or manifests only where the revalidation proves they still encode outdated `PhyloPicMakie` assumptions. Touch `test/Project.toml`, `Manifest.toml`, and `test/Manifest.toml` if required. Do not reintroduce a development-branch pin merely to make the tranche convenient. End this task with the repository in an honest, dependency-aligned state for the public-surface work that follows.

### 3. Produce the final public break matrix and obtain user approval

**Type**: REVIEW  
**Output**: An explicit, user-approved break matrix listing every renamed function, keyword, symbol, attribute, removed helper, and externally visible behavior wording change required to bring the final tree surface into vocabulary compliance.  
**Depends on**: 1, 2

Build the exact public rename set before mutating the public API. This matrix must include the current exported and documented names such as `tip_positions`, `augment_tip_phylopic!`, `showtips`, `tip_fontsize`, `tip_color`, `tip_xoffset`, `tip_yoffset`, `:tip`, and `:tip_label_origin`, along with the approved replacements. Do not assume that every replacement is a literal `leaf*` form; where the current name is really label-oriented, propose a leaf-label-oriented name and explain why. Include README, docs, examples, tests, and any `PhyloPicMakie.jl` public-surface implications if they exist. Pause for explicit user approval before any task that changes the public surface proceeds.

### 4. Apply the approved public rename set in code and exports

**Type**: MIGRATE  
**Output**: The approved `leaf*` and leaf-label-based public surface replaces the old `tip*` surface across exported names, recipe attributes, helper entrypoints, and public symbols, with no default deprecation layer.  
**Depends on**: 3

Implement the approved break matrix across the public code owners in `TaxonomyMakie`. Touch `ext/TaxonomyMakie/TaxonomyMakie.jl`, `_augment.jl`, `_layout.jl`, `_recipe.jl`, and `_leaf_overlay.jl` as needed so the exported surface, recipe attribute names, anchor symbols, public docstrings, and helper references all match the approved vocabulary. Preserve the Tranche 3 owner boundary and do not leave dual-surface aliases behind unless the user explicitly approved them in Task 3. If an internal name can remain non-public temporarily without violating vocabulary or clarity, document that decision in code comments only if truly needed and keep the public surface clean.

### 5. Update tests and executable examples to lock in the approved surface

**Type**: TEST  
**Output**: Automated coverage and runnable example entrypoints use the approved final surface and would fail if the old `tip*` API were silently reintroduced.  
**Depends on**: 4

Update `test/taxonomytree_makie.jl` and any other touched tests so they exercise the approved final public API rather than internal transitional names. Strengthen public-surface checks around exports, keywords, anchor symbols, and documented two-step tree-overlay usage. Update `examples/src/taxonomytree.jl` and any other executable examples touched by the rename so they reflect the approved surface. If a live example is run for verification, use `set_autocaching!(true)` where appropriate. End this task with the touched verification scope green.

### 6. Rewrite docs and README to the approved final vocabulary and behavior wording

**Type**: WRITE  
**Output**: README, API docs, guide docs, and any touched example prose describe only the approved final tree surface and no longer preserve stale `tip*` language or outdated placeholder behavior wording.  
**Depends on**: 4

Update `README.md`, `docs/src/api/taxonomytree_makie.md`, `docs/src/guide/taxonomytree_makie.md`, and any other touched docs so they describe the approved final public names exactly. Remove stale prose such as “leaf tip” when the intended concept is a leaf label, and update any remaining placeholder text that still claims `:placeholder` draws a grey rectangle if the actual renderer now uses a placeholder glyph image. If `PhyloPicMakie.jl` public docs are touched because the approved break matrix reaches that far, update those docs and keep the cross-repo wording aligned.

### 7. Close the tranche with explicit break approval and end-green verification

**Type**: REVIEW  
**Output**: A truthful Tranche 4 closeout showing the approved final break set, the final public surface, the completed automated gates, and the absence of lingering `tip*` vocabulary in code, tests, docs, README, and examples.  
**Depends on**: 5, 6

Run the tranche-required end-green checks honestly. In `PaleobiologyDB.jl`, rerun `julia --project=test test/runtests.jl` and `julia --project=docs docs/make.jl`. If this tranche changed `PhyloPicMakie.jl` public names or docs, rerun `julia --project=. -e 'import Pkg; Pkg.test()'` there and build touched docs with `julia --project=docs docs/make.jl`. Confirm that the user-approved break matrix from Task 3 matches the shipped surface exactly, that no stale `tip*` public names remain, and that no stale dependency or manifest assumptions were left behind while carrying the rename through. This tranche closes only if the final public surface and the documentation truthfully match each other.
