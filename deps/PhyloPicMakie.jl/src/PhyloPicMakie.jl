"""
    PhyloPicMakie

Standalone Makie + FileIO package providing image-loading, rendering, and
PhyloPic-native visualization utilities for
[PhyloPic](https://www.phylopic.org/) silhouette images.

`PhyloPicMakie.PhyloPicDB` exposes the underlying
[PhyloPicDB](https://github.com/jeetsukumaran/PhyloPicDB.jl) data/API module,
giving the caller a single `using PhyloPicMakie` entry point that covers both
the visualization layer and the underlying PhyloPic API client.

## Namespace hierarchy

```
PhyloPicMakie                  ← this module (Makie + image rendering)
PhyloPicMakie.PhyloPicDB       ← the PhyloPicDB data-access module
```

## Public API

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

Single-UUID and table-oriented variants are also available for all functions above.

## Internal helpers

The following symbols are `_`-prefixed and intended for use by packages that
integrate with PhyloPicMakie (e.g. `PaleobiologyDB.PhyloPicPBDB`,
`TaxonTreeMakie`):

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

include("PhyloPicDB/PhyloPicDB.jl")
import .PhyloPicDB

import Makie
import FileIO
import Downloads
import DataCaches: autocache
using Makie: RGBA, N0f8, Colorant

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

end # module PhyloPicMakie
