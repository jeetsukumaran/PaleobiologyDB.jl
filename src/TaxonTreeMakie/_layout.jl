# ---------------------------------------------------------------------------
# TaxonTreeMakie — pure dendrogram layout
#
# All functions here are pure: they depend only on their arguments and produce
# no side effects.  They can be tested without loading Makie.
#
# Public (within extension):
#   _rank_depth(rank)                      → Int
#   _subtree_leaf_count(graph, v)          → Int
#   _compute_dendrogram_layout(tree; ...)  → (Vector{Float64}, Vector{Float64})
#   _dendrogram_segment_pairs(tree, x, y)  → Vector{NTuple{4,Float64}}
# ---------------------------------------------------------------------------

"""
Mapping from PBDB rank name to integer x-depth for dendrogram layout.

`"kingdom"` is assigned depth 0 (leftmost on the x-axis); `"subspecies"` is
depth 19 (rightmost).  Ranks not present in this dict receive `-1` from
[`_rank_depth`](@ref) and are treated as interior structural nodes with
approximate placement.
"""
const _RANK_DEPTH = Dict{String, Int}(
    "kingdom" => 0,
    "phylum" => 1,
    "subphylum" => 2,
    "superclass" => 3,
    "class" => 4,
    "subclass" => 5,
    "infraclass" => 6,
    "superorder" => 7,
    "order" => 8,
    "suborder" => 9,
    "infraorder" => 10,
    "superfamily" => 11,
    "family" => 12,
    "subfamily" => 13,
    "tribe" => 14,
    "subtribe" => 15,
    "genus" => 16,
    "subgenus" => 17,
    "species" => 18,
    "subspecies" => 19,
)

"""
    _rank_depth(rank::AbstractString) -> Int

Return the integer x-depth for `rank` in the dendrogram layout.

Returns `-1` for unknown or empty rank strings (e.g. `"unranked clade"`, `""`).
A return value of `-1` signals to [`_compute_dendrogram_layout`](@ref) that the
vertex should receive an approximate placement relative to its parent.

## Examples

```julia
_rank_depth("order")     # → 8
_rank_depth("genus")     # → 16
_rank_depth("unranked")  # → -1
```
"""
function _rank_depth(rank::AbstractString)::Int
    return get(_RANK_DEPTH, rank, -1)
end

"""
    _subtree_leaf_count(graph::Graphs.SimpleDiGraph, v::Integer) -> Int

Count the leaves (vertices with no outgoing edges) reachable from vertex `v`
in `graph`.

Returns `1` when `v` is itself a leaf (no children).  Used for ladderize
sorting: children with larger subtrees are placed lower in the layout, making
the tree appear more balanced.

## Arguments

- `graph`: a directed graph with parent→child edges (as in `TaxonTree.graph`).
- `v`: source vertex.
"""
function _subtree_leaf_count(
        graph::Graphs.SimpleDiGraph,
        v::Integer,
    )::Int
    children = Graphs.outneighbors(graph, v)
    isempty(children) && return 1
    return sum(_subtree_leaf_count(graph, c) for c in children)
end

# ---------------------------------------------------------------------------
# Internal: iterative post-order traversal with optional ladderize sorting
# ---------------------------------------------------------------------------

"""
    _postorder_traversal(
        graph::Graphs.SimpleDiGraph,
        root::Int;
        ladderize::Bool = false,
    ) -> Vector{Int}

Return the vertices of `graph` in post-order depth-first traversal from `root`.

When `ladderize = true`, children of each node are sorted by ascending subtree
leaf count before recursion, so smaller subtrees are visited first (and placed
higher on the y-axis in the resulting layout).

Post-order guarantees that every child vertex appears before its parent,
which is required by [`_compute_dendrogram_layout`](@ref) to assign y-values
bottom-up.
"""
function _postorder_traversal(
        graph::Graphs.SimpleDiGraph,
        root::Int;
        ladderize::Bool = false,
    )::Vector{Int}
    # Precompute per-vertex child lists (sorted if ladderize).
    children_of = Dict{Int, Vector{Int}}(
        v => (
                ladderize
                ? sort(
                    copy(Graphs.outneighbors(graph, v));
                    by = c -> _subtree_leaf_count(graph, c)
                )
                : copy(Graphs.outneighbors(graph, v))
            )
            for v in Graphs.vertices(graph)
    )

    order = Int[]
    sizehint!(order, Graphs.nv(graph))

    # Iterative post-order: stack entries are (vertex, children_visited_count).
    # When the count reaches length(children), the vertex itself is emitted.
    stack = Vector{Tuple{Int, Int}}()
    push!(stack, (root, 0))

    while !isempty(stack)
        v, idx = stack[end]
        ch = children_of[v]
        if idx < length(ch)
            stack[end] = (v, idx + 1)
            push!(stack, (ch[idx + 1], 0))
        else
            pop!(stack)
            push!(order, v)
        end
    end

    return order
end

# ---------------------------------------------------------------------------
# Public: dendrogram layout
# ---------------------------------------------------------------------------

"""
    _compute_dendrogram_layout(
        tree::TaxonTree;
        ladderize::Bool = false,
    ) -> Tuple{Vector{Float64}, Vector{Float64}}

Compute `(x, y)` axis positions for all vertices of `tree` for a rectangular
dendrogram layout.

## Layout rules

**x-coordinate** — derived from PBDB rank depth:
- `"kingdom"` → 0, `"phylum"` → 1, …, `"subspecies"` → 18.
- Vertices whose rank is absent from `_RANK_DEPTH` (e.g. `"unranked clade"`,
  `""`) receive `x = parent_x + 0.5`; the root with an unknown rank receives
  `x = 0.0`.  These approximations are resolved in BFS order (parent before
  child) so each unknown-rank vertex has a valid parent x already set.

**y-coordinate** — assigned by post-order DFS:
- Each leaf receives the next sequential integer (1, 2, 3, …).
- Each internal node receives the midpoint of its children's y range.

## Arguments

- `tree`: the [`TaxonTree`](@ref) to lay out.
- `ladderize`: when `true`, children of each node are sorted by ascending
  subtree leaf count before the DFS.  This spreads the tree asymmetrically,
  placing dense subtrees at the bottom and sparse subtrees at the top.

## Returns

`(x, y)` — both `Vector{Float64}` of length `Graphs.nv(tree.graph)`, indexed
by vertex index.

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy
import Graphs

tree = taxon_subtree("Carnivora"; leaf_rank = "family")

# Access the extension layout function after loading Makie:
xs, ys = PaleobiologyDB.TaxonTreeMakie._compute_dendrogram_layout(tree)
```
"""
function _compute_dendrogram_layout(
        tree::TaxonTree;
        ladderize::Bool = false,
    )::Tuple{Vector{Float64}, Vector{Float64}}
    g = tree.graph
    n = Graphs.nv(g)

    x = Vector{Float64}(undef, n)
    y = Vector{Float64}(undef, n)

    # ── Step 1: assign x from rank depth (−1 for unknown rank) ──────────────
    for v in 1:n
        x[v] = Float64(_rank_depth(tree.taxa[v].rank))
    end

    # ── Step 2: fix unknown-rank vertices in BFS order (parent → child) ─────
    # BFS ensures each parent's x is finalized before its children are visited.
    bfs_order = Vector{Int}()
    sizehint!(bfs_order, n)
    visited = falses(n)
    queue = [tree.root]
    visited[tree.root] = true
    push!(bfs_order, tree.root)

    while !isempty(queue)
        v = popfirst!(queue)
        for c in Graphs.outneighbors(g, v)
            if !visited[c]
                visited[c] = true
                push!(bfs_order, c)
                push!(queue, c)
            end
        end
    end

    for v in bfs_order
        x[v] >= 0.0 && continue   # known rank — already set
        parents = Graphs.inneighbors(g, v)
        x[v] = isempty(parents) ? 0.0 : x[parents[1]] + 0.5
    end

    # ── Step 3: assign y via post-order DFS ──────────────────────────────────
    postorder = _postorder_traversal(g, tree.root; ladderize = ladderize)
    leaf_y = 0
    for v in postorder
        children = Graphs.outneighbors(g, v)
        if isempty(children)
            leaf_y += 1
            y[v] = Float64(leaf_y)
        else
            y_min = minimum(y[c] for c in children)
            y_max = maximum(y[c] for c in children)
            y[v] = (y_min + y_max) / 2.0
        end
    end

    return (x, y)
end

# ---------------------------------------------------------------------------
# Public: segment generation
# ---------------------------------------------------------------------------

"""
    _dendrogram_segment_pairs(
        tree::TaxonTree,
        x::AbstractVector{<:Real},
        y::AbstractVector{<:Real},
    ) -> Vector{NTuple{4, Float64}}

Return the line segments for a rectangular dendrogram as a vector of
`(x1, y1, x2, y2)` tuples, one tuple per segment.

The caller converts these to `Makie.Point2f` pairs for `linesegments!`.

## Segments generated per internal vertex `v`

- **Vertical connector bar** at `x = x[v]`: spans the y-range of all direct
  children, from `(x[v], y_min_child)` to `(x[v], y_max_child)`.  Degenerate
  (zero-length) when `v` has only one child.
- **Horizontal branch** per child `c`: from `(x[v], y[c])` to `(x[c], y[c])`.

Leaf vertices produce no segments.

## Arguments

- `tree`: the source [`TaxonTree`](@ref).
- `x`, `y`: position vectors from [`_compute_dendrogram_layout`](@ref),
  indexed by vertex index.

## Returns

`Vector{NTuple{4, Float64}}` — one `(x1, y1, x2, y2)` per segment.
"""
function _dendrogram_segment_pairs(
        tree::TaxonTree,
        x::AbstractVector{<:Real},
        y::AbstractVector{<:Real},
    )::Vector{NTuple{4, Float64}}
    g = tree.graph
    segs = NTuple{4, Float64}[]

    for v in Graphs.vertices(g)
        children = Graphs.outneighbors(g, v)
        isempty(children) && continue

        # Vertical connector spanning all children's y-range
        y_min = minimum(y[c] for c in children)
        y_max = maximum(y[c] for c in children)
        push!(segs, (Float64(x[v]), y_min, Float64(x[v]), y_max))

        # Horizontal branch to each child
        for c in children
            push!(segs, (Float64(x[v]), Float64(y[c]), Float64(x[c]), Float64(y[c])))
        end
    end

    return segs
end

# ---------------------------------------------------------------------------
# Public: tip coordinate extraction
# ---------------------------------------------------------------------------

"""
    tip_positions(tree::TaxonTree, xs, ys) -> NamedTuple

Extract leaf-tip coordinates from a pre-computed dendrogram layout.

Returns a `NamedTuple` with fields:
- `vertices::Vector{Int}` — leaf vertex indices into `tree.graph`
- `names::Vector{String}` — accepted taxon name for each leaf
- `x::Vector{Float64}` — x coordinate in data units for each leaf
- `y::Vector{Float64}` — y coordinate in data units for each leaf

All four vectors are the same length and are aligned by index.

`xs` and `ys` are the layout vectors returned by
`_compute_dendrogram_layout`.

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy
using CairoMakie
using PaleobiologyDB.TaxonTreeMakie

tree = taxon_subtree("Panthera")
fig, ax, p = taxontreeplot(tree)
tips = tip_positions(p)   # convenience overload
# tips.names, tips.x, tips.y  — one entry per leaf
```

See also [`augment_tip_phylopic!`](@ref).
"""
function tip_positions(
        tree::TaxonTree,
        xs::AbstractVector{<:Real},
        ys::AbstractVector{<:Real},
    )::NamedTuple
    g = tree.graph
    lvs = [v for v in Graphs.vertices(g) if isempty(Graphs.outneighbors(g, v))]
    return (
        vertices = lvs,
        names = [tree.taxa[v].name for v in lvs],
        x = [Float64(xs[v]) for v in lvs],
        y = [Float64(ys[v]) for v in lvs],
    )
end
