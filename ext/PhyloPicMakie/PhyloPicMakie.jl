"""
    PaleobiologyDB.PhyloPicMakie

Makie extension for [`PaleobiologyDB`](@ref).

Provides functions to overlay [PhyloPic](https://www.phylopic.org/) silhouette
images on existing Makie axes.  The extension is automatically loaded when
both `Makie` (or any Makie backend such as `CairoMakie` or `GLMakie`) and
`FileIO` are loaded in the same Julia session.

## Activation

```julia
using PaleobiologyDB
using CairoMakie   # or GLMakie, WGLMakie, …
using FileIO       # required for PNG decoding
# → PaleobiologyDB.PhyloPicMakie is now available
```

## Quick start

```julia
using PaleobiologyDB, PaleobiologyDB.PhyloPicMakie
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

Both functions have vector-based and table-based signatures.

## Image caching

Downloaded silhouette images are automatically cached via the same
`DataCaches.jl` infrastructure used by the rest of the package.  Each unique
thumbnail URL is downloaded at most once per cache lifetime.  The cache can
be controlled via the standard `PaleobiologyDB.set_autocaching!` mechanism.
"""
module PhyloPicMakie

import Makie
import FileIO
import Downloads
import DataCaches: autocache
using Makie: RGBA, N0f8, Colorant

using PaleobiologyDB

export augment_phylopic!
export augment_phylopic
export augment_phylopic_ranges!
export augment_phylopic_ranges

include("_image_cache.jl")
include("_coordinates.jl")
include("_render.jl")

function __init__()
    # Bind this extension module to PaleobiologyDB.PhyloPicMakie so that
    # callers can access it as PaleobiologyDB.PhyloPicMakie after the extension
    # has been triggered.  This is necessary because Julia 1.9+ extensions are
    # loaded as top-level modules; they are not automatically installed as
    # submodule bindings in the parent package.
    Core.eval(PaleobiologyDB, :(const PhyloPicMakie = $(@__MODULE__)))
end

end # module PhyloPicMakie
