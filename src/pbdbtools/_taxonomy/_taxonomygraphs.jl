# ---------------------------------------------------------------------------
# Taxonomy graph construction
#
# Provides TaxonNode, TaxonomyTree, and taxon_subtree for materialising a
# taxonomic subtree from the Scratch-cached PBDB taxa list snapshot as an
# explicit directed graph (Graphs.jl SimpleDiGraph, edges parent → child).
#
# Indices reused from _taxonomy_augment.jl and _taxonomy_queries.jl
# (included before this file):
#   _TAXA_HIERARCHY_NAME_INDEX  taxon_name → orig_no  (accepted entries)
#   _TAXA_HIERARCHY_NO_INDEX    orig_no    → (name, rank, parent_no)
#   _TAXA_CHILDREN_INDEX        orig_no    → Vector{Int} of child orig_nos
#
# Public API:
#   TaxonNode     — immutable node carrying name, rank, PBDB id, parent id,
#                   and an optional metadata slot (type parameter M)
#   TaxonomyTree     — wrapper around a SimpleDiGraph plus per-vertex TaxonNode vector
#   taxon_subtree — build a TaxonomyTree rooted at a named taxon
#   root_taxon    — return the root TaxonNode
#   leaf_taxa     — return all leaf TaxonNodes (vertices with no children)
#   taxa_at_rank  — return all TaxonNodes at a given rank
# ---------------------------------------------------------------------------

export TaxonNode, TaxonomyTree, taxon_subtree, root_taxon, leaf_taxa, taxa_at_rank

# ---------------------------------------------------------------------------
# TaxonNode
# ---------------------------------------------------------------------------

"""
    TaxonNode

A single node in a taxonomic tree, carrying the full set of identity fields
from the PBDB taxa list snapshot.

## Fields

- `name::String`                        — accepted taxon name (as in PBDB)
- `rank::String`                        — taxonomic rank (e.g. `"genus"`, `"family"`)
- `pbdb_id::Int`                        — PBDB `orig_no` integer identifier
- `accepted_id::Union{Int,Missing}`     — PBDB `accepted_no`; equals `pbdb_id`
  for accepted (non-synonym) taxa, points to the valid name for synonyms,
  `missing` when not recorded in the snapshot
- `parent_id::Union{Int,Missing}`       — `orig_no` of the parent node, or
  `missing` when this node is the root of the subtree

## Construction

```julia
TaxonNode("Canis", "genus", 41045, 41045, 2)
#          name     rank     pbdb_id accepted_id parent_id
```

See also [`TaxonomyTree`](@ref), [`taxon_subtree`](@ref).
"""
struct TaxonNode
    name::String
    rank::String
    pbdb_id::Int
    accepted_id::Union{Int, Missing}
    parent_id::Union{Int, Missing}
end

# ---------------------------------------------------------------------------
# TaxonomyTree
# ---------------------------------------------------------------------------

"""
    TaxonomyTree

A rooted, directed tree representing a taxonomic subtree extracted from
the PBDB taxa list snapshot.

## Fields

- `graph::Graphs.SimpleDiGraph{Int}` — directed graph; edges run
  parent → child.  Vertices are integers in `1 .. Graphs.nv(graph)`.
- `taxa::Vector{TaxonNode}`          — `taxa[v]` is the [`TaxonNode`](@ref)
  for vertex `v`.
- `vertex_of::Dict{Int,Int}`         — maps PBDB `orig_no` → vertex index,
  allowing O(1) lookup by numeric PBDB identifier.
- `root::Int`                        — vertex index of the root node
  (always `1`).

## Working with Graphs.jl

`TaxonomyTree` wraps a standard `Graphs.SimpleDiGraph`, so any function from
[Graphs.jl](https://juliagraphs.org/Graphs.jl/) that accepts an
`AbstractGraph` works directly on `tree.graph`:

```julia
using Graphs

t = taxon_subtree("Carnivora"; leaf_rank = "family")

Graphs.nv(t.graph)                         # number of nodes
Graphs.ne(t.graph)                         # number of edges
Graphs.outneighbors(t.graph, t.root)       # vertex indices of root's children
Graphs.is_tree(t.graph)                    # always true for a valid subtree
```

See also [`taxon_subtree`](@ref), [`TaxonNode`](@ref).
"""
struct TaxonomyTree
    graph::Graphs.SimpleDiGraph{Int}
    taxa::Vector{TaxonNode}
    vertex_of::Dict{Int, Int}
    root::Int
end

# ---------------------------------------------------------------------------
# Internal: build a TaxonomyTree from BFS-collected triples
# ---------------------------------------------------------------------------

# Each triple is (orig_no::Int, parent_orig_no::Union{Int,Missing}, info::_TaxonInfo)
function _build_taxonomy_tree(
        collected::Vector{Tuple{Int, Union{Int, Missing}, Any}},
    )::TaxonomyTree
    n = length(collected)

    # Vertex 1 = root (first element); rest follow BFS order
    vertex_of = Dict{Int, Int}(orig_no => v for (v, (orig_no, _, _)) in enumerate(collected))

    g = Graphs.SimpleDiGraph{Int}(n)
    taxa = Vector{TaxonNode}(undef, n)

    for (v, (orig_no, parent_no, info)) in enumerate(collected)
        taxa[v] = TaxonNode(info.name, info.rank, orig_no, info.accepted_no, parent_no)
        if !ismissing(parent_no)
            parent_v = vertex_of[parent_no]
            Graphs.add_edge!(g, parent_v, v)
        end
    end

    return TaxonomyTree(g, taxa, vertex_of, 1)
end

# ---------------------------------------------------------------------------
# Public API: taxon_subtree
# ---------------------------------------------------------------------------

"""
    taxon_subtree(taxon_name; leaf_rank=nothing, strict_leaf_rank=true) -> TaxonomyTree

Build and return a [`TaxonomyTree`](@ref) rooted at `taxon_name`, descending
through the taxonomic hierarchy down to (and including) `leaf_rank`.

The tree is derived from the Scratch-cached PBDB taxa list snapshot; no
network requests are made.  The snapshot is downloaded on first use and
refreshed automatically when older than 30 days.

## Arguments

- `taxon_name::AbstractString` — accepted taxon name exactly as it appears
  in PBDB (e.g. `"Carnivora"`, `"Canidae"`, `"Canis"`).
- `leaf_rank::Union{AbstractString,Nothing}` (keyword, default `nothing`) —
  the rank at which to stop recursing.  Must be one of:

      "subspecies" "species" "subgenus" "genus" "subtribe" "tribe"
      "subfamily" "family" "superfamily" "infraorder" "suborder" "order"
      "superorder" "infraclass" "subclass" "class" "superclass"
      "subphylum" "phylum" "kingdom"

  When `nothing` (default), the entire descendant subtree is collected.
  When given, nodes at `leaf_rank` become leaves of the returned tree;
  their children in the full PBDB tree are not included.  Intermediate ranks
  between the root rank and `leaf_rank` are included as interior nodes.

- `strict_leaf_rank::Bool` (keyword, default `true`) — controls how nodes at
  ranks finer than `leaf_rank` are handled.

  In real PBDB data, taxa at finer ranks (e.g. a genus or species) are
  sometimes direct children of coarse-rank nodes (e.g. an order) without an
  intervening family.  When `strict_leaf_rank = true` (default), such nodes
  are excluded entirely from the returned tree — the leaves will all be at
  exactly `leaf_rank` (or at an unranked-clade rank if no ranked leaf was
  reachable).  When `strict_leaf_rank = false`, finer-ranked nodes are
  included as leaf nodes, preserving all PBDB parent–child edges.

  Has no effect when `leaf_rank` is `nothing`.

## Returns

A [`TaxonomyTree`](@ref) rooted at the named taxon.  Returns a single-node
tree (root only, no edges) when `taxon_name` is not found in the snapshot.

Throws `ArgumentError` if `leaf_rank` is not a valid PBDB rank string.

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy
import Graphs

# Full subtree of Carnivora (every descendant at every rank)
t = taxon_subtree("Carnivora")
Graphs.nv(t.graph)           # thousands of nodes
root_taxon(t).rank           # "order"

# Strict default: leaves are exactly families; orphaned genera excluded
t2 = taxon_subtree("Carnivora"; leaf_rank = "family")
leaf_taxa(t2) .|> (n -> n.name)   # ["Ailuridae", "Canidae", "Felidae", …]
all(n.rank == "family" for n in leaf_taxa(t2))   # true

# Non-strict: orphaned genera/species included as leaves
t3 = taxon_subtree("Pterosauria"; leaf_rank = "family", strict_leaf_rank = false)
# taxa at genus or species rank parented directly to order appear as leaves

# Genus-level subtree of Canidae
t4 = taxon_subtree("Canidae"; leaf_rank = "genus")

# Unknown taxon → single-node tree
t5 = taxon_subtree("INVALID")
Graphs.nv(t5.graph)          # 1
```

See also [`root_taxon`](@ref), [`leaf_taxa`](@ref), [`taxa_at_rank`](@ref),
[`child_taxa`](@ref), [`TaxonomyTree`](@ref).
"""
function taxon_subtree(
        taxon_name::AbstractString;
        leaf_rank::Union{AbstractString, Nothing} = nothing,
        strict_leaf_rank::Bool = true,
    )::TaxonomyTree
    _ensure_children_index()

    name_to_no = _TAXA_HIERARCHY_NAME_INDEX[]
    no_to_info = _TAXA_HIERARCHY_NO_INDEX[]
    children_idx = _TAXA_CHILDREN_INDEX[]

    start_no = get(name_to_no, taxon_name, nothing)

    if isnothing(start_no)
        # Unknown taxon — return a single-node placeholder tree
        placeholder = TaxonNode(string(taxon_name), "", 0, missing, missing)
        g = Graphs.SimpleDiGraph{Int}(1)
        return TaxonomyTree(g, [placeholder], Dict{Int, Int}(0 => 1), 1)
    end

    start_info = no_to_info[start_no]

    # Validate leaf_rank early so a bad argument fails before any traversal
    target_rank_idx::Union{Int, Nothing} =
        isnothing(leaf_rank) ? nothing : _pbdb_rank_index(leaf_rank)

    # BFS: collect (orig_no, parent_orig_no, info) triples in traversal order
    # (root first, so vertex 1 is always the root)
    Collected = Tuple{Int, Union{Int, Missing}, Any}
    collected = Collected[(start_no, missing, start_info)]

    visited = Set{Int}()
    # Queue carries (orig_no, parent_orig_no) pairs
    queue = Tuple{Int, Union{Int, Missing}}[(start_no, missing)]

    while !isempty(queue)
        (cur_no, _) = popfirst!(queue)
        cur_no in visited && continue
        push!(visited, cur_no)

        for child_no in get(children_idx, cur_no, Int[])
            child_no in visited && continue
            info = get(no_to_info, child_no, nothing)
            isnothing(info) && continue

            child_rank_idx = findfirst(==(info.rank), PBDB_RANK_HIERARCHY)

            if isnothing(target_rank_idx)
                # No rank filter — collect and recurse everywhere
                push!(collected, (child_no, cur_no, info))
                push!(queue, (child_no, cur_no))

            elseif isnothing(child_rank_idx)
                # Unknown rank (e.g. "unranked clade") — treat as an interior
                # node: collect it so it gets a vertex index, then recurse so
                # its descendants are also included.  Skipping collection but
                # still recursing would leave dangling parent_no references in
                # _build_taxonomy_tree (KeyError when any collected descendant's
                # parent_no points to this uncollected node).
                push!(collected, (child_no, cur_no, info))
                push!(queue, (child_no, cur_no))

            elseif child_rank_idx < target_rank_idx
                # Strictly finer than leaf_rank.
                # (PBDB_RANK_HIERARCHY is fine → coarse; smaller index = finer rank)
                if strict_leaf_rank
                    # Skip entirely — do not collect, do not recurse.
                    # Orphaned finer-ranked taxa (e.g. a genus directly under an
                    # order) are excluded from the returned tree.
                    nothing
                else
                    # Non-strict: include as a leaf node, no recursion.
                    push!(collected, (child_no, cur_no, info))
                end

            elseif child_rank_idx == target_rank_idx
                # Exactly at leaf_rank → collect as leaf, do not recurse.
                push!(collected, (child_no, cur_no, info))

            else
                # Coarser than leaf_rank → intermediate interior node
                push!(collected, (child_no, cur_no, info))
                push!(queue, (child_no, cur_no))
            end
        end
    end

    return _build_taxonomy_tree(collected)
end

# ---------------------------------------------------------------------------
# Public API: accessors
# ---------------------------------------------------------------------------

"""
    root_taxon(tree::TaxonomyTree) -> TaxonNode

Return the root [`TaxonNode`](@ref) of `tree`.

## Examples

```julia
t = taxon_subtree("Carnivora")
root_taxon(t).name    # "Carnivora"
root_taxon(t).rank    # "order"
```

See also [`leaf_taxa`](@ref), [`taxa_at_rank`](@ref).
"""
function root_taxon(tree::TaxonomyTree)::TaxonNode
    return tree.taxa[tree.root]
end

"""
    leaf_taxa(tree::TaxonomyTree) -> Vector{TaxonNode}

Return all leaf nodes of `tree` — vertices with no outgoing edges (no
children in the subtree) — sorted by name.

When `taxon_subtree` was called with a `leaf_rank`, these are typically all
nodes at exactly `leaf_rank`.  The exception is interior nodes at coarser
ranks that have no `leaf_rank`-level descendants: those nodes are included in
the tree but have no children, so they also appear as leaves.  Without
`leaf_rank`, they are the most finely resolved taxa included in the tree.

## Examples

```julia
t = taxon_subtree("Carnivora"; leaf_rank = "family")
leaf_taxa(t) .|> (n -> n.name)   # ["Ailuridae", "Canidae", …]
```

See also [`root_taxon`](@ref), [`taxa_at_rank`](@ref).
"""
function leaf_taxa(tree::TaxonomyTree)::Vector{TaxonNode}
    g = tree.graph
    nodes = [tree.taxa[v] for v in Graphs.vertices(g) if isempty(Graphs.outneighbors(g, v))]
    return sort!(nodes; by = n -> n.name)
end

"""
    taxa_at_rank(tree::TaxonomyTree, rank::AbstractString) -> Vector{TaxonNode}

Return all nodes in `tree` whose `rank` field equals `rank`, sorted by name.

Returns an empty vector when no nodes at `rank` are present.

Throws `ArgumentError` if `rank` is not a valid PBDB rank string.

## Examples

```julia
t = taxon_subtree("Carnivora")
taxa_at_rank(t, "family") .|> (n -> n.name)  # ["Ailuridae", "Canidae", …]
taxa_at_rank(t, "genus")  |> length          # number of genera in Carnivora
```

See also [`root_taxon`](@ref), [`leaf_taxa`](@ref).
"""
function taxa_at_rank(
        tree::TaxonomyTree,
        rank::AbstractString,
    )::Vector{TaxonNode}
    _pbdb_rank_index(rank)   # throws ArgumentError for unknown ranks
    nodes = [n for n in tree.taxa if n.rank == rank]
    return sort!(nodes; by = n -> n.name)
end
