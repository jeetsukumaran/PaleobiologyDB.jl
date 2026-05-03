# Tasks for Tranche 4 fixes: Public-surface cleanup, owner-boundary repair, and doc contract truth

Parent tranche: Tranche 4  
Parent PRD: `01_prd.md`  
Related tranche tasking: `03_tranche-04--tasking.md`

## Why this fixes tasking exists

The prior Tranche 4 implementation reported green, but the review found that it did not honestly satisfy the tranche contract.

The main failures were:

- `PaleobiologyDB.jl` regrew a shadow generic anchored-overlay owner in `ext/TaxonomyMakie/PhyloPic/src/_render.jl` instead of preserving the repaired Tranche 3 owner boundary.
- The tranche still carried stale dependency assumptions and compatibility code even though the right fix was to align the environment honestly.
- The HITL approval state was real in conversation, but the tasking did not carry that approved break set forward explicitly enough for a fresh agent.
- The docs and README changed names but still described a false import story.
- A touched public docstring still claimed `on_missing = :placeholder` draws a grey rectangle when the renderer now uses a placeholder glyph image.

This fixes tasking is intentionally stricter than the original tranche tasking. It is meant to be executable by a fresh agent without relying on hidden context from the conversation.

## Governance

Mandated line-by-line reading applies to all relevant governance documents for both repositories. This fix pass remains inside the Tranche 4 public-surface cleanup boundary, but it must also preserve the architecture repair achieved in Tranche 3 instead of weakening it.

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

## Human decisions already made

These decisions are already made and approved by the user. Downstream implementation must treat them as settled unless a new conflict is discovered that truly requires escalation.

### 1. Public break approval is already granted

The HITL approval requirement for the Tranche 4 rename set is satisfied in conversation. Do not stop to ask for the same approval again.

This fixes tasking file is now the durable workflow artifact carrying that approval forward.

### 2. Approved public break matrix

The following public rename set is approved:

- `tip_positions` -> `leaf_positions`
- `augment_tip_phylopic!` -> `augment_leaf_phylopic!`
- `showtips` -> `show_leaf_labels`
- `tip_fontsize` -> `leaf_label_fontsize`
- `tip_color` -> `leaf_label_color`
- `tip_xoffset` -> `leaf_label_xoffset`
- `tip_yoffset` -> `leaf_label_yoffset`
- `:tip` -> `:leaf`
- `:tip_label_origin` -> `:leaf_label_origin`

Further instructions on that approved break set:

- No deprecation shims or dual-surface aliases are wanted.
- Do not reopen the rename debate unless a concrete semantic conflict appears.
- Where prose previously used `tip` for a label concept, the final wording should be leaf-label-oriented rather than mechanically leaf-node-oriented.

### 3. Manifest policy for this fix pass

The user deleted both `Manifest.toml` and `test/Manifest.toml` to rebuild cleanly.

That means:

- `Manifest.toml` is intentionally absent at repo root.
- `test/Manifest.toml` is intentionally absent.
- Do not recreate or commit either manifest in this fix pass unless the user explicitly changes that policy later.
- Fresh dependency resolution during verification is acceptable and expected.

### 4. Import-story decision

The docs must be fixed to match reality.

That means:

- Do not "fix" the docs by expanding `PaleobiologyDB` top-level exports unless the user explicitly asks for that API change.
- The truthful import story is extension-module based.
- The docs and examples should use `PaleobiologyDB.TaxonomyMakie` or explicit qualification where appropriate.

## Prior tasking gaps that must not repeat

The earlier tasking was too permissive in four ways. These gaps are now closed explicitly:

- It did not forbid a compatibility fallback that regrew a second generic rendering owner in `PaleobiologyDB.jl`.
- It did not explicitly say that, once human break approval existed, the agent should record and carry it forward rather than treating it as missing.
- It did not explicitly forbid solving the doc import mismatch by silently changing the parent-module export surface.
- It did not anticipate the user deleting manifests and therefore did not say clearly that the honest next state is "no committed manifests," not "rebuild a different stale one."

If a downstream implementation would reintroduce any of those failures, it is not an acceptable completion of this fix pass.

## Required revalidation before implementation

- Read Tranche 4 in `02_tranches.md`, the parent PRD in `01_prd.md`, `03_tranche-04--tasking.md`, and this fixes tasking file in full.
- Re-read the reviewed `PaleobiologyDB.jl` files in full:
  - `Project.toml`
  - `test/Project.toml`
  - `README.md`
  - `docs/src/api/taxonomytree_makie.md`
  - `docs/src/guide/taxonomytree_makie.md`
  - `examples/src/taxonomytree.jl`
  - `ext/TaxonomyMakie/TaxonomyMakie.jl`
  - `ext/TaxonomyMakie/_augment.jl`
  - `ext/TaxonomyMakie/_layout.jl`
  - `ext/TaxonomyMakie/_leaf_overlay.jl`
  - `ext/TaxonomyMakie/_recipe.jl`
  - `ext/TaxonomyMakie/PhyloPic/src/PhyloPic.jl`
  - `ext/TaxonomyMakie/PhyloPic/src/_resolve.jl`
  - `ext/TaxonomyMakie/PhyloPic/src/_render.jl`
  - `test/phylopic_makie.jl`
  - `test/taxonomytree_makie.jl`
- Re-read the relevant `PhyloPicMakie.jl` owner files in full if the owner-boundary repair requires touching the adjacent repo:
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/PhyloPicMakie.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_augment_api.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_anchored_overlay.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/src/_render_core.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/test/test_anchored_overlay.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/test/test_render_core.jl`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/test/test_makie_integration.jl`
- Reproduce the reviewed failures honestly against the current no-manifest baseline:
  - shadow anchored-overlay owner / compatibility fallback in `ext/TaxonomyMakie/PhyloPic/src/_render.jl`
  - stale comments or logic that still assume an old resolved `PhyloPicMakie` surface
  - false import examples such as `using PaleobiologyDB: taxonomytreeplot`
  - false activation prose such as "TaxonomyMakie exports are now in scope" after `using PaleobiologyDB`
  - stale placeholder wording claiming a grey rectangle
- If the live code no longer matches any of those findings, stop and record the exact delta before editing further.

## Non-negotiable execution rules

These rules are binding for the fix pass:

- Do not reintroduce or commit `Manifest.toml` or `test/Manifest.toml`.
- Do not keep or add a PBDB-side shadow generic anchored-overlay owner.
- Do not reach into `PhyloPicMakie` private internals from `PaleobiologyDB.jl` merely to compensate for stale dependency assumptions.
- Do not solve the docs problem by re-exporting `taxonomytreeplot`, `augment_leaf_phylopic!`, or related names from the top-level `PaleobiologyDB` module unless the user explicitly approves that separate public API change.
- Do not ask the user to approve the same rename matrix again.
- Do not silently change the approved rename set. If an additional public rename or API break becomes necessary, stop and escalate that exact new change.

## Concrete anti-patterns that must be removed

The following are not acceptable end states for Tranche 4 and should be treated as concrete removal targets during implementation:

- In `ext/TaxonomyMakie/PhyloPic/src/_render.jl`, PBDB-side generic overlay helpers such as:
  - `_VALID_ANCHORED_ON_MISSING`
  - `_HAS_SCENE_LIKE_ANCHORED_INTERNALS`
  - `_prepared_anchor_positions`
  - `_prepare_resolved_anchor_overlay`
  - `_transparent_anchored_probe_scatter!`
  - `_projected_anchor_positions_scene_like!`
  - `_augment_phylopic_anchored_scene_like!`
- PBDB-side comments or code paths that justify private-internal reach-in because "the unpinned test environment currently resolves to an older mainline surface."
- README and guide snippets that import `taxonomytreeplot` or `augment_leaf_phylopic!` from `PaleobiologyDB` directly.
- Guide activation prose that claims the extension exports are automatically in scope after `using PaleobiologyDB`.
- Public docstrings that still describe `:placeholder` as a grey rectangle.

## Tasks

### 1. Revalidate the current baseline and lock the real repair boundary

**Type**: REVIEW  
**Output**: A verified start-state note for this fix pass covering the no-manifest baseline, the already-approved rename matrix, the false import story, and whether the PBDB-side shadow owner still exists exactly as reviewed.  
**Depends on**: none

Read the parent PRD, Tranche 4, the original Tranche 4 tasking, this fixes tasking file, and the active governance set in full. Reproduce the review findings directly against the current clean worktree. Confirm that both manifests are intentionally absent, that the approved rename set already matches the user's decisions, and that the import mismatch is still a docs problem rather than a newly approved export-surface change. Do not edit production files in this task unless a tiny verification-only probe is required to establish reality.

### 2. Remove the PBDB-side shadow anchored-overlay owner and stale fallback assumptions

**Type**: WRITE  
**Output**: `PaleobiologyDB.jl` no longer contains a second generic anchored-overlay preparation path, and any needed generic helper ownership lives in `PhyloPicMakie.jl` rather than in the PBDB bridge.  
**Depends on**: 1

Repair `ext/TaxonomyMakie/PhyloPic/src/_render.jl` first. The goal is not "make the current code pass locally"; the goal is "restore the owner boundary honestly." Remove PBDB-side generic overlay-preparation helpers and any compatibility branch that exists only because an older resolved `PhyloPicMakie` might be present. If an upstream helper is missing, add or repair it in the adjacent `PhyloPicMakie.jl` repository and route the PBDB bridge through that owner instead of duplicating the logic locally. End this task with no PBDB-side generic render-preparation owner, no stale fallback comment about old mainline resolution, and truthful touched tests green in every repository changed.

### 3. Normalize the tranche approval artifact and final public break contract

**Type**: REVIEW  
**Output**: The approved rename matrix is now carried forward explicitly as the authoritative Tranche 4 break set, with no need for a second human-approval stop.  
**Depends on**: 1

Use this fixes tasking file as the already-approved break artifact. Do not ask the user again for the same rename approval. Instead, verify that the shipped or to-be-shipped public surface matches the approved matrix in this file exactly. If the current code deviates from that matrix, either bring it back into alignment or stop and escalate the specific deviation. The agent should leave behind a clear closeout note or workflow-doc reference showing that the approval gate is satisfied by this artifact and the conversation-derived decision it records.

### 4. Fix the import story in docs and examples to match reality, not a wished-for API

**Type**: WRITE  
**Output**: README, guide docs, API docs, and touched examples tell the truth about how users access `TaxonomyMakie` today, without implying top-level `PaleobiologyDB` re-exports that do not exist.  
**Depends on**: 1

Repair the user-facing import and activation instructions. Concretely:

- Remove examples like `using PaleobiologyDB: taxonomytreeplot, ...`.
- Remove prose claiming TaxonomyMakie exports are automatically in scope after `using PaleobiologyDB`.
- Replace them with the real extension usage pattern, for example loading a Makie backend, loading `PaleobiologyDB`, and then using `PaleobiologyDB.TaxonomyMakie` or qualifying names from that submodule.
- Keep this a docs-and-example truth fix. Do not turn it into a top-level export expansion unless the user explicitly asks for that separate public-surface change.

Touch at least:

- `README.md`
- `docs/src/guide/taxonomytree_makie.md`
- `docs/src/api/taxonomytree_makie.md`
- `examples/src/taxonomytree.jl` if its prose or usage examples need alignment

### 5. Add verification that locks the repaired owner boundary and the real import contract

**Type**: TEST  
**Output**: Automated checks fail on the reviewed Tranche 4 problems and pass on the repaired implementation, including the docs-facing extension import contract and the absence of the PBDB-side shadow owner.  
**Depends on**: 2, 4

Strengthen verification so this does not regress silently again. At minimum:

- Add or update tests around the extension surface so the supported access pattern is explicit.
- Prefer positive checks such as `isdefined(PaleobiologyDB, :TaxonomyMakie)` after backend load and use of `PaleobiologyDB.TaxonomyMakie`.
- If practical without brittle import-warning gymnastics, also add a small negative contract check that `PaleobiologyDB` itself does not currently expose `taxonomytreeplot` or `augment_leaf_phylopic!`, so docs cannot drift back toward a false top-level import story by accident.
- Add verification or structural assertions that would have failed if the PBDB bridge still carried the reviewed shadow-owner logic.
- Fix touched public wording such as the `:placeholder` description so docs and docstrings agree with the real renderer.

The goal is not to test private implementation names exhaustively; it is to make the reviewed failure modes hard to reintroduce unnoticed.

### 6. Close the fix pass with truthful end-green verification

**Type**: REVIEW  
**Output**: A truthful Tranche 4 fix closeout covering owner-boundary repair, approved rename-set alignment, no-manifest policy compliance, corrected import docs, corrected placeholder wording, and green verification.  
**Depends on**: 3, 5

Run the required end-green checks honestly in the manifest-less baseline:

- In `PaleobiologyDB.jl`, run `julia --project=test test/runtests.jl`.
- In `PaleobiologyDB.jl`, run `julia --project=docs docs/make.jl`.
- If Task 2 touched `PhyloPicMakie.jl`, rerun the relevant `PhyloPicMakie.jl` tests and touched docs build there.

Before closing, confirm all of the following explicitly:

- no committed `Manifest.toml` or `test/Manifest.toml` was reintroduced
- the approved rename matrix in this fixes tasking file matches the shipped public surface
- the PBDB bridge no longer owns a fallback generic anchored-overlay implementation
- README and docs no longer claim `using PaleobiologyDB: taxonomytreeplot` works
- README and docs no longer claim TaxonomyMakie exports are automatically in scope after `using PaleobiologyDB`
- public placeholder wording describes the actual placeholder glyph image behavior

This fix pass closes only if the code, docs, and workflow artifact all tell the same true story.
