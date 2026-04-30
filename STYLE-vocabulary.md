---
date-created: 2026-04-18T23:01:00
date-revised: 2026-04-24T00:00:00
status: ratified
---

# Controlled vocabulary

This file is the authoritative terminology reference for this project.
All code, documentation, tests, tranche documents, issue reports, and pull requests must use the canonical
terms defined here. Proscribed terms must not appear in any identifier, type
name, function name, keyword argument, symbol, or field name.

**This list is not exhaustive and is not final.** Any agent, contributor, or
automated tool that needs to coin a new term, or is uncertain whether an
existing term applies, must raise the question with the project owner before
implementing anything. If a decision is made, this file must be updated with
explicit approval. No amendment or exception may be made unilaterally.

All agents and contributors who read this file must also pass it forward.
If you generate downstream instructions, tranche documents, tasking documents,
review requests, audit scopes, or delegated task descriptions, you must restate
the applicable vocabulary constraints there as well. Governance obligations do
not stop at the current document boundary.

For the decision log and ratification history, see
`.workflow-docs/log.20260418T2301--vocabulary.md`.

## Reader-facing prose versus API names

Controlled vocabulary distinguishes reader-facing prose from exact API names.
Use conventional spaced English terms in explanatory prose when that improves
clarity for readers outside the project. Use compact project spellings only
when referring to code identifiers, keyword arguments, symbols, struct fields,
or deliberate project terms.

Examples:

- Write "root node" in prose; write `rootnode` only for the exact positional
  argument name or code identifier.
- Write "edge weight" in prose; write `edgeweight` only for the exact accessor
  keyword, callable name, or code identifier.
- Write "node value" in prose; write `nodevalue` only for the exact accessor
  keyword, callable name, or code identifier.
- Introduce "lineage graph" with a short gloss in user-facing material before
  relying on it as a project term.
- Do not wrap ordinary prose terms in code font. Code font marks exact syntax.
- Code examples in this repository are project-owned code and must follow the
  canonical identifier forms. Use noncanonical identifiers only when showing a
  real third-party library API or user-supplied external data structure.

## Entries

### `axis_polarity`

**Part of speech:** noun (semantic concept); `LineageAxis` attribute name

**Definition:** The relationship between increasing process-coordinate values
and the direction of the modeled process. Has two values:

- `:forward` — increasing process coordinates move in the root-to-leaf
  direction (forward time). `lineageunits` values `:edgeweights`,
  `:branchingtime`, `:nodedepths`, and `:nodelevels` produce forward
  process coordinates (rootnode = 0, increases toward leaves).
- `:backward` — increasing process coordinates move in the leaf-to-root
  direction (backward time, as in coalescent models). `lineageunits` values
  `:coalescenceage` and `:nodeheights` produce backward process coordinates
  (leaves = 0, increases toward root).

`axis_polarity` is a property of the data and the active `lineageunits` value,
not of the screen. It is distinct from `display_polarity`, which governs the
screen direction. A `:backward` process coordinate does not imply a reversed
plot; the two are independently settable.

`LineageAxis` infers a default `axis_polarity` from the active `lineageunits`
value and exposes it as an overridable attribute for axis labeling and
semantic documentation.

**Proscribed alternates:** conflating with `display_polarity`; `time_direction`,
`polarity`, `orientation`.

---

### `boundingbox`

**Part of speech:** noun (geometry concept); identifier

**Definition:** The smallest axis-aligned rectangle that encloses all
`node_positions` in a layout. Returned by `boundingbox(::LineageGraphGeometry)`.
Written as one word without underscore.

**Proscribed alternates:** `bounding_box`, `extent`, `limits`, `bounds`.

---

### `branchingtime`

**Part of speech:** noun (data concept); accessor name

**Definition (concept):** IFF `edgeweight` values represent time in a time-indexed branching process, 
then this is the cumulative sum of `edgeweight` values on the directed path from `rootnode` to a given node. 
Represents the total
evolutionary or temporal distance accumulated since the root. Also called
"divergence time" in phylogenetic prose.

- `branchingtime(rootnode) = 0` by definition.
- `branchingtime(child) = branchingtime(parent) + edgeweight(parent, child)`.
- Polarity: increases in the forward-time direction (root → leaves), i.e., the
  x-axis reads left = past, right = present for a standard chronogram.

**Definition (as accessor):** The callable `branchingtime(node) -> Float64`
returning a pre-computed branching time for a node. Supplied as a keyword
argument when `lineageunits = :branchingtime`, for cases where the user has a
vector of pre-computed divergence times and does not want to re-derive them
from per-edge weights.

**Relationship to `lineageunits = :edgeweights`:** The `:edgeweights`
`lineageunits` value computes `branchingtime` on the fly by summing the
`edgeweight` accessor along the path from `rootnode`. The `:branchingtime`
`lineageunits` value bypasses that traversal and reads the value directly from
the `branchingtime` accessor. Both `lineageunits` values produce identical
node x-coordinates when the supplied times are consistent with the edge
lengths.

**Relationship to `coalescenceage`:** `branchingtime` and `coalescenceage` have
opposite polarity. For a strictly ultrametric tree:
`branchingtime(node) + coalescenceage(node) = branchingtime(deepest_leaf)`.

**Proscribed alternates:** `depth`, `distance_from_root`, `divergence_time`
(acceptable in prose only), `node_age` (different concept).

---

### `children`

**Part of speech:** noun (accessor name)

**Definition:** The callable accessor `children(node) -> iterable` that
returns zero or more child nodes of the given node. The only required
accessor in the LineagesMakie input contract. A node for which `children`
returns an empty iterable is a leaf.

**Proscribed alternates:** `child_func`, `get_children`, `offspring`,
`descendants` (when meaning immediate children).

---

### `clade graph` / `cladegraph`

**Part of speech:** noun (concept); one-word compound `cladegraph` in code
identifiers; adjective `cladological`.

**Definition:** The branching structure of a tree considered as a graph up to
label-preserving isomorphism — that is, the combinatorial structure specifying
which vertices are connected to which, without reference to any scalar quantity
on vertices or edges (no branch lengths, times, or weights). Two trees share the
same clade graph if and only if they are related by a label-preserving graph
isomorphism.

This is the sense in which the concept is colloquially called the
*phylogenetic "topology"* of a tree.

**Relationship to "topology":** The phylogenetic notion of "topology" (branching
pattern, without branch lengths) corresponds formally to a label-preserving
isomorphism class of graphs. This project uses `clade graph` in place of
"topology" to avoid collision with the mathematical discipline of topology
(continuity, open sets, homeomorphism), which is a distinct body of theory. On
first occurrence in a document or major section, use the expanded form:

> *the clade graph (the phylogenetic "topology", i.e. the tree as a graph up to
> label-preserving isomorphism)*

Subsequent uses within the same section may abbreviate to "clade graph".

**Derived forms:**
- `clade graph` — preferred prose form
- `cladegraph` — code identifier form (one word, no underscore; consistent with
  `edgeweight`, `coalescenceage`, `lineageunits`)
- `cladological` — adjectival form; e.g. "cladological distance" = path distance
  along the unweighted clade graph

**Usage notes:**
- Preferred expanded phrase when contrasting with metric/weighted layouts:
  `clade graph (branching pattern)` or `clade graph (unweighted edge layout)`.
- "topology-only plot" → "clade graph layout"
- "topology-only analogue" → "clade graph (unweighted) analogue"
- For path distance across the unweighted clade graph: use `path distance
  (number of edges)` or `unweighted path distance`; never "topological distance"
  or "step count".

**Proscribed alternates:** `topology` (unqualified), `tree topology`
(unqualified), `graph topology` (unqualified), `tree shape` (reserved term in
phylogenetics for an unlabeled/ranked structure). When citing prior literature,
always qualify: the phylogenetic `"topology"` (in quotation marks).

---

### `coalescenceage`

**Part of speech:** noun (data concept); accessor name

**Definition (concept):** The distance from a given node to the leaves,
measured in cumulative `edgeweight` units. Represents the elapsed time since
the evolutionary or coalescent event at that node. Also called "coalescent
age" or "backward time" in phylogenetic prose.

- `coalescenceage(leaf) = 0` by definition; a leaf at the present has age zero.
- `coalescenceage(parent) = edgeweight(parent, child) + coalescenceage(child)`
  for any direct child (ultrametric guarantee: all children give the same
  value).
- Polarity: increases in the backward-time direction (leaves → root), i.e., the
  x-axis reads left = distant past, right = present for a standard chronogram
  when `lineageunits = :coalescenceage`.

**Ultrametricity assumption:** `coalescenceage` is well-defined only for
ultrametric trees (all paths from any node to any of its leaf descendants have
equal total `edgeweight`). For non-ultrametric trees, three policies are
available via a `nonultrametric` keyword argument:
- `:minimum` — use the minimum over all descendant paths to a leaf.
- `:maximum` — use the maximum over all descendant paths to a leaf.
- `:error` (default) — raise `ArgumentError` if any two children yield
  inconsistent values.

**Computation from edge weights:** Can be computed in a post-order traversal:
leaves are assigned 0; each internal node is assigned
`edgeweight(parent, child) + coalescenceage(child)` for any child (or resolved via
the `nonultrametric` policy).

**Definition (as accessor):** The callable `coalescenceage(node) -> Float64`
returning the pre-computed coalescence age for a node. Supplied as a keyword
argument when `lineageunits = :coalescenceage`.

**Relationship to `branchingtime`:** See the `branchingtime` entry.

**Proscribed alternates:** `age` (as an identifier), `node_age`,
`vertex_age`, `vertexage`, `age_func`, `divergence_time` (different concept).

---

### `color`

**Part of speech:** noun / attribute name

**Definition:** The color of any rendered element (edge, marker, text, etc.).
US spelling `color` is used throughout, matching Makie's API convention.

**Proscribed alternates:** `colour` (in any identifier, attribute name, or code
comment; acceptable in display-facing prose text only if the project owner
explicitly approves).

---

### `display_polarity`

**Part of speech:** noun (rendering concept); `LineageAxis` attribute name

**Definition:** The mapping from process-coordinate values to screen direction
along the lineage axis. Has two values:

- `:standard` (default) — increasing process coordinates map to increasing
  screen position along `lineage_orientation` (right in `:left_to_right`
  orientation, up in `:bottom_to_top`). With forward axis polarity, this places
  the rootnode at the left and leaves at the right.
- `:reversed` — increasing process coordinates map to decreasing screen
  position. Allows, for example, a forward-time tree to be drawn root-at-right
  (paleontological or stratigraphic convention), or a `:coalescenceage` tree to
  be drawn with the rootnode at the left and leaves at the right.

`display_polarity` is independent of `axis_polarity`. The combination of the
two determines how the biological direction of the process maps to the screen.

**Proscribed alternates:** conflating with `axis_polarity`; `flip`, `invert`,
`reverse`, `reverse_axis`.

---

### `edge`

**Part of speech:** noun (structural concept)

**Definition:** A directed connection from `src` to `dst`. In all
code identifiers, the term `edge` is used exclusively. In biological prose,
"branch" is acceptable but should not appear in any identifier, keyword
argument, type name, or symbol.

**Proscribed alternates (in code):** `branch`, `arc`, `link`, `connection`.

---

### `edgeweight`

**Part of speech:** accessor name; prose form is "edge weight"

**Definition (as measure):** The scalar quantity associated with a directed
edge. Represents evolutionary distance, time span, or any arbitrary measurement concept. 
In reader-facing prose, write "edge weight".

**Definition (as accessor):** The callable `edgeweight(src, dst)`,
which returns either:
- a `Float64` value in data units, or
- a named tuple `(; value::Float64, units::Symbol)` with an explicit unit
  for conversion.

When the `edgeweight` accessor is not supplied, layout defaults to
`lineageunits = :nodeheights` (leaf-aligned clade graph plot).

**Proscribed alternates (as project-owned identifiers):**
`branch_length`, `edge_length`, `edge_len`, `edgelen`, `edgelength`, `length`, `weight`, `len`, `w`, $\el$.

---

### `edge_shapes`

**Part of speech:** noun (geometry)

**Definition:** The collection of geometric shapes (polylines, arcs, or segments)
that represent the visual shape of edges in a rendered layout. A field of
`LineageGraphGeometry`. Written with underscore (a multi-word field name, not a
compound accessor name).

**Proscribed alternates:** `edge_paths` (proscribed project-wide for this
concept), `edge paths` (prose form, proscribed for
this concept), `paths` (unqualified, proscribed for this concept),
`branch_paths`, `segments`, `edge_segments`. We reserve the term (edge) "paths" for 
the graph theoretic sense.

---

### `src`

**Part of speech:** noun (accessor argument)

**Definition:** The source (parent) node in a directed edge. First positional
argument of `edgeweight(src, dst)` and any other edge-level accessor.
Follows the `Graphs.jl` ecosystem convention.

**Proscribed alternates:** `fromnode`, `fromvertex`, `parent`, `v1`, `s`,
`from_node`, `from_vertex`.

---

### `height`

**Part of speech:** noun (measure); two related uses

**Definition (tree-level):** The maximum `branchingtime` of any node in the
tree, equivalently the `branchingtime` of the deepest leaf. For an ultrametric
tree, equals the `coalescenceage` of the root node.

**Definition (per-node):** The path distance (number of edges, ignoring
`edgeweight` values) from a given node to its farthest descendant leaf. Used
by the `:nodeheights` `lineageunits` value: all leaves have height = 0, and
each internal node has height = max(heights of children) + 1. This naturally
aligns all leaves at the same x-coordinate (the classic cladogram appearance).
`height` is the clade graph (unweighted edge) analogue of `coalescenceage`.

**Proscribed alternates:** `max_depth` (for tree-level height), `depth` (for
per-node height — these are now different concepts and `depth` is proscribed
entirely).

---

### `interval_schema`

**Part of speech:** noun (future capability); field name

**Definition:** A mapping from named intervals to axis coordinate ranges,
enabling visual elements to be placed by interval name rather than raw
coordinate. Geological timescales (epochs, periods, eras) are the motivating
example, but any named partition of the primary lineage axis qualifies.

An `interval_schema` value would map a symbol such as `:eocene` to a numeric
range on the `process_coordinate` axis, allowing annotations, background fills,
and overlays to be addressed by interval key. With two or more transverse
dimensions, intervals define cells in a coordinate lattice that can hold
arbitrary visual layers.

**Scope:** `interval_schema` is explicitly **Tier 4**. The term is recorded
here to reserve it and prevent incompatible uses in earlier tiers.

**Proscribed alternates:** `time_scale`, `epoch_map`, `interval_map`.

---

### `leaf` / `leaves`

**Part of speech:** noun (role)

**Definition:** A node for which `children` returns an empty iterable. The
terminal/outermost node in a tree. In code, `leaf` (singular) and `leaves`
(plural or iterator). The AbstractTrees.jl interface uses the same term
(`Leaves`, `isleaf`), which confirms this choice.

There is no assumed biological sense. A "leaf" is simply a node with no
children.

**Proscribed alternates:** `tip` (proscribed in all contexts — code,
identifiers, comments, and documentation), `terminal`, `taxa` (plural),
`leaf_node`.

---

### `leaf_order`

**Part of speech:** noun (geometry)

**Definition:** The ordered sequence of leaves as they appear along the
transverse axis of a layout (y-axis in rectangular layouts; angular position
in circular layouts). A field of `LineageGraphGeometry`.

**Proscribed alternates:** `tip_order`, `leaf_sequence`, `leaf_rank`.

---

### `leaf_spacing`

**Part of speech:** noun / keyword argument

**Definition:** The spacing between adjacent leaves along the transverse axis.
Keyword argument to layout functions. Default value `:equal` distributes leaves
evenly. A positive `Float64` value sets an explicit inter-leaf distance in
layout units.

**Proscribed alternates:** `tip_spacing`, `gap`, `interval`, `spacing`
(unqualified).

---

### `lineage graph` / `LineageGraph` / `lineagegraph`

**Part of speech:** noun phrase (core concept); `LineageGraph` in PascalCase type
names; `lineagegraph` (no underscore) in compound code identifiers.

**Definition:** The primary conceptual object that LineagesMakie.jl visualizes.
A lineage graph is a graph representing evolutionary relationships.

In Tier 1 the lineage graph is always a tree (each node has exactly one parent);
future tiers will extend to DAGs with shared ancestry (reticulation) and
eventually to general networks.

**Usage:**
- In prose: "lineage graph" (two words).
- In PascalCase type names: `LineageGraphAccessor`, `LineageGraphGeometry`.
- In compound identifiers: `lineagegraph_accessor` (underscore before a
  multi-word suffix, e.g. `lineagegraph_accessor`).
- Code examples that explicitly load a Newick file or interface with
  `AbstractTrees` may use "tree" when referring to the external object type;
  once that object is passed to LineagesMakie it is a "lineage graph".

**Proscribed alternates (in identifiers and internal prose):**
`tree` (as a generic name for the LineagesMakie input object), `phylotree`,
`phylogenetic tree` (acceptable in biological prose when describing the domain,
but not as a code identifier or type name). "Graph" alone is too generic and
does not capture lineage semantics; always use the full phrase "lineage graph"
in prose and `LineageGraph` / `lineagegraph` in code.

**Relationship to other terms:** A lineage graph is traversed via a
`LineageGraphAccessor`. Its computed 2D layout is stored in a
`LineageGraphGeometry`. The core plotting function is `lineageplot!`.

---

### `lineageunits`

**Part of speech:** noun (positioning concept); keyword argument name

**Definition:** The keyword argument that selects how node process coordinates
are determined during layout. Formerly referred to as `mode` in early design
drafts; renamed to `lineageunits` because `mode` is too generic to convey that
this keyword selects the unit and direction of the primary lineage axis.

The value of `lineageunits` determines which accessor is consulted to compute
the process coordinate (x in rectangular layouts, radial in circular) of each
node, and what `axis_polarity` `LineageAxis` infers:

- `:edgeweights` — cumulative edge weights from rootnode; requires `edgeweight`
  accessor; `:forward` polarity.
- `:branchingtime` — pre-supplied branching times; requires `branchingtime`
  accessor; `:forward` polarity.
- `:coalescenceage` — pre-supplied coalescence ages; requires `coalescenceage`
  accessor; leaf = 0, increases toward root; `:backward` polarity.
- `:nodedepths` — cumulative path distance (edge count) from rootnode; no
  accessor required; `:forward` polarity.
- `:nodeheights` — edge count to farthest leaf; leaves at 0; default when no
  `edgeweight` accessor is supplied; `:backward` polarity.
- `:nodelevels` — integer level from rootnode; equal inter-level spacing;
  no accessor required; `:forward` polarity.
- `:nodecoordinates` — user-supplied data coordinates; requires `nodecoordinates`
  accessor; polarity is user-defined.
- `:nodepos` — user-supplied pixel coordinates; requires `nodepos` accessor;
  polarity is user-defined.

Default selection: `:edgeweights` if an `edgeweight` accessor is supplied;
`:nodeheights` otherwise.

Written as one word without underscore, consistent with `edgeweight`,
`coalescenceage`, `branchingtime`.

**Proscribed alternates:** `mode`, `positioning_mode`, `layout_mode`,
`layout_type`, `tree_mode`.

---

### `lineage_orientation`

**Part of speech:** noun (rendering concept); `LineageAxis` attribute name

**Definition:** How the primary lineage axis is embedded in the 2D scene.
Controls which screen axis corresponds to lineage progression and which
corresponds to the transverse (leaf-spacing) dimension.

Values:
- `:left_to_right` (default for rectangular layouts) — the lineage axis runs
  along the x-axis; the transverse axis is y; rootnode is at the left by
  default.
- `:right_to_left` — lineage axis runs along x, transverse is y; rootnode
  is at the right by default (use with `:standard` `display_polarity` and a
  leaf-relative `lineageunits` such as `:coalescenceage`, or with `:reversed`
  `display_polarity` and a root-relative `lineageunits` value).
- `:bottom_to_top` — lineage axis runs along y; transverse is x.
- `:top_to_bottom` — lineage axis runs along y inverted; classic dendrogram
  orientation.
- `:radial` (default for circular layouts) — lineage axis is the radial
  dimension; transverse axis is angular.

`lineage_orientation` defines which physical screen axis carries the process
coordinate. `display_polarity` then controls which end of that axis has the
smaller values.

**Proscribed alternates:** `orientation`, `direction`, `tree_direction`,
`axis_orientation`.

---

### `marker`

**Part of speech:** noun (visual concept)

**Definition:** The visual symbol rendered at a node position (circle, square,
diamond, etc.). Follows Makie's naming convention. In prose, "glyph" is an
acceptable synonym; in code, `marker` is the only permitted term.

**Proscribed alternates (in code):** `glyph`, `symbol`, `shape`.

---

### `process_coordinate`

**Part of speech:** noun (conceptual / documentation term)

**Definition:** The scalar value that positions a node along the lineage axis.
In any given plot, the process coordinate is determined by the active
`lineageunits` value: `branchingtime` values for `lineageunits = :branchingtime`
or `:edgeweights`, `coalescenceage` values for `lineageunits = :coalescenceage`,
path distances (edge counts) for `:nodelevels` / `:nodedepths` / `:nodeheights`,
or user-supplied coordinates for `:nodecoordinates` / `:nodepos`.

This is a documentation and design term that unifies all `lineageunits` values
under a single concept. It does not appear as a code identifier (there is no
function or struct field named `process_coordinate`). When writing code, use
the specific accessor or `lineageunits` value.

`process_coordinate` is the concept that `axis_polarity` and `display_polarity`
operate on: `axis_polarity` describes the semantic direction of increasing
process-coordinate values; `display_polarity` describes their screen direction.

**Proscribed alternates (as a code identifier):** use specific accessor names
(`branchingtime`, `coalescenceage`, etc.).

---

### `rootnode`

**Part of speech:** positional argument name; prose form is "root node"

**Definition:** The unique node with no parent; the starting point of tree
traversal. Passed as the first positional argument to `lineageplot`,
`rectangular_layout`, `circular_layout`, and related functions. In
reader-facing prose, write "root node". Use `rootnode` only when referring to
the exact API argument or identifier.

**Proscribed alternates (as project-owned identifiers):**
`root`, `rootvertex`, `root_node`, `root_vertex`, `seed`, `seed_node`,
`source`, `origin`.

---

### `dst`

**Part of speech:** noun (accessor argument)

**Definition:** The destination (child) node in a directed edge. Second
positional argument of `edgeweight(src, dst)` and any other edge-level accessor.
Follows the `Graphs.jl` ecosystem convention.

**Proscribed alternates:** `tonode`, `tovertex`, `child`, `v2`, `d`,
`to_node`, `to_vertex`.

---

### `transverse_axis`

**Part of speech:** noun (conceptual / documentation term)

**Definition:** The dimension perpendicular to the primary lineage axis, along
which leaves are spaced. In rectangular layouts with `:left_to_right`
orientation, this is the y-axis; in circular layouts it is the angular
dimension. Transverse placement is determined by layout algorithms and
controlled primarily by `leaf_spacing`.

This is a documentation term providing a consistent name for the concept across
layout types. It does not appear as a code identifier.

**Proscribed alternates (as a code identifier):** use `leaf_spacing` and
`leaf_order`.

---

### `node` / `nodes`

**Part of speech:** noun (structural concept)

**Definition:** Any element of the graph: the root node, any internal
node, or any `leaf`. The generic term for a graph element. `nodes` is
the plural. In compound role-specific names, use the role term directly
(`leaf`, "root node", `internal node` in prose) rather than repeating `node`
where the role already implies it.
The use of `vertex` and related forms is acceptable in graph-theoretic
mathematical context or when quoting a third-party API.

**Proscribed alternates (as a generic term):** `vertex`, `vertices`. The words
`vertex` / `vertices` must not appear as generic synonyms for `node` in any
identifier, field name, keyword, type name, or symbol.

---

### `node_positions`

**Part of speech:** noun (geometry)

**Definition:** A `Dict` (or equivalent) mapping each node to its 2D
coordinate `Point2f` in layout space. A field of `LineageGraphGeometry`. Written with
underscore (multi-word field name).

**Proscribed alternates:** `vertex_positions`, `positions` (unqualified),
`coords`.

---

### `nodevalue`

**Part of speech:** accessor name; prose form is "node value"

**Definition:** The callable `nodevalue(node) -> Any` returning arbitrary
per-node data: bootstrap support, posterior probability, taxon name, age, or
any domain value. Used by label and color-mapping layers. In reader-facing
prose, write "node value". Use `nodevalue` only when referring to the exact
accessor keyword or callable name.

**Proscribed alternates:** `vertexvalue`, `vertex_value`, `node_value`
(underscored), `get_node_data`.

---

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

In this project, governance documents include `CONTRIBUTING.md`, all
applicable `STYLE*.md` files, and any additional policy or design-governance
documents explicitly designated by the project owner.

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
relied on has not been identified; `Makie way` or other informal phrases in
place of a traced contract.

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

**Definition:** The canonical term for a bounded unit of planned work in this
project's AI workflow. A tranche may be user-facing, foundational, migration-
oriented, stabilization-focused, or review-gated, but it must always have a
clear purpose, clear dependencies, and clear verification criteria.

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
`what Makie does` or similar vague paraphrases.

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

---

## Layer recipe names

| Canonical recipe type | Canonical function | Former name (proscribed) |
|---|---|---|
| `EdgeLayer` | `edgelayer!` | `BranchLayer`, `branchlayer!` |
| `NodeLayer` | `nodelayer!` | `VertexLayer`, `vertexlayer!` |
| `LeafLayer` | `leaflayer!` | `TipLayer`, `tiplayer!` |
| `LeafLabelLayer` | `leaflabellayer!` | `TipLabelLayer`, `tiplabellayer!` |
| `NodeLabelLayer` | `nodelabellayer!` | `VertexLabelLayer`, `vertexlabellayer!` |
| `CladeHighlightLayer` | `cladehighlightlayer!` | — |
| `CladeLabelLayer` | `cladelabellayer!` | — |
| `ScaleBarLayer` | `scalebarlayer!` | — |
| `LineagePlot` | `lineageplot!` | — |

## Layout `lineageunits`

| Symbol | Accessor required | x-coordinate source | Polarity | `axis_polarity` |
|---|---|---|---|---|
| `:edgeweights` | `edgeweight` | Cumulative `edgeweight(src, dst)` from `rootnode`; computes `branchingtime` on the fly | Root = 0, increases toward leaves | `:forward` |
| `:branchingtime` | `branchingtime` | `branchingtime(node)` directly; user pre-supplies divergence times | Root = 0, increases toward leaves | `:forward` |
| `:coalescenceage` | `coalescenceage` | `coalescenceage(node)`; requires ultrametric tree (or `nonultrametric` policy) | Leaf = 0, increases toward root | `:backward` |
| `:nodedepths` | none | Cumulative path distance (edge count) from `rootnode` (all edge weights = 1) | Root = 0, increases toward leaves | `:forward` |
| `:nodeheights` | none | Per-node height (path distance to farthest leaf); all leaves at x = 0; clade graph (unweighted) analogue of `:coalescenceage` | Leaf = 0, increases toward root | `:backward` |
| `:nodelevels` | none | Integer level = edge count from `rootnode`; equal spacing between levels; clade graph (unweighted) analogue of `:branchingtime` | Root = 0, increases toward leaves | `:forward` |
| `:nodecoordinates` | `nodecoordinates` | User-supplied `(x, y)` in data coordinates | User-defined | User-defined |
| `:nodepos` | `nodepos` | User-supplied `(x, y)` in pixel coordinates | User-defined | User-defined |

**Default `lineageunits`:** `:edgeweights` if an `edgeweight` accessor is
supplied; `:nodeheights` otherwise.

**Polarity summary:** `lineageunits` values that are root-relative
(`:edgeweights`, `:branchingtime`, `:nodedepths`, `:nodelevels`) have
`:forward` `axis_polarity` and assign the root x = 0 increasing toward the
leaves. `lineageunits` values that are leaf-relative (`:coalescenceage`,
`:nodeheights`) have `:backward` `axis_polarity` and assign leaves x = 0
increasing toward the root. With the default `display_polarity = :standard`
and `lineage_orientation = :left_to_right`, forward `lineageunits` values
place leaves at the right; backward `lineageunits` values place the
rootnode at the right.

## Compound-word naming convention

Compound accessor names and domain-specific identifiers in this package are
written without underscores when the compound reads naturally as a single
concept: `edgeweight`, `nodevalue`, `coalescenceage`, `branchingtime`,
`rootnode`, `boundingbox`, `lineageunits`. This is consistent with
STYLE-julia.md §2.1, which permits omitting underscores when the name is not
hard to read.

Edge-endpoint parameters `src` and `dst` are short conventional forms (3
characters each) following the `Graphs.jl` ecosystem; they are an approved
exception to the "full word preferred" rule in STYLE-julia.md §2.4.

Multi-word field names on structs retain underscores: `node_positions`,
`edge_shapes`, `leaf_order`, `leaf_spacing`, `axis_polarity`, `display_polarity`,
`lineage_orientation`, `interval_schema`.

## Project-specific short-form canonical table

The table below records this project's canonical identifier forms for each
domain concept, governed jointly by STYLE-julia.md §2.4 (identifier form rules)
and this document (lexeme choices). All proscribed forms in the right column
must not appear in project-owned identifiers, field names, keywords, type
names, or symbols, including code examples.

| Concept | Canonical form | Type-param form | Proscribed short forms |
|---|---|---|---|
| A generic graph node | `node` (full word) | `NodeT` | `n`, `nd`, `v`, `V` |
| Root node | `rootnode` (one word) | — | `root`, `rootvertex`, `root_node` |
| Edge source (parent node) | `src` | — | `fromnode`, `fromvertex`, `s`, `from_node` |
| Edge destination (child node) | `dst` | — | `tonode`, `tovertex`, `d`, `to_node` |
| Indexed nodes | `node1`, `node2` | — | `n1`, `n2`, `v1`, `v2` |
| Child node (loop variable) | `child` | — | `c`, `ch` (when meaning child node) |
| Children collection (local var) | `child_collection` | — | `ch`, `children` (collision with `AbstractTrees.children`) |
| Node identity type parameter | — | `NodeT` | `V`, `N`, `T` |
| Collection of all nodes | `all_nodes` | — | `all_vertices`, `vs` |
| Node data accessor | `nodecoordinates` / `nodepos` | `NC` / `NP` | `vertexcoords`, `vertexpos`, `vc`, `vp` |
