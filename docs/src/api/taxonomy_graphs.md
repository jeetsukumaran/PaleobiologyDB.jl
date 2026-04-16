```@meta
CurrentModule = PaleobiologyDB.Taxonomy
```

# Taxonomy — Graphs

## Taxonomy tree graphs

`taxon_subtree` materialises a rooted taxonomic subtree as an explicit directed
graph — a [`TaxonTree`](@ref) wrapping a
[Graphs.jl](https://juliagraphs.org/Graphs.jl/) `SimpleDiGraph`.  Where
[`child_taxa`](@ref) and [`parent_taxa`](@ref) return flat name lists,
`taxon_subtree` preserves the full parent–child structure and enables graph
algorithms, tree traversals, and subtree visualisation.

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy
import Graphs
```

### Building a subtree

```julia
# Full descendant subtree of Carnivora (every rank, every node)
tree = taxon_subtree("Carnivora")

Graphs.nv(tree.graph)    # → total number of taxa
Graphs.ne(tree.graph)    # → total number of parent → child edges

# The root node
root_taxon(tree).name    # → "Carnivora"
root_taxon(tree).rank    # → "order"
```

### Truncating at a leaf rank

Pass `leaf_rank` to stop the traversal at a given rank.  By default
(`strict_leaf_rank = true`), only nodes at exactly `leaf_rank` become leaves;
any taxa at finer ranks that are direct children of a coarser node (an PBDB
data pattern common in less well-resolved groups) are excluded.
The intermediate ranks between the root and `leaf_rank` are retained as
interior nodes.

```julia
# Carnivora subtree truncated at family level (strict default)
#   interior nodes: order, suborder, …, superfamily
#   leaf nodes: family-rank taxa only; orphaned genera/species excluded
tree = taxon_subtree("Carnivora"; leaf_rank = "family")
Graphs.nv(tree.graph)   # order + suborders + superfamilies + families
Graphs.ne(tree.graph)   # one edge per parent → child pair

# leaf_taxa returns exclusively family-rank nodes
all(n.rank == "family" for n in leaf_taxa(tree))   # → true

# Genus-level subtree of Canidae (strict default)
#   interior: family, tribe, subfamily, …
#   leaves: genus-rank taxa only
t2 = taxon_subtree("Canidae"; leaf_rank = "genus")

# The leaf nodes are exactly the genera
leaf_taxa(t2) .|> (n -> n.name)
# → ["Borophagus", "Canis", "Urocyon", "Vulpes", …]

# Non-strict: also include orphaned finer-ranked taxa as leaves
t3 = taxon_subtree("Pterosauria"; leaf_rank = "family", strict_leaf_rank = false)

# Without leaf_rank → full descendant tree to finest available rank
t4 = taxon_subtree("Canis"; leaf_rank = nothing)
leaf_taxa(t4) |> length   # number of species under Canis
```

### Accessor functions

```julia
tree = taxon_subtree("Carnivora"; leaf_rank = "family")

# Root node
r = root_taxon(tree)
r.name      # → "Carnivora"
r.rank      # → "order"
r.pbdb_id   # → PBDB orig_no

# Leaf nodes (sorted by name)
leaves = leaf_taxa(tree)
leaves .|> (n -> n.name)   # → ["Ailuridae", "Amphicyonidae", "Canidae", …]

# All nodes at a specific rank (sorted by name)
taxa_at_rank(tree, "family")    # same as leaf_taxa when leaf_rank = "family"

# In a full (untruncated) tree, taxa_at_rank selects any rank
full_tree = taxon_subtree("Carnivora")
taxa_at_rank(full_tree, "genus")    |> length   # number of genera
taxa_at_rank(full_tree, "species")  |> length   # number of species
```

### TaxonNode fields

Every node in the tree is a `TaxonNode` carrying the full set of fields
from the PBDB taxa list snapshot:

```julia
node = root_taxon(tree)

node.name        # accepted taxon name (String)
node.rank        # rank string (String, e.g. "order")
node.pbdb_id     # PBDB orig_no (Int)
node.accepted_id # PBDB accepted_no (Union{Int,Missing})
                 #   == pbdb_id  for accepted (non-synonym) taxa
                 #   != pbdb_id  for synonyms — points to the valid name's orig_no
                 #   missing     when not recorded in the snapshot
node.parent_id   # parent orig_no, or missing for the subtree root (Union{Int,Missing})
```

### Using the graph with Graphs.jl

The `.graph` field is a standard `Graphs.SimpleDiGraph{Int}`, so any
algorithm from Graphs.jl that accepts an `AbstractGraph` works directly:

```julia
import Graphs

tree = taxon_subtree("Carnivora"; leaf_rank = "family")
g    = tree.graph

# Basic metrics
Graphs.nv(g)    # number of vertices
Graphs.ne(g)    # number of edges
Graphs.is_directed(g)   # → true (edges run parent → child)

# Neighbours of the root
Graphs.outneighbors(g, tree.root)   # vertex indices of root's children
Graphs.inneighbors(g, tree.root)    # → Int[] (root has no parent in subtree)

# Traverse from any vertex
v = tree.vertex_of[tree.taxa[1].pbdb_id]   # vertex for a node by pbdb_id
```

### Connecting the tree to an occurrence DataFrame

A common workflow is to build a clade tree and then map occurrences onto it
to see which sub-groups are represented in a dataset:

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy
import Graphs

# Fetch occurrences and build the family tree
df   = pbdb_occurrences(base_name = "Carnivora", interval = "Miocene", show = "full")
tree = taxon_subtree("Carnivora"; leaf_rank = "family")

# Which families appear in the occurrence data?
occ_families = Set(skipmissing(df.family))

sampled = [n for n in leaf_taxa(tree) if n.name in occ_families]
missing_ = [n for n in leaf_taxa(tree) if n.name ∉ occ_families]

println("$(length(sampled)) of $(length(leaf_taxa(tree))) families sampled in the Miocene")
```

```@docs
TaxonNode
TaxonTree
taxon_subtree
root_taxon
leaf_taxa
taxa_at_rank
```
