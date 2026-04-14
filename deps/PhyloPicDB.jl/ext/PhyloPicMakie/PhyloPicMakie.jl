"""
    PhyloPicDB.PhyloPicMakie

Makie + FileIO extension providing image-loading, rendering, and
PhyloPic-native visualization utilities for
[PhyloPic](https://www.phylopic.org/) silhouette images.

Activates automatically when both `Makie` (or any backend such as
`CairoMakie`) and `FileIO` are loaded in the same Julia session as
`PhyloPicDB`.

## What this module provides

This module is the complete **PhyloPic visualization layer**: downloading,
decoding, caching, coordinate geometry, axis scale correction, the core
`Makie.image!` rendering loop, thumbnail grid rendering, and the
**PhyloPic-native public API** keyed on node UUIDs.  It has no dependency
on `PaleobiologyDB`.

PBDB taxon-name resolution (mapping PBDB names → PhyloPic node UUIDs)
lives in `PaleobiologyDB.PhyloPicPBDB`, which delegates here after
performing that mapping.

## Public API

These functions are exported and accept PhyloPic node UUIDs as the primary
image-source identifier.

### Glyph overlay

| Function | Description |
|---|---|
| `augment_phylopic!(ax, xs, ys; node_uuid, ...)` | Add one glyph per datum at explicit `(x, y)` coordinates |
| `augment_phylopic(ax, xs, ys; node_uuid, ...)` | Non-bang alias |
| `augment_phylopic!(ax, xs, ys, images; ...)` | Low-level: render pre-resolved image matrices |
| `augment_phylopic_ranges!(ax, xstart, xstop, y; node_uuid, ...)` | Glyphs anchored to range endpoints |
| `augment_phylopic_ranges(ax, xstart, xstop, y; node_uuid, ...)` | Non-bang alias |
| `augment_phylopic!(ax, table; x, y, node_uuid, ...)` | Table-oriented variant |
| `augment_phylopic_ranges!(ax, table; xstart, xstop, y, node_uuid, ...)` | Table range variant |

All vector-API variants also accept a pre-loaded `glyph::AbstractMatrix`
instead of `node_uuid`.

### Thumbnail gallery

| Function | Description |
|---|---|
| `phylopic_thumbnail_grid!(ax, node_uuids; ...)` | Gallery in an existing axis |
| `phylopic_thumbnail_grid(node_uuids; ...)` | Factory: creates `Figure` + `Axis` |
| `phylopic_thumbnail_grid!(ax, images, labels, group_sizes; ...)` | Low-level: pre-built cell data |
| `phylopic_thumbnail_grid(images, labels, group_sizes; ...)` | Low-level factory |

Single-UUID and table-oriented variants are also available for all functions
above.

## Internal helpers

The following symbols are `_`-prefixed and intended for use by sibling
extensions (`PaleobiologyDB.PhyloPicPBDB`, `TaxonTreeMakie`):

| Symbol | Description |
|---|---|
| `_load_phylopic_image(url)` | Download + decode + cache a PNG image |
| `_resolve_images_by_uuid(uuids, glyph, n; ...)` | UUID vector → image matrix vector |
| `_compute_image_bbox(x, y, w, h; ...)` | Data-space bounding box with scale correction |
| `_axis_scale_correction_obs(scene)` | Reactive `(ypx/unit) / (xpx/unit)` correction |
| `_apply_rotation(img, deg)` | Rotate image matrix by multiples of 90° |
| `_range_anchor(xstart, xstop, at)` | Resolve range endpoint to an x coordinate |
| `_extract_column(table, selector)` | Generic table-column extractor |
| `_fetch_node_image_pool(uuid, filter, pages)` | Fetch image pool for one PhyloPic node |
| `_build_node_grid_cells(uuids, labels, ...)` | Build flat cell data for grid rendering |
| `_apply_image_selector(pool, selector)` | Select images from a `PhyloPicImage` pool |
| `_select_image_url(img, rendering)` | Extract URL from `PhyloPicImage` by rendering symbol |
| `_download_image(img, label; rendering)` | Download and decode one `PhyloPicImage` |
| `_build_label(name, k, multi, img, label, sep)` | Build the display label for a grid cell |
"""
module PhyloPicMakie

import Makie
import FileIO
import Downloads
import DataCaches: autocache
using Makie: RGBA, N0f8, Colorant

import PhyloPicDB

# Public PhyloPic-native API
export augment_phylopic!
export augment_phylopic
export augment_phylopic_ranges!
export augment_phylopic_ranges
export phylopic_thumbnail_grid!
export phylopic_thumbnail_grid

include("_image_cache.jl")
include("_coordinates.jl")
include("_render_core.jl")
include("_thumbnail_grid.jl")
include("_glyph_resolution.jl")
include("_augment_api.jl")
include("_node_thumbnail_grid.jl")

function __init__()
    # Bind this extension module to PhyloPicDB.PhyloPicMakie so that callers
    # can access it as PhyloPicDB.PhyloPicMakie after extension load.  Julia
    # 1.9+ extensions are top-level modules and are not automatically installed
    # as submodule bindings in the parent package.
    #
    # Guard against incremental precompilation: during precompilation of another
    # extension that also triggers on Makie + FileIO, Julia 1.12+ restores
    # cached modules and re-runs __init__ functions.  The guard ensures the eval
    # only runs at actual runtime, not during precompilation.
    if ccall(:jl_generating_output, Cint, ()) == 0
        Core.eval(PhyloPicDB, :(const PhyloPicMakie = $(@__MODULE__)))
    end
end

end # module PhyloPicMakie
