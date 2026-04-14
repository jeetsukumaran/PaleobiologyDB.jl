"""
    PhyloPicDB.PhyloPicMakie

Makie + FileIO extension providing image-loading and rendering utilities for
[PhyloPic](https://www.phylopic.org/) silhouette images.

Activates automatically when both `Makie` (or any backend such as `CairoMakie`)
and `FileIO` are loaded in the same Julia session as `PhyloPicDB`.

## What this module provides

This module is the **image utilities layer**: downloading, decoding, caching,
coordinate geometry, axis scale correction, and the core `Makie.image!` rendering
loop.  It has no dependency on `PaleobiologyDB`.

Higher-level functionality that requires PBDB taxon-name resolution (e.g.
`augment_phylopic!` with `taxon = [...]`) lives in
`PaleobiologyDB.PhyloPicPBDB`, which loads on top of this module.

## Internal API

All symbols are `_`-prefixed and intended for use by other extensions, not
directly by end users.

| Symbol | Description |
|---|---|
| `_load_phylopic_image(url)` | Download + decode + cache a PNG image |
| `_compute_image_bbox(x, y, w, h; ...)` | Data-space bounding box with optional axis scale correction |
| `_axis_scale_correction_obs(scene)` | Reactive `(ypx/unit) / (xpx/unit)` correction factor |
| `_apply_rotation(img, deg)` | Rotate image matrix by multiples of 90° |
| `_range_anchor(xstart, xstop, at)` | Resolve range endpoint to an x coordinate |
| `_augment_phylopic_core!(ax, xs, ys, images; ...)` | Core rendering loop (pre-resolved images → `Makie.image!`) |
"""
module PhyloPicMakie

import Makie
import FileIO
import Downloads
import DataCaches: autocache
using Makie: RGBA, N0f8, Colorant

import PhyloPicDB

# No exports — all symbols are _-prefixed internal helpers consumed by
# PaleobiologyDB extensions and TaxonTreeMakie.

include("_image_cache.jl")
include("_coordinates.jl")
include("_render_core.jl")

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
