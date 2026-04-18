```@meta
CurrentModule = PaleobiologyDB.TaxonomyMakie
```

# PhyloPic — Acquisition

`acquire_phylopic` and `augment_phylopic` resolve PBDB taxon names to
[PhyloPic](https://www.phylopic.org/) silhouette image metadata using the
PhyloPic `/resolve/paleobiodb.org/txn` API endpoint.

## How it works

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

## Output fields

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

## acquire_phylopic — single taxon

```julia
using PaleobiologyDB, PaleobiologyDB.TaxonomyMakie

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

## acquire_phylopic — DataFrame (phylopic columns only)

```julia
using PaleobiologyDB, PaleobiologyDB.TaxonomyMakie, DataFrames

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

## augment_phylopic — enriched DataFrame

```julia
# Returns a copy of df with all original columns plus the 14 phylopic columns
enriched = augment_phylopic(df)

ncol(enriched) == ncol(df) + 14  # true
hasproperty(enriched, :accepted_name)   # original columns preserved
hasproperty(enriched, :phylopic_uuid)   # phylopic columns added
```

## Multi-level enrichment with custom prefixes

Because the `fieldname_prefix` argument completely controls the output column names,
you can acquire images at multiple taxonomic levels simultaneously without column-name
conflicts:

```julia
using PaleobiologyDB, PaleobiologyDB.TaxonomyMakie, DataFrames

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

## Downloading and saving images

The functions return URLs as plain strings.  `Downloads` (a Julia standard
library, no installation required) is all you need to save files to disk:

```julia
using Downloads
using PaleobiologyDB, PaleobiologyDB.TaxonomyMakie

rec = acquire_phylopic("Tyrannosaurus")

# Save to disk — no extra dependencies needed
Downloads.download(rec.phylopic_raster,    "tyrannosaurus.png")   # raster PNG
Downloads.download(rec.phylopic_vector,    "tyrannosaurus.svg")   # vector SVG
Downloads.download(rec.phylopic_thumbnail, "tyrannosaurus_thumb.png")
```

## Enhancing Makie plots with PhyloPic silhouettes

The `PaleobiologyDB.TaxonomyMakie` extension provides a high-level API for
overlaying PhyloPic silhouettes on existing Makie axes.  It activates
when both a Makie backend (e.g. `CairoMakie`) and `PhyloPicMakie` are loaded.

```
pkg> add CairoMakie PhyloPicMakie
```

```julia
using PaleobiologyDB
import PhyloPicMakie
using CairoMakie
using PaleobiologyDB.TaxonomyMakie

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

See the [PhyloPic rendering guide](../guide/phylopic_makie.md) and
[PhyloPic: Rendering API reference](phylopic_makie.md) for the full API, table-
oriented variants, and keyword-argument reference.

```@docs
acquire_phylopic
```

## phylopic_images_dataframe — all images for a taxon

`acquire_phylopic` returns one representative image per taxon — the primary
image of the best-matching PhyloPic node.  `phylopic_images_dataframe` does the
opposite: it pages through the PhyloPic `/images` endpoint and returns **every
image** available for the taxon's clade (or just the node, with `filter = :node`),
one row per image.

```julia
using PaleobiologyDB, PaleobiologyDB.TaxonomyMakie

# All images within the Carnivora clade (one row per image, hundreds of rows)
imgs = phylopic_images_dataframe("Carnivora")

nrow(imgs)                   # total number of PhyloPic images for Carnivora
ncol(imgs)                   # 12 — see column reference below
imgs.phylopic_uuid[1:5]      # image UUIDs
imgs.phylopic_raster[1:5]    # raster PNG URLs (largest available size)
imgs.phylopic_thumbnail[1:5] # thumbnail PNG URLs

# context columns — same for every row in a single call
imgs.phylopic_query_taxon_name[1]  # → "Carnivora"
imgs.phylopic_query_node_uuid[1]   # → PhyloPic node UUID for Carnivora

# Images tagged to exactly the Carnivora node only (no descendants)
imgs_node = phylopic_images_dataframe("Carnivora"; filter = :node)

# Fetch only the first page (~30 images) for a quick preview
imgs_quick = phylopic_images_dataframe("Carnivora"; max_pages = 1)

# Custom column prefix
imgs_dog = phylopic_images_dataframe("Canis", "dog_")
imgs_dog.dog_uuid
imgs_dog.dog_raster

# Unknown or unresolvable taxon → empty DataFrame with correct columns
result = phylopic_images_dataframe("NOT_A_REAL_TAXON_XYZ")
nrow(result)   # → 0
ncol(result)   # → 12
```

### Output columns

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

### Choosing between acquire_phylopic and phylopic_images_dataframe

| Need | Function |
|------|---------|
| One silhouette per taxon for a plot or DataFrame column | `acquire_phylopic` / `augment_phylopic` |
| Browse or enumerate all images for a taxon (image gallery, selection UI) | `phylopic_images_dataframe` |
| Download all raster files for a clade for offline use | `phylopic_images_dataframe` + `Downloads.download` |

```@docs
phylopic_images_dataframe
```

## phylopic_node and phylopic_images

```@docs
phylopic_node
phylopic_images
```
