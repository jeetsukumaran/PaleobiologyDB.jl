# PhyloPicDB.jl

[![Build Status](https://github.com/jeetsukumaran/PhyloPicDB.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jeetsukumaran/PhyloPicDB.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
[![License: LGPL v3](https://img.shields.io/badge/License-LGPL_v3-blue.svg)](https://www.gnu.org/licenses/lgpl-3.0)
[![Julia 1.10+](https://img.shields.io/badge/Julia-1.10%2B-blueviolet)](https://julialang.org)

A Julia client for the [PhyloPic](https://www.phylopic.org) silhouette image API, providing typed structs, transparent caching, paginated image lists, and batch deduplication.

## Features

- **Typed results** — `PhyloPicNode` and `PhyloPicImage` structs with documented fields; no raw JSON dictionaries.
- **Two-stage pipeline** — resolve a node once, then retrieve images independently; each stage is separately cached.
- **Automatic caching** — build numbers, nodes, and images are cached in memory (TTL-guarded) via [DataCaches.jl](https://github.com/JuliaData/DataCaches.jl); repeat calls are free.
- **Paginated image lists** — `clade_images` and `node_images` page through `/images` automatically; limit with `max_pages`.
- **Batch deduplication** — `batch_primary_images` / `batch_images` deduplicate UUIDs so each unique node triggers at most one API call.
- **Composable image selection** — `select_image` accepts a symbol (`:first`), an integer index, or any callable, and returns `nothing` on out-of-bounds rather than throwing.
- **PBDB convenience** — `resolve_pbdb_node` maps a Paleobiology Database lineage ID list directly to a PhyloPic node UUID.

## Installation

PhyloPicDB.jl is not yet registered in the General registry.
Add it as a URL dependency:

```julia
using Pkg
Pkg.add(url = "https://github.com/jeetsukumaran/PhyloPicDB.jl")
```

Or, within a project that already lists it as a path/source dependency, it is available immediately after `using PaleobiologyDB` (or whichever parent package declares the source dep).

## Quick start

```julia
using PhyloPicDB

# --- 1. Resolve an external identifier to a PhyloPic node UUID ---------------

# From a Paleobiology Database lineage (most-derived taxon first):
uuid = resolve_pbdb_node([133360, 133359, 39168, 37177])
# => "some-uuid-string"   (or nothing if no match)

# Generic resolver for other authorities:
uuid = resolve_node("paleobiodb.org", "txn", ["133360", "133359"])

# --- 2. Fetch the node -------------------------------------------------------

node = fetch_node(uuid)
println(node.preferred_name)   # "Tyrannosaurus"
println(node.all_names)        # ["Tyrannosaurus", "Tyrannosaurus rex", ...]
println(node.uuid)             # same as `uuid`

# --- 3. Retrieve images ------------------------------------------------------

# Primary image — one round trip, one result:
img = primary_image(uuid)
println(img.thumbnail_url)     # "https://images.phylopic.org/images/.../thumbnail/..."
println(img.license)           # "CC BY 3.0"

# All images for the clade (paginated):
imgs = clade_images(uuid; max_pages = 2)
println(length(imgs))          # however many were returned

# Images tagged to exactly this node (not descendants):
mine = node_images(uuid)

# --- 4. Select from a list ---------------------------------------------------

first_img  = select_image(imgs, :first)   # first element or nothing
third_img  = select_image(imgs, 3)        # element at index 3, or nothing if OOB
chosen_img = select_image(imgs, imgs -> first(filter(i -> !ismissing(i.vector_url), imgs), nothing))
```

## Typed structs

### `PhyloPicNode`

Returned by `fetch_node`, `fetch_node_with_primary_image`, and `resolve_*` helpers.

| Field | Type | Description |
|---|---|---|
| `uuid` | `String` | Unique identifier for this node |
| `preferred_name` | `String` | Preferred taxonomic name |
| `all_names` | `Vector{String}` | All known names, preferred first |
| `build` | `Int` | PhyloPic build index when fetched |
| `parent_node_uuid` | `Union{String,Nothing}` | Parent node UUID, or `nothing` at root |
| `primary_image_uuid` | `Union{String,Nothing}` | Designated primary image UUID, or `nothing` |
| `clade_images_href` | `String` | Endpoint href for clade-image list |
| `images_href` | `String` | Endpoint href for node-image list |

### `PhyloPicImage`

Returned by all image-fetching functions.

| Field | Type | Description |
|---|---|---|
| `uuid` | `String` | Unique identifier for this image |
| `build` | `Int` | PhyloPic build index when fetched |
| `thumbnail_url` | `Union{String,Missing}` | Largest thumbnail PNG URL |
| `vector_url` | `Union{String,Missing}` | Vector SVG URL |
| `raster_url` | `Union{String,Missing}` | Largest raster PNG URL |
| `source_file_url` | `Union{String,Missing}` | Original upload URL |
| `og_image_url` | `Union{String,Missing}` | Open Graph preview PNG URL |
| `license_url` | `Union{String,Missing}` | Full license URI |
| `license` | `Union{String,Missing}` | Human-readable label, e.g. `"CC BY 4.0"` |
| `contributor_href` | `Union{String,Missing}` | Contributor resource href |
| `attribution` | `Union{String,Missing}` | Attribution text |
| `specific_node_uuid` | `Union{String,Nothing}` | Most-precise associated node UUID |
| `general_node_uuid` | `Union{String,Nothing}` | Most-inclusive associated node UUID |

## API reference

### Build management

```julia
# Current build number (cached; re-fetched after BUILD_TTL seconds = 1 hour):
build = fetch_current_build()

# Use a supplied build, or fetch current if nothing:
build = ensure_build(nothing)   # fetches
build = ensure_build(537)       # returns 537
```

Pass `build` explicitly to any function to pin all results to a specific snapshot:

```julia
node = fetch_node(uuid; build = 537)
imgs = clade_images(uuid; build = 537, max_pages = 3)
```

### Nodes

```julia
# Fetch one node by UUID:
node = fetch_node(uuid)                    # Union{PhyloPicNode, Nothing}

# Fetch node + primary image in one request:
node, img = fetch_node_with_primary_image(uuid)  # Tuple{..., ...}
```

### Images

```julia
# Fetch one image by UUID:
img = fetch_image(image_uuid)              # Union{PhyloPicImage, Nothing}

# Paginated list for a node:
imgs = fetch_images(node_uuid)                          # all pages, clade filter
imgs = fetch_images(node_uuid; filter = :node)          # only images at this node
imgs = fetch_images(node_uuid; max_pages = 1)           # first page only (~30 images)
```

### Resolve

```julia
# PBDB convenience (lineage IDs, most-derived first):
uuid = resolve_pbdb_node([133360, 133359, 39168, 37177])

# Generic resolver:
uuid = resolve_node("paleobiodb.org", "txn", ["133360", "133359"])
```

### Image selection

`select_image` is a pure function — no I/O, no network calls.

```julia
imgs = clade_images(uuid)

select_image(imgs, :first)       # first image, or nothing if empty
select_image(imgs, 3)            # imgs[3], or nothing if length(imgs) < 3
select_image(imgs, 0)            # nothing (out of bounds — no error, no fallback)
select_image(imgs, f)            # f(imgs) for any callable f
```

### Batch / bulk

Deduplicate a list of node UUIDs — each unique UUID triggers at most one API call,
and results are cached for future calls.

```julia
# Primary image per node:
result = batch_primary_images(uuids)
# => Dict{String, Union{PhyloPicImage, Nothing}}
img = result[uuid]

# Full image lists per node:
result = batch_images(uuids; filter = :clade, max_pages = 2)
# => Dict{String, Vector{PhyloPicImage}}
imgs = result[uuid]
```

## Complete worked example

```julia
using PhyloPicDB

# Resolve Carnivora from PBDB lineage IDs
carnivora_uuid = resolve_pbdb_node([41045, 40197, 37177])
isnothing(carnivora_uuid) && error("not found")

# Inspect the node
node = fetch_node(carnivora_uuid)
println("Node: $(node.preferred_name), primary image: $(node.primary_image_uuid)")

# Get the primary image (fastest — one request)
img = primary_image(carnivora_uuid)
if !isnothing(img)
    println("Primary image UUID:  $(img.uuid)")
    println("License:             $(img.license)")
    println("Thumbnail URL:       $(img.thumbnail_url)")
end

# Get all clade images, limited to 2 pages
imgs = clade_images(carnivora_uuid; max_pages = 2)
println("$(length(imgs)) clade images found")

# Pick the third image, falling back gracefully if fewer exist
chosen = select_image(imgs, 3)
isnothing(chosen) && println("fewer than 3 images available")

# Download the vector SVG for a chosen image
if !isnothing(chosen) && !ismissing(chosen.vector_url)
    import Downloads
    Downloads.download(chosen.vector_url, "carnivora.svg")
    println("saved carnivora.svg")
end

# Batch fetch for a list of taxa (deduplicates automatically)
uuids = [carnivora_uuid, node.primary_image_uuid]
primaries = batch_primary_images(filter(!isnothing, uuids))
for (u, i) in primaries
    println("$u → $(isnothing(i) ? "no image" : i.uuid)")
end
```

## Design notes

- **Pure core / effectful shell.** The JSON parsers (`_parse_node_json`, `_parse_image_json`) and `select_image` are pure functions with no I/O. All network calls are isolated to the `_http.jl` primitive (`phylopic_get`), which is the sole place that can fail with a network error.
- **Thread-safe build cache.** The build number is stored behind a `ReentrantLock` and refreshed at most once per `BUILD_TTL` seconds (one hour by default).
- **Automatic caching via DataCaches.** Nodes, images, and resolved UUIDs are keyed on `(uuid, build)` tuples so that switching build numbers naturally invalidates entries without manual cache management.
- **`nothing` vs `missing`.** Functions that query an external resource return `nothing` to signal "not found". Struct fields that represent an optional attribute of a resource use `missing`.

## License

Copyright (C) 2026 Jeet Sukumaran.
Released under the [GNU Lesser General Public License v3.0](LICENSE.md).
