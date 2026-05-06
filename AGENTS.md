# Agent instructions

This repository uses governed workflow documents and phase-specific skills.
Treat this file as the authoritative repo-root agent instruction file. It is
the compact repo-local backstop that applies across the entire workflow.

## Universal rules

- Read all applicable governance documents line by line before substantial
  work. At minimum, check `CONTRIBUTING.md`, all relevant `STYLE*.md` files,
  and any active workflow documents.
- Treat governance documents and active workflow documents as controlling
  inputs, not as optional background context.
- Maintain an active-authorities list while you work.
- Pass governance, vocabulary, upstream-source, authorization-boundary, and
  verification obligations forward explicitly in every downstream artifact and
  agent handoff.
- Revalidate workflow documents against the current code, tests, docs, outputs,
  and upstream sources before acting on them.
- Stop and escalate if a workflow document, handoff, or request conflicts with
  active governance or current reality.

## Workflow handoffs

- Use a handoff packet whenever downstream execution, review, audit, or
  delegation is expected.
- The packet should include, where applicable:
  - active authorities
  - parent documents
  - settled decisions and non-negotiables
  - authorization boundary
  - current-state diagnosis
  - primary-goal lock
  - direct red-state repros
  - owner and invariant being repaired or relied on
  - exact scope in and out
  - required upstream primary sources
  - green-state gates
  - stop conditions
- Do not rely on "see parent document" as the only handoff.

## Primary goals and decisions

- Convert every user-stated primary goal, explicit non-negotiable, review
  finding, compatibility boundary, and migration boundary into a separate lock
  item.
- For each lock item, state:
  - the non-completion condition
  - the direct red-state repro or equivalent current bad behavior
  - the owner, task, or tranche that closes it
  - the verification artifact that fails the bad implementation or fake-fix
    shape
- Do not collapse distinct goals into one generic acceptance note if one could
  still survive while another is fixed.
- Do not reopen settled decisions under the label of implementation detail.
- If a design decision is derivable from the active sources, resolve it in the
  workflow document. If it genuinely requires judgment, convert it into an
  explicit `REVIEW` gate.

## Implementation behavior

- Start from the task file, tranche, PRD, governance, and handoff packet.
- Restate the active authorities, settled decisions, lock items, and red-state
  repros before substantial edits.
- Repair the owning layer or invariant, not just the symptom site.
- Do not claim success on the basis of passing tests, passing docs builds, grep
  checks, or helper-level checks alone when a more direct contract-level proof
  exists.
- Report completion by lock item and green-state gate, not just by listing
  files changed.

## Review and audit behavior

- Review and audit against the active authorities, parent workflow documents,
  handoff packet, lock items, and real contract boundary.
- Prefer findings that identify surviving bugs, anti-fixes, migration gaps,
  ownership drift, or missing proof obligations over generic style commentary.
- If no findings are discovered, say so explicitly and mention any remaining
  residual risks or verification gaps.

## Skill interaction

- Use the `development-policies` skill first whenever governed workflow,
  planning, implementation, review, audit, or delegation work is requested.
- Use the relevant phase skill for PRD writing, trancheing, tasking, execution,
  review, or audit work instead of improvising the procedure from scratch.
- This file complements those skills; it does not replace them.
