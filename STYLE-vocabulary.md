---
date-created: <fill-in-when-copied>
date-revised: <fill-in-when-copied>
status: draft
---

# Controlled vocabulary

This file is the authoritative terminology reference for <project-name>.
All code, documentation, tests, tranche documents, issue reports, and pull
requests must use the canonical terms defined here. Proscribed terms must not
appear in any identifier, type name, function name, keyword argument, symbol,
or field name.

**This starter file is intentionally partial.** It contains reusable workflow,
architecture, and general development terms that are portable across projects.
Project-specific domain terms must be added, revised, or removed with explicit
project-owner approval.

Any agent, contributor, or automated tool that needs to coin a new term, or is
uncertain whether an existing term applies, must raise the question with the
project owner before implementing anything. If a decision is made, this file
must be updated with explicit approval. No amendment or exception may be made
unilaterally.

All agents and contributors who read this file must also pass it forward.
If you generate downstream instructions, tranche documents, tasking documents,
review requests, audit scopes, or delegated task descriptions, you must restate
the applicable vocabulary constraints there as well. Governance obligations do
not stop at the current document boundary.

## Entries

### `anti-fix`

**Part of speech:** noun (process and review concept)

**Definition:** A change that appears to address a problem locally but actually
masks, reroutes, clamps, or cosmetically suppresses the bad state without
repairing the owning contract, invariant, or root cause.

An anti-fix may make tests, logs, or screenshots look better while leaving the
underlying design wrong.

**Usage notes:** The correct response to a suspected anti-fix is to identify the
owning layer and repair the invariant there, or explicitly document why the
local policy is in fact the intended owner-level behavior.

**Proscribed alternates:** using `fix` for known masking changes; `workaround`
without explicit statement of scope, owner, and temporary/permanent status.

---

### `foundational tranche`

**Part of speech:** noun (workflow concept)

**Definition:** A tranche that exists to establish, repair, or migrate a shared
owner, contract, invariant, or architectural boundary before user-facing or
symptom-level tranches are attempted.

A foundational tranche is appropriate when multiple visible defects or feature
requests depend on one shared internal responsibility.

**Proscribed alternates:** `cleanup tranche`; `prep work` when the tranche
changes a real contract; `horizontal slice` when the work is actually owner-
establishing.

---

### `governance document`

**Part of speech:** noun (process concept)

**Definition:** Any project document whose directives are binding on planning,
implementation, verification, naming, documentation, or review behavior.

**Usage notes:** Governance documents are not optional background reading.
Agents and contributors must read applicable governance documents line by line,
comply with them, and pass their mandates forward into downstream instructions
and delegated work.

**Proscribed alternates:** `reference` when the document is actually binding;
`optional guidance` for mandatory governance.

---

### `host-framework contract`

**Part of speech:** noun (architecture and integration concept)

**Definition:** The externally defined behavior, conventions, invariants,
ownership model, or API semantics imposed by a library or framework the project
is built on or tightly integrated with.

**Usage notes:** Host-framework contracts must be verified from upstream
primary sources, not assumed from memory. Local wrappers and abstractions must
preserve them unless an explicit, documented, user-approved divergence is
intended.

**Proscribed alternates:** `upstream behavior` when the specific contract being
relied on has not been identified; informal phrases in place of a traced
contract.

---

### `ownership boundary`

**Part of speech:** noun (architecture concept)

**Definition:** The explicit boundary that determines which module, type,
subsystem, or layer owns a given responsibility, invariant, contract, or
policy, and which adjacent modules merely consume that owned behavior.

**Usage notes:** If multiple modules appear to be applying the same defensive
logic, that is evidence the ownership boundary may be wrong or unclear. Fixes
should move toward clearer ownership, not toward broader duplication.

**Proscribed alternates:** `somewhere in the stack`; `handled upstream`
without naming the owner.

---

### `pass forward` / `pass-forward`

**Part of speech:** verb phrase / adjective (governance process concept)

**Definition:** The obligation to restate and preserve all relevant governance,
controlled-vocabulary, upstream-reference, authorization-boundary, and
verification requirements in downstream instructions, workflow documents, task
descriptions, or delegated work.

To pass a mandate forward is not merely to link the parent document. It means
making the downstream recipient explicitly aware of what they must read, obey,
verify, and continue transmitting.

**Usage notes:** This term applies especially to agents. If an agent reads a
governance document and then creates a PRD, tranche file, tasking file, review
instruction, or delegated task without carrying forward the relevant mandates,
that agent has not complied with governance.

**Proscribed alternates:** `implied by context`; `assumed known`; `see above`
as a substitute for a real downstream governance block.

---

### `task`

**Part of speech:** noun (workflow concept)

**Definition:** A concrete, ordered unit of execution within a tranche. A task
must have a clear purpose, a clear verification condition, and a defined set of
dependencies or blockers.

Tasks are subordinate to tranches. They do not replace the need for sound
tranche framing.

**Proscribed alternates:** using `issue` to mean a task in workflow documents;
`step` when the unit carries formal execution and verification obligations.

---

### `tranche`

**Part of speech:** noun (workflow concept)

**Definition:** The canonical term for a bounded unit of planned work in the
workflow. A tranche may be user-facing, foundational, migration-oriented,
stabilization-focused, or review-gated, but it must always have a clear
purpose, clear dependencies, and clear verification criteria.

The term `tranche` is used to avoid collision with the overloaded word
"issue", which may otherwise refer to a problem, a GitHub issue, or an
arbitrary discussion thread.

**Usage notes:** Use `tranche` for the planned work unit, and reserve `issue`
for plain-English problem statements or for explicit GitHub issue references.

**Proscribed alternates:** using `issue` as the default workflow unit term in
project-generated planning documents; `ticket` unless referring to an external
system that actually uses that term.

---

### `upstream primary source`

**Part of speech:** noun (process and evidence concept)

**Definition:** The authoritative source material that defines the behavior,
contract, API, or policy of an external dependency, framework, renderer, or
tool on which the project relies.

Primary sources include official documentation, source files in the upstream
repository, accepted standards, and project-owned design documents when they
are the actual source of truth.

**Usage notes:** Secondary summaries, memory, or model recollection are not
substitutes when contract-sensitive behavior is at issue. When a change depends
on an upstream primary source, the exact source should be named and passed
forward into downstream planning and execution documents.

**Proscribed alternates:** `docs` when the exact authority is not specified;
vague paraphrases of host-framework behavior.

---

### `verification artifact`

**Part of speech:** noun (testing and review concept)

**Definition:** Any concrete artifact used to verify that work is correct at
the intended contract boundary.

Verification artifacts may include test results, rendered examples,
screenshots, pixel comparisons, docs builds, example outputs, migration checks,
benchmarks, or other reproducible evidence tied to the real acceptance
condition.

**Usage notes:** Verification artifacts should match the real failure mode. For
visual defects, geometry existence alone is often not a sufficient verification
artifact. For public API changes, docs and example behavior may be part of the
required artifact set.

**Proscribed alternates:** `proof` when no reproducible artifact is recorded;
`test coverage` as a substitute for a concrete acceptance artifact.
