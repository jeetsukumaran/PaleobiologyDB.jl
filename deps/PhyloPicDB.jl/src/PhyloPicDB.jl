"""
    PhyloPicDB

A Julia client for the [PhyloPic](https://www.phylopic.org/) API (v2).

PhyloPic is an open database of freely reusable silhouette images of
organisms, searchable by phylogeny.  This package provides typed structs
([`PhyloPicNode`](@ref), [`PhyloPicImage`](@ref)), low-level API wrappers,
a high-level image-selection layer, and batch-fetch utilities with built-in
deduplication and DataCaches-based caching.

## Quick start

```julia
using PhyloPicDB

# Resolve a PBDB lineage to a PhyloPic node UUID
uuid = resolve_pbdb_node([133360, 133359, 39168, 37177])

# Fetch the node
node = fetch_node(uuid)
println(node.preferred_name)

# Get the primary image (one request)
img = primary_image(uuid)
println(img.thumbnail_url)

# Get all clade images (paginated)
imgs = clade_images(uuid; max_pages = 2)
length(imgs)

# Select the third image (or nothing if fewer than 3 exist)
chosen = select_image(imgs, 3)

# Batch fetch for multiple nodes
result = batch_primary_images([uuid, uuid])  # deduplicates to 1 request
```

## Build management

All API functions accept an optional `build` keyword argument.  Pass
`nothing` (the default) to fetch the current build automatically.  Pass an
explicit `Int` to pin the build and avoid redundant network requests when
making many calls in a tight loop:

```julia
b    = fetch_current_build()
node = fetch_node(uuid; build = b)
imgs = clade_images(uuid; build = b)
```

## Image ordering stability

Within a single PhyloPic build, image ordering for a given node is
deterministic.  Integer-index selection via [`select_image`](@ref) therefore
returns the same image on every call within a session (assuming the build
does not change).
"""
module PhyloPicDB

using HTTP
using JSON3
import DataCaches: autocache

include("_types.jl")
include("_http.jl")
include("_build.jl")
include("_api_nodes.jl")
include("_api_images.jl")
include("_api_resolve.jl")
include("_image_selector.jl")
include("_bulk.jl")

export PhyloPicNode
export PhyloPicImage

export PHYLOPIC_BASE_URL
export BUILD_TTL

export fetch_current_build
export ensure_build

export fetch_node
export fetch_node_with_primary_image

export fetch_image
export fetch_images

export resolve_node
export resolve_pbdb_node

export primary_image
export clade_images
export node_images
export select_image
export with_node_names

export batch_primary_images
export batch_images

export PHYLOPIC_IMAGE_RENDERINGS
export PHYLOPIC_IMAGE_ALL_LABEL_FIELDS
export PHYLOPIC_IMAGE_BASIC_LABEL_FIELDS

end # module PhyloPicDB
