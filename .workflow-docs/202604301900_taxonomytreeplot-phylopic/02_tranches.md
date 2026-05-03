# Tranches: Re-architect TaxonomyMakie and PhyloPicMakie tree glyph overlays

These tranches implement `01_prd.md` in dependency order.

For cross-repository work, downstream implementers must treat both repositories' active governance files as controlling authorities:

- `PaleobiologyDB.jl/CONTRIBUTING.md`
- `PaleobiologyDB.jl/STYLE-architecture.md`
- `PaleobiologyDB.jl/STYLE-docs.md`
- `PaleobiologyDB.jl/STYLE-git.md`
- `PaleobiologyDB.jl/STYLE-julia.md`
- `PaleobiologyDB.jl/STYLE-makie.md`
- `PaleobiologyDB.jl/STYLE-upstream-contracts.md`
- `PaleobiologyDB.jl/STYLE-verification.md`
- `PaleobiologyDB.jl/STYLE-vocabulary.md`
- `PaleobiologyDB.jl/STYLE-workflow-docs.md`
- `PaleobiologyDB.jl/STYLE-writing.md`
- `PhyloPicMakie.jl/STYLE-architecture.md`
- `PhyloPicMakie.jl/STYLE-docs.md`
- `PhyloPicMakie.jl/STYLE-git.md`
- `PhyloPicMakie.jl/STYLE-julia.md`
- `PhyloPicMakie.jl/STYLE-makie.md`
- `PhyloPicMakie.jl/STYLE-upstream-contracts.md`
- `PhyloPicMakie.jl/STYLE-verification.md`
- `PhyloPicMakie.jl/STYLE-vocabulary.md`
- `PhyloPicMakie.jl/STYLE-workflow-docs.md`
- `PhyloPicMakie.jl/STYLE-writing.md`

`PhyloPicMakie.jl` currently has no repo-local `CONTRIBUTING.md`. Its repo-local `STYLE*.md` files are active for tranche work there.

## Tranche 1: Build PhyloPicMakie Generic Anchored Overlay Foundation

**Type**: AFK
**Blocked by**: None — can start immediately

### Parent PRD

`01_prd.md`

### Governance and required reading

- Mandated line-by-line reading of all relevant `CONTRIBUTING*.md`, `STYLE*.md`, and user-supplied governance documents listed above.
- Mandated line-by-line reading of `STYLE-vocabulary.md` in both repositories, with explicit enforcement of the `tip` to `leaf` cleanup direction and the ban on vague host-framework phrasing.
- Mandated reading of the Makie primary sources named in the PRD, especially:
  - `docs/src/explanations/conversion_pipeline.md`
  - `docs/src/explanations/recipes.md`
  - `docs/src/reference/generic/space.md`
  - `docs/src/explanations/cameras.md`
  - `Makie/src/utilities/projection_utils.jl`
  - `Makie/src/basic_recipes/textlabel.jl`
  - `CairoMakie/src/scatter.jl`
  - `Makie/test/boundingboxes.jl`
- Mandated reading of the current `PhyloPicMakie.jl` owners and tests named in the PRD, especially:
  - `src/PhyloPicMakie.jl`
  - `src/_coordinates.jl`
  - `src/_render_core.jl`
  - `src/_augment_api.jl`
  - `test/test_coordinates.jl`
  - `test/test_render_core.jl`
  - `test/test_makie_integration.jl`

### What to build

Build the foundational `PhyloPicMakie` owner for generic anchored overlays.

This is a foundational tranche. It should establish the reusable lower-level rendering substrate that tree clients, tick or legend helpers, and arbitrary overlay callers can all share. The product-level direction is already approved: `PhyloPicMakie` should own more of the general rendering and placement service, and `TaxonomyMakie` should become a client of that service rather than a parallel renderer.

The tranche should:

- implement the generic anchor and placement contract in `PhyloPicMakie`,
- bias toward a projected-anchor based solution when placement truly depends on rendered screen geometry,
- keep renderer-safe size, aspect, and resize/reactivity behavior inside `PhyloPicMakie`,
- avoid pushing pixel or viewport reconstruction back into client packages,
- preserve explicit missing-image policy behavior and generic error handling.

If Makie host-framework behavior proves the projected-anchor bias unworkable, the tranche must stop with evidence and escalate rather than falling back to ad hoc anti-fixes.

### How to verify

- **Manual**:
  1. Build or adapt a small `PhyloPicMakie` demo that attaches silhouettes to at least two non-tree anchor kinds, such as explicit coordinates plus a rendered-label or marker-relative anchor.
  2. Resize the figure and trigger relimit or layout changes.
  3. Inspect that silhouettes remain visible, aspect-correct, and anchored to the intended rendered object without client-side reimplementation of Makie-space math.
- **Automated**:
  - In `PhyloPicMakie.jl`, run `julia --project=. -e 'import Pkg; Pkg.test()'`.
  - If this tranche touches `PhyloPicMakie.jl/docs`, run `julia --project=docs docs/make.jl` in `PhyloPicMakie.jl`.
  - Add or update render-aware tests that would have failed for the current placement or size-collapse class of bug.

### Acceptance criteria

- [ ] Given explicit anchors and at least one rendered-object anchor kind, when glyphs are rendered through the new `PhyloPicMakie` anchored-overlay substrate, then they remain visibly sized, aspect-correct, and stable under resize or relimit without client-side pixel or data reconstruction hacks.
- [ ] Given unsupported or ambiguous anchor specifications, or missing images under `:error`, then `PhyloPicMakie` raises deterministic documented failures instead of silently misplacing or shrinking glyphs.

### User stories addressed

- User story 2: aspect stability under resize and auto-limits
- User story 7: explicit missing-image behavior
- User story 9: one owner for general glyph rendering
- User story 11: Makie-supported projection contracts
- User story 14: trancheable foundational work
- User story 15: tests that catch the historical bug
- User story 17: shared `PhyloPicMakie` ownership for generic improvements
- User story 18: generic anchor-driven overlay API
- User story 21: distinguish owner-level fixes from symptom patches
- User story 22: clear final module boundaries

---

## Tranche 2: Build Standalone PhyloPicMakie Examples Environment and MWE Gallery

**Type**: AFK
**Blocked by**: Tranche 1

### Parent PRD

`01_prd.md`

### Governance and required reading

- Mandated line-by-line reading of all relevant `CONTRIBUTING*.md`, `STYLE*.md`, and user-supplied governance documents listed above.
- Mandated line-by-line reading of `STYLE-docs.md`, `STYLE-makie.md`, `STYLE-verification.md`, and `STYLE-vocabulary.md` in both repositories.
- Mandated reading of the `PhyloPicMakie.jl` public-surface and verification owners named in the PRD, especially:
  - `src/PhyloPicMakie.jl`
  - `src/_coordinates.jl`
  - `src/_render_core.jl`
  - `src/_augment_api.jl`
  - `test/test_makie_integration.jl`
- Mandated reading of the additional graph-stack primary sources named in the PRD, especially:
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

### What to build

Build a standalone `PhyloPicMakie.jl` examples environment and minimal working example gallery that showcases the approved public interface independently of `PaleobiologyDB.jl`.

This is a user-facing and stabilization-oriented tranche. It should:

- create an `examples` project in `PhyloPicMakie.jl`,
- add runnable scripts under `examples/src`,
- ensure the examples can be invoked as `julia --project=examples examples/src/<name>.jl`,
- keep the examples isolated from `PaleobiologyDB.jl`,
- use `Graphs.jl`, `MetaGraphsNext.jl`, and `GraphMakie.jl` where useful to provide graph abstractions and rendered scenes onto which PhyloPic overlays are plotted,
- showcase the public overlay interface rather than private internals,
- include at least one graph-oriented example that exercises the shared hand-off architecture in a non-tree context.

The goal is not a generic graph-visualization subsystem. The goal is a compact, credible gallery of public-interface examples that prove `PhyloPicMakie.jl` stands on its own as a reusable Makie overlay package.

### How to verify

- **Manual**:
  1. In `PhyloPicMakie.jl`, run at least one standalone example as `julia --project=examples examples/src/<name>.jl`.
  2. Inspect that the example runs without `PaleobiologyDB.jl` in the environment and produces the intended plot or rendered artifact.
  3. Run at least one graph-based example using `Graphs.jl`, `MetaGraphsNext.jl`, or `GraphMakie.jl` support and inspect that the PhyloPic overlay behavior is visibly correct.
- **Automated**:
  - In `PhyloPicMakie.jl`, run `julia --project=. -e 'import Pkg; Pkg.test()'`.
  - If examples are wired into docs or verification harnesses, run `julia --project=docs docs/make.jl` in `PhyloPicMakie.jl`.
  - Add a lightweight verification path, script check, or CI-friendly smoke run so the examples environment does not silently rot.

### Acceptance criteria

- [ ] Given a fresh `PhyloPicMakie.jl` checkout, when a user runs `julia --project=examples examples/src/<name>.jl`, then the example executes in an isolated examples environment and demonstrates the public overlay interface without depending on `PaleobiologyDB.jl`.
- [ ] Given at least one graph-oriented example built on `Graphs.jl`, `MetaGraphsNext.jl`, or `GraphMakie.jl`, then the example showcases a realistic reusable overlay scenario without introducing a tree-specific dependency or private-interface coupling.

### User stories addressed

- User story 8: trustworthy final docs and API reference
- User story 17: shared `PhyloPicMakie` ownership for generic improvements
- User story 18: generic anchor-driven overlay API
- User story 19: standalone runnable `PhyloPicMakie` examples
- User story 22: clear final module boundaries

---

## Tranche 3: Migrate TaxonomyMakie to Shared Leaf Overlay Planning

**Type**: AFK
**Blocked by**: Tranche 2

### Parent PRD

`01_prd.md`

### Governance and required reading

- Mandated line-by-line reading of all relevant `CONTRIBUTING*.md`, `STYLE*.md`, and user-supplied governance documents listed above.
- Mandated line-by-line reading of `STYLE-vocabulary.md` in both repositories, with no silent preservation of proscribed `tip*` concepts in new owner logic.
- Mandated reading of the Makie and `PhyloPicMakie.jl` primary sources named in the PRD.
- Mandated reading of the current `PaleobiologyDB.jl` tree-overlay owners named in the PRD, especially:
  - `examples/src/taxonomytree.jl`
  - `ext/TaxonomyMakie/_layout.jl`
  - `ext/TaxonomyMakie/_recipe.jl`
  - `ext/TaxonomyMakie/_augment.jl`
  - `ext/TaxonomyMakie/_phylopic.jl`
  - `ext/TaxonomyMakie/PhyloPic/src/_render.jl`
  - `test/taxonomytree_makie.jl`

### What to build

Migrate `TaxonomyMakie` to the shared `PhyloPicMakie` anchored-overlay foundation while confining tree ownership to leaf planning and convenience orchestration.

This is the cross-package migration tranche. It should:

- remove or retire the duplicated private `show_phylopic = true` render path as the owner of glyph rendering behavior,
- make the one-step `taxonomytreeplot(...; show_phylopic = true, ...)` route through the same underlying overlay machinery as the explicit two-step tree overlay flow,
- keep `TaxonomyMakie` responsible only for leaf discovery, leaf-label policy, alignment mode, and derivation of overlay anchors,
- preserve ordinary no-glyph tree plotting behavior and approved missing-image policies,
- keep tree ergonomics intact while stopping further leakage of general rendering logic into `TaxonomyMakie`.

### How to verify

- **Manual**:
  1. Enable `set_autocaching!(true)` for live PBDB and PhyloPic-heavy checks.
  2. Run `examples/src/taxonomytree.jl` and inspect that leaf glyphs are visible and correctly placed.
  3. Exercise both the one-step `show_phylopic = true` path and the explicit two-step tree overlay path on the same tree.
  4. Resize the figure or adjust axis limits and confirm both routes remain behaviorally aligned.
- **Automated**:
  - In `PaleobiologyDB.jl`, run `julia --project=test test/runtests.jl`.
  - In `PhyloPicMakie.jl`, rerun `julia --project=. -e 'import Pkg; Pkg.test()'` if this tranche changes shared renderer behavior or adapter-facing contracts.
  - Add or update tests in `test/taxonomytree_makie.jl` so they verify size, aspect, or anchor relationships rather than only `@test_nowarn`.

### Acceptance criteria

- [ ] Given a tree rendered through either the one-step `show_phylopic = true` path or the explicit two-step tree overlay path, when the figure is rendered and resized, then both flows use the same underlying overlay machinery and keep glyphs visible, aspect-correct, and correctly anchored relative to the intended leaf or leaf-label policy.
- [ ] Given `show_phylopic = false`, a tree with unresolved images, or approved `on_missing` modes, then ordinary tree rendering and failure behavior remain correct without fallback duplication of renderer ownership in `TaxonomyMakie`.

### User stories addressed

- User story 1: trustworthy one-step happy path
- User story 2: aspect stability under resize and auto-limits
- User story 3: correct leaf-label placement policy
- User story 4: explicit lower-level tree overlay API
- User story 5: clean no-glyph tree plotting path
- User story 9: one owner for general glyph rendering
- User story 10: one owner for tree-specific anchor semantics
- User story 11: Makie-supported projection contracts
- User story 20: keep tree wrappers ergonomic
- User story 22: clear final module boundaries

---

## Tranche 4: Finalize Public Surface and Vocabulary Cleanup

**Type**: HITL
**Blocked by**: Tranche 3

### Parent PRD

`01_prd.md`

### Governance and required reading

- Mandated line-by-line reading of all relevant `CONTRIBUTING*.md`, `STYLE*.md`, and user-supplied governance documents listed above.
- Mandated line-by-line reading of `STYLE-vocabulary.md` in both repositories, with direct attention to proscribed `tip` terminology and canonical project spellings such as `edge`, `rootnode`, `edgeweight`, `lineageunits`, and `node_positions`.
- Mandated reading of the `PaleobiologyDB.jl` public-surface and docs owners named in the PRD, especially:
  - `ext/TaxonomyMakie/_recipe.jl`
  - `ext/TaxonomyMakie/_augment.jl`
  - `ext/TaxonomyMakie/_layout.jl`
  - `docs/src/guide/taxonomytree_makie.md`
  - `docs/src/api/taxonomytree_makie.md`

### What to build

Finalize the approved public surface cleanup after the shared architecture is in place.

This is the explicit public-break tranche. It should:

- perform the hard `tip*` to `leaf*` rename set with no deprecation aliases by default,
- clean up approved keyword and helper naming so final user-facing terminology matches the active controlled vocabulary,
- remove or replace stale docs and examples that still describe superseded tree overlay semantics,
- surface the final public break list to the user for approval before the tranche closes.

This tranche is `HITL` because the user explicitly reserved approval rights over the final public break set even though breakage is broadly authorized.

### How to verify

- **Manual**:
  1. Produce the final public break list, including renamed functions, renamed keywords, removed helpers, and any changes to documented behavior.
  2. Review that list with the user and obtain explicit approval before closing the tranche.
  3. Inspect the final public docs and exports for lingering `tip*` language or other vocabulary violations.
- **Automated**:
  - In `PaleobiologyDB.jl`, run `julia --project=test test/runtests.jl`.
  - If this tranche changes `PhyloPicMakie.jl` public names or docs, run `julia --project=. -e 'import Pkg; Pkg.test()'` there and build touched docs with `julia --project=docs docs/make.jl`.
  - In `PaleobiologyDB.jl`, run `julia --project=docs docs/make.jl`.
  - Add or update tests that lock in the approved final `leaf*`-based surface.

### Acceptance criteria

- [ ] Given the current unreleased `tip*`-heavy tree overlay surface, when the final public API is approved, then `leaf*` terminology replaces proscribed names across code, tests, docs, and examples without default deprecation shims.
- [ ] Given the final rename and cleanup set, then that break list is explicitly shown to the user and approved before the tranche is considered complete.

### User stories addressed

- User story 4: explicit lower-level tree overlay API
- User story 8: trustworthy final docs and API reference
- User story 12: vocabulary cleanup to `leaf*`
- User story 13: explicit approval of API changes
- User story 21: distinguish owner-level fixes from symptom patches
- User story 22: clear final module boundaries

---

## Tranche 5: Stabilize Verification, Docs, and Rendered Artifacts

**Type**: AFK
**Blocked by**: Tranche 4

### Parent PRD

`01_prd.md`

### Governance and required reading

- Mandated line-by-line reading of all relevant `CONTRIBUTING*.md`, `STYLE*.md`, and user-supplied governance documents listed above.
- Mandated line-by-line reading of `STYLE-verification.md`, `STYLE-docs.md`, `STYLE-makie.md`, and `STYLE-vocabulary.md` in all touched repositories.
- Mandated reading of the PRD's verification and docs owners, especially:
  - `test/taxonomytree_makie.jl`
  - `test/phylopic_makie.jl`
  - `examples/src/taxonomytree.jl`
  - `docs/src/guide/taxonomytree_makie.md`
  - `docs/src/api/taxonomytree_makie.md`
  - `docs/src/guide/phylopic_makie.md`
  - `docs/src/api/phylopic_makie.md`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/Project.toml`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/examples/src`
  - `/home/jeetsukumaran/site/storage/local/computing/research/20260414_PhyloPicMakie.jl/PhyloPicMakie.jl/test/test_makie_integration.jl`

### What to build

Stabilize the redesigned overlay system with render-aware verification, final docs alignment, and required visual artifacts.

This is the stabilization tranche. It should:

- ensure automated coverage would have caught the original tiny-glyph failure,
- harden resize, relimit, and anchor-relationship checks,
- ensure docs and examples describe the approved final surface exactly,
- ensure verification would also catch the reviewed contract regressions, not just visual happy-path failures,
- keep the standalone `PhyloPicMakie.jl` examples environment healthy and aligned with the finalized public overlay interface,
- produce at least one rendered tree plus PhyloPic artifact and one explicit two-step overlay artifact,
- keep live verification practical by using `set_autocaching!(true)` for slow PBDB and PhyloPic-heavy checks,
- preserve the repaired owner boundary and truthful import or docs contract rather than broadening API surface or reintroducing compatibility scaffolding during stabilization.

This tranche must not be treated as a loose polish pass. It is the final guard against regressions that would recreate removed owners, stale docs contracts, or environment-policy drift while still reporting a superficial green state.

### Legacy artifacts and regression classes that must stay retired

- PBDB-side shadow generic anchored-overlay owners or compatibility fallbacks that regrow retired `PhyloPicMakie` responsibilities
- stale docs or README import guidance that implies `using PaleobiologyDB: taxonomytreeplot` works or that `TaxonomyMakie` exports automatically enter scope after `using PaleobiologyDB`
- stale public wording that claims `:placeholder` draws a grey rectangle rather than a placeholder glyph image
- reintroduction of committed `Manifest.toml` or `test/Manifest.toml` in `PaleobiologyDB.jl`
- reintroduction of committed `examples/Manifest.toml` in `PhyloPicMakie.jl`, which should remain `Project.toml`-driven
- manual-only artifact inspection paths that are not backed by any automated or scripted regression signal

### Forbidden regressions

- shadow implementations, compatibility shims, or private-internal reach-ins added merely to make verification pass
- docs fixes that silently broaden public API surface instead of keeping docs truthful to the approved final contract
- example or smoke paths that depend on `PaleobiologyDB.jl` from inside the standalone `PhyloPicMakie.jl` examples gallery
- stabilization work that weakens the already-approved contract checks instead of encoding them more robustly

### Environment and dependency baseline

- In `PaleobiologyDB.jl`, `Manifest.toml` and `test/Manifest.toml` are intentionally absent unless the user later changes that policy.
- In `PhyloPicMakie.jl`, the `examples` environment should remain `Project.toml`-driven without a tracked `examples/Manifest.toml`.
- Docs must continue to reflect the extension-module import story for `TaxonomyMakie`; stabilization must not assume a new top-level export policy unless a later explicit user decision changes that contract.
- Verification may instantiate fresh transient manifests locally, but the tranche must not close with those manifests committed contrary to the approved baseline.

### How to verify

- **Manual**:
  1. Enable `set_autocaching!(true)` for live example checks.
  2. Run at least one standalone `PhyloPicMakie.jl` example as `julia --project=examples examples/src/<name>.jl` and inspect the rendered output.
  3. Run the final `examples/src/taxonomytree.jl` flow and inspect the rendered artifact.
  4. Run one explicit two-step leaf overlay example and inspect the rendered artifact.
  5. Perform at least one resize or relimit scenario and confirm the artifact remains visually correct.
  6. Inspect the final docs or README snippets that demonstrate tree plotting and confirm they use the truthful `PaleobiologyDB.TaxonomyMakie` import path rather than a false top-level `PaleobiologyDB` import story.
- **Automated**:
  - In `PaleobiologyDB.jl`, run `julia --project=test test/runtests.jl`.
  - In `PaleobiologyDB.jl`, run `julia --project=docs docs/make.jl`.
  - If this tranche changes `PhyloPicMakie.jl` verification or docs assets, run `julia --project=. -e 'import Pkg; Pkg.test()'` and `julia --project=docs docs/make.jl` in `PhyloPicMakie.jl`.
  - Ensure the standalone `PhyloPicMakie.jl` examples environment and the rendered-artifact generation path are part of tranche verification, not optional manual afterthoughts.
  - Include at least one automated check that would fail if shadow-owner helpers, false import docs, stale placeholder wording, or manifest-policy drift were reintroduced.
  - If transient manifests are generated during verification, ensure the repository closes the tranche without those manifests becoming part of the committed end state unless the user later changes policy.

### Acceptance criteria

- [ ] Given the approved final tree and generic overlay surfaces, when tests, docs builds, and example or artifact checks run, then they produce a visible correctly placed standalone `PhyloPicMakie.jl` happy path, a tree-plus-PhyloPic happy path, and an explicit two-step overlay happy path that match the documented behavior.
- [ ] Given resize, relimit, or slow live lookup conditions, then the verification suite and cached example workflow catch regressions without depending on uncached ad hoc manual probing.
- [ ] Given the reviewed failure classes from earlier tranches, when verification runs, then it fails rather than reporting green if shadow owner logic, false import docs, stale placeholder wording, or manifest-policy drift reappears.
- [ ] Given the finalized docs and examples surface, when a user follows the documented import and example flow, then it reflects the approved extension-module contract and standalone examples policy without smuggling in a broader API or a tracked-manifest requirement.

### User stories addressed

- User story 6: caching-friendly live verification
- User story 8: trustworthy final docs and API reference
- User story 15: tests that catch the historical bug
- User story 16: rendered tree plus PhyloPic artifact in green state

---
