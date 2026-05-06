# STYLE-workflow-docs.md

## Purpose

This document governs project planning and review artifacts such as PRDs,
tranche documents, tasking documents, design notes, review reports, and audit
reports.

Its purpose is to prevent loss of context, loss of governance mandates, frozen
misdiagnoses, and handoffs that preserve a narrow framing while dropping the
real constraints.

## Mandatory reading and pass-forward

All contributors, including agents, must read this document line by line
before generating or revising workflow documents or delegating work.

If you create any downstream workflow document or dispatch any downstream task,
you must pass relevant mandates forward explicitly.

The downstream document must not merely inherit the parent context implicitly.
It must explicitly restate:

- which governance documents must be read line by line
- which upstream primary sources must be read
- which vocabulary constraints apply
- which authorization boundaries apply
- which verification gates define green state

This pass-forward obligation applies at every handoff boundary.

## Required sections

Every workflow document should include the sections appropriate to its level,
but the following obligations must be represented somewhere explicitly.

### Governance and required reading

List every applicable governance document that must be read line by line.

If only some documents are relevant, say which ones and why.

### Controlled vocabulary

Name the relevant vocabulary constraints.

If new terms are required or existing terms are ambiguous, say so explicitly
and route the question through `STYLE-vocabulary.md`.

### Upstream primary sources

List the exact upstream primary sources that constrain the work.

If the work depends on framework behavior and no primary source has been read,
the workflow document is incomplete.

### Current-state diagnosis

Describe the current problem, not just the desired outcome.

If the work addresses a bug or architectural defect, the document must state:

- the observed failure mode
- the suspected root cause
- the owning layer or contract involved

### Ownership and invariant framing

If the work touches more than one module or layer, the document must identify:

- the owning layer
- the shared contract or invariant
- whether a foundational tranche is required before user-facing work

If a public semantic is accepted through more than one entry surface, the
document must also identify:

- the canonical owner that normalizes that semantic
- each supported public surface through which it may enter
- which surfaces must be covered by verification

### Authorization boundary

If disruptive redesign, deep refactor, clean-room replacement, migration, or
external breakage is in play, the document must state what is authorized and
what is not.

### Verification and green-state gates

Every workflow document must state what counts as complete for its scope.

This includes the required verification artifacts and the green-state gates
that must pass before the work is considered done.

### Handoff packet

Any workflow document that is meant to be consumed downstream by another
agent, contributor, tranche, review pass, or audit pass must include a concise
handoff packet.

The handoff packet must not merely point back to the parent document. It must
extract and restate the concrete execution controls that the downstream actor
needs in order to succeed honestly.

At minimum, the handoff packet must include, where applicable:

- active authorities
- parent documents
- settled decisions and non-negotiables
- authorization boundary
- current-state diagnosis
- primary-goal lock
- direct red-state repros
- owner and invariant being repaired or relied on
- exact files or surfaces in scope
- exact files or surfaces out of scope
- required upstream primary sources
- green-state gates
- stop conditions or escalate-if conditions

If a field does not apply, say so explicitly or omit it deliberately with a
clear reason. Do not silently rely on the downstream actor to infer it.

### Primary-goal lock

Any workflow document that turns requirements, findings, tranche goals,
compatibility boundaries, migration boundaries, or explicit non-negotiables
into downstream execution must convert each primary goal into an explicit lock
item.

Each lock item must state:

- the failure mode or forbidden surviving shape
- the non-completion condition in the form "the work is not complete if..."
- the direct red-state repro, historical bad behavior, or equivalent observed
  failure mode
- the task, tranche subsection, or delegated owner that closes it
- the verification artifact that must fail the old implementation or fake-fix
  shape

Do not leave a user-stated primary goal or review finding as descriptive prose
only.

If multiple lock items share the same owning repair, they may point at the same
task, but they must still remain separately named if one could survive while
another is fixed.

Green test suites, docs builds, grep checks, and source-text audits are
necessary but not sufficient as the only proof for a lock item unless no more
direct artifact is possible and that limitation is stated explicitly.

## Revalidation rule

Tasking documents must not blindly operationalize stale or partial diagnoses.

Before implementation begins, the current code, tests, examples, outputs, and
upstream sources must be rechecked against the document's framing.

If the diagnosis no longer matches reality, the contributor or agent must stop
and rewrite, split, or escalate the workflow document rather than blindly
continuing.

Receivers of a handoff packet must re-check the packet against the current
code, tests, docs, outputs, and upstream sources before acting on it. A
handoff packet does not waive revalidation.

## Anti-drift rules

Workflow documents must not:

- freeze a known partial diagnosis into downstream execution
- omit architecture concerns merely to make the tranche look thinner
- omit upstream references when framework semantics matter
- omit verification gates when user-visible behavior is changing
- omit the handoff packet when downstream execution is expected
- pass only parent links or filenames when a downstream actor needs concrete
  execution controls
- leave primary goals, review findings, or compatibility requirements as
  descriptive intent without explicit lock items
- let several distinct primary goals collapse into one generic regression if
  one of those goals could still survive behind a green suite
- strip governance obligations from downstream documents

If a downstream document is materially weaker than its parent on these points,
that is workflow drift and must be corrected before execution proceeds.

## Review and audit standard

Reviews and audits of workflow documents must ask:

- did the mandates actually get passed forward?
- did the document preserve the real owner and root-cause framing?
- did it preserve upstream-reading obligations?
- did it preserve the correct verification gates?
- did it create an honest authorization boundary?
- did it include a usable handoff packet rather than a link-only or
  context-dump handoff?
- did every primary goal, review finding, and compatibility boundary become a
  separate lock item with a direct proof obligation?
- could a fresh implementing agent still declare success while one of those
  lock items survives behind a green suite?

If not, the workflow document is not safe for downstream execution.
