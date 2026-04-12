# Taxonomy

The `Taxonomy` submodule provides tools for validating and cleaning
palaeobiological data against the PBDB taxonomic authority.

```julia
using PaleobiologyDB.Taxonomy
```

## Combined taxonomic quality filter

`drop_unqualified_taxa` is the top-level function for cleaning occurrence
DataFrames.  It applies two independent filters in sequence: a *resolution*
check (is the identification specific enough?) and a *name-validity* check (is
the name actually in the PBDB taxonomy?).

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy

df = pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")

# Keep rows resolved and recognized at genus level
df_genus = drop_unqualified_taxa(df, "genus")

# Keep rows resolved and recognized at species level
# ("species" maps to the accepted_name column for the name check)
df_species = drop_unqualified_taxa(df, "species")

# In-place variant (modifies df directly)
drop_unqualified_taxa!(df, "family")

# Use live API validation instead of the local snapshot
df_clean = drop_unqualified_taxa(df, "genus"; validation_authority = :query)
```

```@docs
PaleobiologyDB.Taxonomy.drop_unqualified_taxa
PaleobiologyDB.Taxonomy.drop_unqualified_taxa!
```

## Taxonomy resolution filter

These functions check that each row is identified to at least a given
taxonomic rank, based on the `accepted_rank` column.

```julia
using PaleobiologyDB.Taxonomy

# Keep rows where accepted_rank is "genus", "species", or "subspecies"
df_resolved = drop_unresolved_taxa(df, "genus")

# Equivalent shorthand using a column symbol
df_resolved = drop_unresolved_taxa(df, :genus)

# :accepted_name maps to "species" resolution
df_resolved = drop_unresolved_taxa(df, :accepted_name)

# In-place variant
drop_unresolved_taxa!(df, "family")
```

```@docs
PaleobiologyDB.Taxonomy.drop_unresolved_taxa
PaleobiologyDB.Taxonomy.drop_unresolved_taxa!
```

## Taxonomy name-validity filter

These functions check taxon names against the PBDB taxonomy using either a
local Scratch-managed snapshot (default, O(1) lookups after the initial
download) or live API queries.

```julia
using PaleobiologyDB.Taxonomy

# Single-name check
istaxon("Pliosauridae")            # → true
istaxon("NO_FAMILY_SPECIFIED")     # → false

# Audit a DataFrame column
mask = audit_taxonomy(df, :family)
df[mask, :]

# Filter to recognized taxa only (non-mutating)
df_clean = drop_unrecognized_taxa(df, :family)

# In-place variant
drop_unrecognized_taxa!(df, :family)
```

```@docs
PaleobiologyDB.Taxonomy.istaxon
PaleobiologyDB.Taxonomy.audit_taxonomy
PaleobiologyDB.Taxonomy.drop_unrecognized_taxa
PaleobiologyDB.Taxonomy.drop_unrecognized_taxa!
```

## Taxonomy augmentation

`augment_taxonomy` enriches an occurrences DataFrame with the full taxonomic
hierarchy for each row, resolved from the Scratch-cached PBDB taxa list.

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy

df = pbdb_occurrences(base_name = "Carnivora", interval = "Miocene", limit = 500)

# Add taxonomy_genus, taxonomy_family, …, taxonomy_kingdom, taxonomy_clades columns
df2 = augment_taxonomy(df)

# Filter for a specific subfamily
df2[.!ismissing.(df2.taxonomy_subfamily) .&& df2.taxonomy_subfamily .== "Borophaginae", :]

# Inspect a taxonomy string
df2.taxonomy_clades[1]
# → "Animalia > Chordata > Mammalia > Carnivora > Canidae > Borophaginae > Epicyon"
```

```@docs
PaleobiologyDB.Taxonomy.augment_taxonomy
```

## Taxonomic rank hierarchy

```@docs
PaleobiologyDB.Taxonomy.PBDB_RANK_HIERARCHY
```

## Taxonomy tree queries

These functions navigate the PBDB taxonomic hierarchy by name, returning
descendants or ancestors at a requested rank.  All functions are backed by the
same Scratch-managed snapshot used by the filters above and build their indices
on first use (no extra download required).

```julia
using PaleobiologyDB.Taxonomy

# Valid rank names
taxonomic_ranks()
# → ["subspecies", "species", "genus", …, "kingdom"]

# All accepted taxon names (tens of thousands)
registered_taxa()

# Names matching a pattern
registered_taxa(r"^Canis\b")
# → ["Canis", "Canis aureus", "Canis lupus", …]

# Union of patterns
registered_taxa([r"^Canis\b", r"^Vulpes\b"])

# All families within Carnivora
child_taxa("Carnivora", "family")
# → ["Ailuridae", "Amphicyonidae", "Canidae", "Felidae", …]

# All genera within Canidae
child_taxa("Canidae", "genus")
# → ["Borophagus", "Canis", "Lycaon", "Urocyon", "Vulpes", …]

# All species within a genus
child_taxa("Canis", "species")
# → ["Canis aureus", "Canis lupus", "Canis mesomelas", …]

# Every descendant at any rank (no filter)
child_taxa("Canidae")

# Full ancestor chain of a species, child → root
parent_taxa("Canis lupus")
# → ["Canis", "Canidae", "Carnivora", "Mammalia", …, "Animalia"]

# Only the family
parent_taxa("Canis lupus", "family")
# → ["Canidae"]
```

```@docs
PaleobiologyDB.Taxonomy.taxonomic_ranks
PaleobiologyDB.Taxonomy.registered_taxa
PaleobiologyDB.Taxonomy.child_taxa
PaleobiologyDB.Taxonomy.parent_taxa
```

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
PaleobiologyDB.Taxonomy.TaxonNode
PaleobiologyDB.Taxonomy.TaxonTree
PaleobiologyDB.Taxonomy.taxon_subtree
PaleobiologyDB.Taxonomy.root_taxon
PaleobiologyDB.Taxonomy.leaf_taxa
PaleobiologyDB.Taxonomy.taxa_at_rank
```

## Taxon occurrence search: taxon_occursin

`taxon_occursin` searches for taxonomic patterns across multiple columns. It comes in two forms:

- **2-arg** `taxon_occursin(pattern, df)` → `Vector{Bool}` — searches across all
  taxonomy columns; use for `df[mask, :]` filtering.
- **1-arg** `taxon_occursin(pattern)` → `ByRow` predicate — for use directly with
  `subset(df, :col => taxon_occursin(pattern))`.

By placing the pattern first, this function works naturally with piping and functional composition.

Vector inputs (`AbstractVector{<:AbstractString}` or `AbstractVector{<:Regex}`) accept
a `combine` keyword (`all` by default): `combine=all` requires **all** elements to
match (AND); `combine=any` requires **any** to match (OR).

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy: taxon_occursin

df = pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")

# 2-arg: multi-column boolean mask
df[taxon_occursin("Canis", df), :]
df[taxon_occursin(r"^Canis\b", df), :]

# 2-arg: AND — every name must appear in some column (default combine=all)
df[taxon_occursin(["Canis", "Mammalia"], df), :]

# 2-arg: OR — any name matches any column
df[taxon_occursin(["Canis", "Vulpes"], df; combine=any), :]

# 2-arg: AND patterns — each regex must match at least one column
df[taxon_occursin([r"Canidae", r"Canis"], df), :]

# 1-arg: use directly with subset
df2 = augment_taxonomy(df)
subset(df2, :taxonomy_genus => taxon_occursin("Canis"))
subset(df2, :taxonomy_clades => taxon_occursin(r"Borophaginae"))

# 1-arg: regex AND on composite column (default combine=all)
# rows where taxonomy_clades contains BOTH patterns
subset(df2, :taxonomy_clades => taxon_occursin([r"Canidae", r"lupus"]))

# 1-arg: regex OR
subset(df2, :taxonomy_clades => taxon_occursin([r"^Canis\b", r"^Vulpes\b"]; combine=any))

# 1-arg: string OR
subset(df2, :taxonomy_genus => taxon_occursin(["Canis", "Vulpes"]; combine=any))

# Chain with subset (Chain.jl)
using Chain
@chain df begin
    augment_taxonomy
    subset(:taxonomy_family   => taxon_occursin("Canidae"))
    subset(:taxonomy_clades   => taxon_occursin([r"Canis", r"lupus"]))
end
```

```@docs
PaleobiologyDB.Taxonomy.taxon_occursin
```

## Taxon occurrence search: contains_taxon

`contains_taxon` provides an alternative syntax to [`taxon_occursin`](@ref) with the DataFrame
as the first argument. It comes in the same two forms:

- **2-arg** `contains_taxon(df, pattern)` → `Vector{Bool}` — searches across all
  taxonomy columns; use for `df[mask, :]` filtering.
- **1-arg** `contains_taxon(pattern)` → `ByRow` predicate — for use directly with
  `subset(df, :col => contains_taxon(pattern))`.

By placing the DataFrame first, this function is more natural for statement chaining and
method calls where data flows from left to right.

All matching semantics, column selection, and keywords are identical to `taxon_occursin`.

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy: contains_taxon

df = pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")

# 2-arg: multi-column boolean mask (DataFrame first)
df[contains_taxon(df, "Canis"), :]
df[contains_taxon(df, r"^Canis\b"), :]

# 2-arg: AND — every name must appear in some column (default combine=all)
df[contains_taxon(df, ["Canis", "Mammalia"]), :]

# 2-arg: OR — any name matches any column
df[contains_taxon(df, ["Canis", "Vulpes"]; combine=any), :]

# 2-arg: AND patterns — each regex must match at least one column
df[contains_taxon(df, [r"Canidae", r"Canis"]), :]

# 1-arg: use directly with subset
df2 = augment_taxonomy(df)
subset(df2, :taxonomy_genus => contains_taxon("Canis"))
subset(df2, :taxonomy_clades => contains_taxon(r"Borophaginae"))

# 1-arg: regex AND on composite column (default combine=all)
# rows where taxonomy_clades contains BOTH patterns
subset(df2, :taxonomy_clades => contains_taxon([r"Canidae", r"lupus"]))

# 1-arg: regex OR
subset(df2, :taxonomy_clades => contains_taxon([r"^Canis\b", r"^Vulpes\b"]; combine=any))

# 1-arg: string OR
subset(df2, :taxonomy_genus => contains_taxon(["Canis", "Vulpes"]; combine=any))

# Chain with subset (Chain.jl)
using Chain
@chain df begin
    augment_taxonomy
    subset(:taxonomy_family   => contains_taxon("Canidae"))
    subset(:taxonomy_clades   => contains_taxon([r"Canidae", r"lupus"]))
end
```

```@docs
PaleobiologyDB.Taxonomy.contains_taxon
```

## Choosing between taxon_occursin and contains_taxon

Both `taxon_occursin` and `contains_taxon` are functionally identical and support all the same
patterns, keywords, and use cases. The choice is purely stylistic:

| Preference | Function | Usage |
|-----------|----------|--------|
| Pattern-first (functional style) | `taxon_occursin` | `df[taxon_occursin("Canis", df), :]` |
| DataFrame-first (method chaining style) | `contains_taxon` | `df[contains_taxon(df, "Canis"), :]` |

Use whichever feels more natural for your workflow. Both are equally idiomatic and supported.

## PhyloPic silhouette images

`acquire_phylopic` and `augment_phylopic` resolve PBDB taxon names to
[PhyloPic](https://www.phylopic.org/) silhouette image metadata using the
PhyloPic `/resolve/paleobiodb.org/txn` API endpoint.

### How it works

For each taxon name the following steps are performed automatically:

1. **PBDB lookup** — `pbdb_taxon(name = X)` retrieves the taxon's numeric ID (`orig_no`).
2. **Lineage** — `pbdb_taxa(id = "txn:N", rel = "all_parents")` fetches the full ancestor chain.
3. **PhyloPic resolve** — the lineage IDs are sent to
   `https://api.phylopic.org/resolve/paleobiodb.org/txn`, which returns the UUID of the
   closest-matching node in PhyloPic's taxonomy.
4. **Image metadata** — the node's primary image is fetched with all file links, licence, and attribution.

The current PhyloPic build number is cached in memory for one hour to avoid unnecessary round-trips.

When processing a DataFrame, each *unique* taxon name triggers exactly one set of API calls;
duplicate names reuse the cached result.  If a taxon cannot be found in PBDB or PhyloPic, all
fields for that row are `missing` — no error is raised.

### Output fields

Both functions produce the following fields.  The `fieldname_prefix` argument (default
`"phylopic_"`) is prepended to every base name:

| Base name       | Column (default prefix) | Content                                   |
|-----------------|-------------------------|-------------------------------------------|
| `pbdb_taxon_id` | `phylopic_pbdb_taxon_id`| PBDB `orig_no` of the query taxon         |
| `pbdb_lineage`  | `phylopic_pbdb_lineage` | Comma-separated lineage `orig_no` values  |
| `node_uuid`     | `phylopic_node_uuid`    | Matched PhyloPic node UUID                |
| `matched_name`  | `phylopic_matched_name` | Name of the matched PhyloPic node         |
| `uuid`          | `phylopic_uuid`         | Image UUID                                |
| `thumbnail`     | `phylopic_thumbnail`    | URL to the largest thumbnail PNG          |
| `vector`        | `phylopic_vector`       | URL to the vector SVG                     |
| `raster`        | `phylopic_raster`       | URL to the largest raster PNG             |
| `source_file`   | `phylopic_source_file`  | URL to the original uploaded file         |
| `og_image`      | `phylopic_og_image`     | URL to the OG social-media preview image  |
| `license`       | `phylopic_license`      | Licence identifier (e.g. `"CC BY 4.0"`)  |
| `license_url`   | `phylopic_license_url`  | Full licence URL                          |
| `contributor`   | `phylopic_contributor`  | Contributor resource href                 |
| `attribution`   | `phylopic_attribution`  | Attribution text                          |

### acquire_phylopic — single taxon

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy

# Default prefix → :phylopic_uuid, :phylopic_thumbnail, etc.
rec = acquire_phylopic("Tyrannosaurus")
rec.phylopic_thumbnail    # → "https://images.phylopic.org/…/thumbnail/…"
rec.phylopic_vector       # → SVG URL
rec.phylopic_license      # → "CC BY 4.0"
rec.phylopic_attribution  # → "Matt Martyniuk"
rec.phylopic_pbdb_taxon_id  # → 56230 (orig_no)

# Taxon not found in PBDB or PhyloPic → all fields missing
rec_missing = acquire_phylopic("UNKNOWN_TAXON_XYZ")
ismissing(rec_missing.phylopic_uuid)  # → true
```

### acquire_phylopic — DataFrame (phylopic columns only)

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy, DataFrames

df   = pbdb_occurrences(base_name = "Ceratopsia", interval = "Cretaceous", show = "full")

# Returns a new DataFrame with ONLY the 14 phylopic columns (nrow(df) rows)
pics = acquire_phylopic(df)
pics.phylopic_thumbnail   # vector of URL strings / missings

# Custom taxon column (default is :accepted_name)
pics_genus = acquire_phylopic(df, :genus)
```

The returned DataFrame contains only the PhyloPic columns.  Combine it with the
original using `hcat` or use [`augment_phylopic`](@ref) for the one-call convenience:

```julia
enriched = hcat(df, pics)
```

### augment_phylopic — enriched DataFrame

```julia
# Returns a copy of df with all original columns plus the 14 phylopic columns
enriched = augment_phylopic(df)

ncol(enriched) == ncol(df) + 14  # true
hasproperty(enriched, :accepted_name)   # original columns preserved
hasproperty(enriched, :phylopic_uuid)   # phylopic columns added
```

### Multi-level enrichment with custom prefixes

Because the `fieldname_prefix` argument completely controls the output column names,
you can acquire images at multiple taxonomic levels simultaneously without column-name
conflicts:

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy, DataFrames

df = pbdb_occurrences(base_name = "Dinosauria", interval = "Cretaceous",
                      show = "full", limit = 100)

# Silhouettes matched at genus level
genus_pics = acquire_phylopic(df, :genus, "genus_phylopic_")
# → columns :genus_phylopic_uuid, :genus_phylopic_thumbnail, …

# Silhouettes matched at species level
sp_pics = acquire_phylopic(df, :accepted_name, "sp_phylopic_")
# → columns :sp_phylopic_uuid, :sp_phylopic_thumbnail, …

# Combine everything
full = hcat(df, genus_pics, sp_pics)

# Compare: genus-level match vs. species-level match
full[!, [:accepted_name, :genus_phylopic_matched_name, :sp_phylopic_matched_name]]
```

This is especially useful when the species-level image is absent (returns `missing`)
but a genus- or family-level silhouette is available.

### Downloading and saving images

The functions return URLs as plain strings.  `Downloads` (a Julia standard
library, no installation required) is all you need to save files to disk:

```julia
using Downloads
using PaleobiologyDB, PaleobiologyDB.Taxonomy

rec = acquire_phylopic("Tyrannosaurus")

# Save to disk — no extra dependencies needed
Downloads.download(rec.phylopic_raster,    "tyrannosaurus.png")   # raster PNG
Downloads.download(rec.phylopic_vector,    "tyrannosaurus.svg")   # vector SVG
Downloads.download(rec.phylopic_thumbnail, "tyrannosaurus_thumb.png")
```

### Enhancing Makie plots with PhyloPic silhouettes

The `PaleobiologyDB.PhyloPicMakie` extension provides a high-level API for
overlaying PhyloPic silhouettes on existing Makie axes.  It activates
automatically when a Makie backend (e.g. `CairoMakie`) and `FileIO` are
loaded.

```
pkg> add CairoMakie FileIO PNGFiles
```

```julia
using PaleobiologyDB, PaleobiologyDB.PhyloPicMakie
using CairoMakie, FileIO

taxa      = ["Tyrannosaurus", "Triceratops", "Ankylosaurus",
             "Pachycephalosaurus", "Edmontosaurus"]
first_app = [68.0, 68.0, 70.0, 74.0, 76.0]
last_app  = [66.0, 66.0, 66.0, 66.0, 66.0]

fig = Figure(size = (800, 420))
ax  = Axis(fig[1, 1];
    xlabel = "Age (Ma)", xreversed = true,
    yticks = (1:length(taxa), taxa), yticklabelsize = 13,
)

for (i, (fa, la)) in enumerate(zip(first_app, last_app))
    lines!(ax, [fa, la], [i, i]; linewidth = 6, color = :gray30)
end

augment_phylopic_ranges!(
    ax, first_app, last_app, collect(1.0:length(taxa));
    taxon      = taxa,
    at         = :start,
    glyph_size = 0.38,
    placement  = :center,
)

xlims!(ax, 78, 64)
display(fig)
```

See the [PhyloPicMakie guide](../guide/phylopic_makie.md) and
[PhyloPicMakie API reference](phylopic_makie.md) for the full API, table-
oriented variants, and keyword-argument reference.

```@docs
PaleobiologyDB.Taxonomy.acquire_phylopic
PaleobiologyDB.Taxonomy.augment_phylopic
```

### list_phylopic_images — all images for a taxon

`acquire_phylopic` returns one representative image per taxon — the primary
image of the best-matching PhyloPic node.  `list_phylopic_images` does the
opposite: it pages through the PhyloPic `/images` endpoint and returns **every
image** available for the taxon's clade (or just the node, with `filter = :node`),
one row per image.

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy

# All images within the Carnivora clade (one row per image, hundreds of rows)
imgs = list_phylopic_images("Carnivora")

nrow(imgs)                   # total number of PhyloPic images for Carnivora
ncol(imgs)                   # 12 — see column reference below
imgs.phylopic_uuid[1:5]      # image UUIDs
imgs.phylopic_raster[1:5]    # raster PNG URLs (largest available size)
imgs.phylopic_thumbnail[1:5] # thumbnail PNG URLs

# context columns — same for every row in a single call
imgs.phylopic_query_taxon_name[1]  # → "Carnivora"
imgs.phylopic_query_node_uuid[1]   # → PhyloPic node UUID for Carnivora

# Images tagged to exactly the Carnivora node only (no descendants)
imgs_node = list_phylopic_images("Carnivora"; filter = :node)

# Fetch only the first page (~30 images) for a quick preview
imgs_quick = list_phylopic_images("Carnivora"; max_pages = 1)

# Custom column prefix
imgs_dog = list_phylopic_images("Canis", "dog_")
imgs_dog.dog_uuid
imgs_dog.dog_raster

# Unknown or unresolvable taxon → empty DataFrame with correct columns
result = list_phylopic_images("NOT_A_REAL_TAXON_XYZ")
nrow(result)   # → 0
ncol(result)   # → 12
```

#### Output columns

With the default prefix `"phylopic_"`:

| Base name            | Column (default prefix)          | Content                                         |
|----------------------|----------------------------------|-------------------------------------------------|
| `query_taxon_name`   | `phylopic_query_taxon_name`      | Input taxon name                                |
| `query_node_uuid`    | `phylopic_query_node_uuid`       | PhyloPic node UUID resolved for the query taxon |
| `uuid`               | `phylopic_uuid`                  | Image UUID                                      |
| `thumbnail`          | `phylopic_thumbnail`             | URL of the largest thumbnail PNG                |
| `vector`             | `phylopic_vector`                | URL of the vector SVG                           |
| `raster`             | `phylopic_raster`                | URL of the largest raster PNG                   |
| `source_file`        | `phylopic_source_file`           | URL of the original source file                 |
| `og_image`           | `phylopic_og_image`              | URL of the OG social-media preview image        |
| `license`            | `phylopic_license`               | Licence identifier (e.g. `"CC BY 4.0"`)         |
| `license_url`        | `phylopic_license_url`           | Full licence URL                                |
| `contributor`        | `phylopic_contributor`           | Contributor resource href                       |
| `attribution`        | `phylopic_attribution`           | Attribution text                                |

#### Choosing between acquire_phylopic and list_phylopic_images

| Need | Function |
|------|---------|
| One silhouette per taxon for a plot or DataFrame column | `acquire_phylopic` / `augment_phylopic` |
| Browse or enumerate all images for a taxon (image gallery, selection UI) | `list_phylopic_images` |
| Download all raster files for a clade for offline use | `list_phylopic_images` + `Downloads.download` |

```@docs
PaleobiologyDB.Taxonomy.list_phylopic_images
```

## Local data store management

The `Depot` module manages the Scratch-backed local snapshots used by the
taxonomy validation functions. Access via the full namespace:

```julia
using PaleobiologyDB.Depot

# List all registered stores and their status
PaleobiologyDB.Depot.list()

# Metadata for a specific store
PaleobiologyDB.Depot.info(:pbdb_taxa)

# Force re-download of a snapshot
PaleobiologyDB.Depot.refresh!(:pbdb_taxa)

# Delete the local snapshot (will be re-downloaded on next use)
PaleobiologyDB.Depot.delete!(:pbdb_taxa)
```

```@docs
PaleobiologyDB.Depot
```
