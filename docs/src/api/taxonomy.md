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

PhyloPic thumbnails can be overlaid on Makie figures using `image!`.

The examples below require the following additional packages: 

```
pkg> add CairoMakie FileIO PNGFiles
```

The example below draws a stratigraphic range chart for a handful of Cretaceous
taxa and annotates each range bar with the taxon's silhouette.

```julia
using CairoMakie, FileIO, Downloads
using PaleobiologyDB, PaleobiologyDB.Taxonomy

# ── Data ──────────────────────────────────────────────────────────────────

taxa       = ["Tyrannosaurus", "Triceratops", "Ankylosaurus",
              "Pachycephalosaurus", "Edmontosaurus"]
first_app  = [68.0, 68.0, 70.0, 74.0, 76.0]   # first appearance (Ma)
last_app   = [66.0, 66.0, 66.0, 66.0, 66.0]   # last appearance (Ma)

# ── PhyloPic images ───────────────────────────────────────────────────────

pics = [acquire_phylopic(t) for t in taxa]

# ── Plot ──────────────────────────────────────────────────────────────────

fig = Figure(size = (800, 420))
ax  = Axis(fig[1, 1],
    xlabel          = "Age (Ma)",
    title           = "Latest Cretaceous taxa — stratigraphic ranges",
    yreversed       = false,
    xreversed       = true,          # geological convention: older on the right
    yticks          = (1:length(taxa), taxa),
    yticklabelsize  = 13,
)

img_half_height = 0.38   # vertical half-size of the image overlay

for (i, (fa, la, rec)) in enumerate(zip(first_app, last_app, pics))
    # Range bar
    lines!(ax, [fa, la], [i, i]; linewidth = 6, color = :gray30)

    # Overlay the thumbnail at the older end of the range
    if !ismissing(rec.phylopic_thumbnail)
        img = load(Downloads.download(rec.phylopic_thumbnail))
        w   = size(img, 2) / size(img, 1)   # aspect ratio
        dx  = img_half_height * w
        image!(ax,
            [fa - dx, fa + dx],               # x extent (Ma)
            [i - img_half_height, i + img_half_height],  # y extent
            rotr90(img);                       # Makie expects column-major
            interpolate = true,
        )
    end
end

xlims!(ax, 78, 64)
display(fig)
save("cretaceous_ranges.png", fig)
```

For a diversity bar chart, pass the full occurrence DataFrame through
`augment_phylopic` and load one thumbnail per bar (same package requirements:
`pkg> add CairoMakie FileIO PNGFiles`):

```julia
using CairoMakie, FileIO, Downloads, DataFrames
using PaleobiologyDB, PaleobiologyDB.Taxonomy

df = pbdb_occurrences(base_name = "Ceratopsia", interval = "Cretaceous",
                      show = "full", limit = 500)
df2 = augment_taxonomy(df)

# Occurrence counts per genus
counts = sort(
    combine(groupby(dropmissing(df2, :taxonomy_genus), :taxonomy_genus),
            nrow => :n),
    :n; rev = true
)
top = first(counts, 6)

# PhyloPic images for the top genera
pics = acquire_phylopic(
    DataFrame(g = top.taxonomy_genus), :g, "phylopic_"
)

fig = Figure(size = (700, 500))
ax  = Axis(fig[1, 1],
    xticks         = (1:nrow(top), top.taxonomy_genus),
    xticklabelrotation = π / 4,
    ylabel         = "Occurrence count",
    title          = "Most common Cretaceous ceratopsian genera",
)

for (i, (n, thumb)) in enumerate(zip(top.n, pics.phylopic_thumbnail))
    barplot!(ax, [i], [n]; color = (:steelblue, 0.7))
    if !ismissing(thumb)
        img = load(Downloads.download(thumb))
        w   = size(img, 2) / size(img, 1)
        h   = n * 0.25                        # image height = 25 % of bar
        image!(ax, [i - w * h / 2, i + w * h / 2], [n * 0.02, n * 0.02 + h],
               rotr90(img); interpolate = true)
    end
end

display(fig)
```

```@docs
PaleobiologyDB.Taxonomy.acquire_phylopic
PaleobiologyDB.Taxonomy.augment_phylopic
```

## Local data store management

The `Store` submodule manages the Scratch-backed local snapshots used by the
taxonomy validation functions. Access via the full namespace:

```julia
using PaleobiologyDB.Taxonomy

# List all registered stores and their status
PaleobiologyDB.Taxonomy.Store.list()

# Metadata for a specific store
PaleobiologyDB.Taxonomy.Store.info(:pbdb_taxa)

# Force re-download of a snapshot
PaleobiologyDB.Taxonomy.Store.refresh!(:pbdb_taxa)

# Delete the local snapshot (will be re-downloaded on next use)
PaleobiologyDB.Taxonomy.Store.delete!(:pbdb_taxa)
```

```@docs
PaleobiologyDB.Taxonomy.Store
```
