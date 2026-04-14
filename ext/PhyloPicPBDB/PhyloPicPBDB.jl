"""
    PaleobiologyDB.PhyloPicPBDB

Makie + FileIO extension providing PBDB-specific PhyloPic silhouette overlay
functions for [`PaleobiologyDB`](@ref).

Activates automatically when both `Makie` (or any backend such as `CairoMakie`)
and `FileIO` are loaded in the same Julia session as `PaleobiologyDB`.

This module is a **thin PBDB name-resolution bridge**: it resolves taxon names
via [`PaleobiologyDB.Taxonomy.acquire_phylopic`](@ref) (and
`PaleobiologyDB.Taxonomy.phylopic_node` / `phylopic_images`) to image data,
then delegates all generic image download, coordinate geometry, rendering, grid
layout, and label building to `PhyloPicDB.PhyloPicMakie`.

The split is at the PBDB boundary: any function that requires PaleobiologyDB
taxonomy knowledge lives here; everything that works with pre-resolved
`PhyloPicDB.PhyloPicImage` objects or raw image matrices lives in
`PhyloPicDB.PhyloPicMakie`.

## Activation

```julia
using PaleobiologyDB
using CairoMakie   # or GLMakie, WGLMakie, …
using FileIO       # required for PNG decoding
# → PaleobiologyDB.PhyloPicPBDB is now available
```

## Quick start

```julia
using PaleobiologyDB, PaleobiologyDB.PhyloPicPBDB
using CairoMakie, FileIO

fig = Figure()
ax  = Axis(fig[1, 1]; xreversed = true,
           yticks = (1:5, ["Tyrannosaurus", "Triceratops",
                           "Ankylosaurus", "Pachycephalosaurus", "Edmontosaurus"]))

# Draw range bars manually, then add silhouettes at first appearance
augment_phylopic_ranges!(
    ax,
    [68.0, 68.0, 70.0, 74.0, 76.0],   # first appearances (Ma)
    [66.0, 66.0, 66.0, 66.0, 66.0],   # last appearances (Ma)
    collect(1.0:5.0);
    taxon     = ["Tyrannosaurus", "Triceratops",
                 "Ankylosaurus", "Pachycephalosaurus", "Edmontosaurus"],
    at        = :start,
    glyph_size = 0.4,
)
```

## Public API

| Function | Description |
|---|---|
| [`augment_phylopic!`](@ref) | Add glyphs at explicit (x, y) coordinates |
| [`augment_phylopic`](@ref) | Non-bang alias for `augment_phylopic!` |
| [`augment_phylopic_ranges!`](@ref) | Add glyphs anchored to range data |
| [`augment_phylopic_ranges`](@ref) | Non-bang alias for `augment_phylopic_ranges!` |
| [`phylopic_thumbnail_grid!`](@ref) | Draw a thumbnail gallery into an existing axis |
| [`phylopic_thumbnail_grid`](@ref) | Create a new figure containing a thumbnail gallery |

Both functions have vector-based and table-based signatures.

## Image caching

Downloaded silhouette images are automatically cached via the same
`DataCaches.jl` infrastructure used by the rest of the package.  Each unique
thumbnail URL is downloaded at most once per cache lifetime.  The cache can
be controlled via the standard `PaleobiologyDB.set_autocaching!` mechanism.
"""
module PhyloPicPBDB

import Makie
import FileIO
import DataCaches: autocache
using Makie: RGBA, N0f8, Colorant

using PaleobiologyDB
import PhyloPicDB

export augment_phylopic!
export augment_phylopic
export augment_phylopic_ranges!
export augment_phylopic_ranges
export phylopic_thumbnail_grid!
export phylopic_thumbnail_grid

include("_resolve.jl")
include("_render.jl")
include("_phylopic_thumbnail_grid.jl")

function __init__()
    # Bind this extension module to PaleobiologyDB.PhyloPicPBDB so that
    # callers can access it as PaleobiologyDB.PhyloPicPBDB after the extension
    # has been triggered.  Julia 1.9+ extensions are loaded as top-level
    # modules and are not automatically installed as submodule bindings in the
    # parent package.
    #
    # Guard against incremental precompilation: during precompilation of another
    # extension that also triggers on Makie (e.g. TaxonTreeMakie), Julia 1.12+
    # restores cached modules and re-runs their __init__ functions.  Calling
    # Core.eval into PaleobiologyDB at that point breaks incremental compilation
    # because the parent module is "closed".  The guard below ensures the eval
    # only runs at actual runtime, not during precompilation.
    if ccall(:jl_generating_output, Cint, ()) == 0
        Core.eval(PaleobiologyDB, :(const PhyloPicPBDB = $(@__MODULE__)))
    end
end

end # module PhyloPicPBDB
