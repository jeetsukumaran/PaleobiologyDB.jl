
# ---------------------------------------------------------------------------
# PhyloPicMakie — image download and caching
#
# Provides a cached image loader keyed on the thumbnail URL returned by
# acquire_phylopic.  Each unique URL is downloaded at most once per cache
# lifetime; subsequent calls return the stored matrix without any network
# activity.
#
# Cache layer 1 (taxon → metadata/URL): handled by acquire_phylopic in the
# main package via DataCaches.autocache.
#
# Cache layer 2 (URL → decoded image matrix): handled here.
#
# Public (within extension):
#   _load_phylopic_image(url)  → Matrix{RGBA{N0f8}}
# ---------------------------------------------------------------------------

import Downloads: download as _downloads_download
import FileIO
import DataCaches: autocache
using Makie: RGBA, N0f8

"""
    _load_phylopic_image(url::AbstractString) -> Matrix{RGBA{N0f8}}

Download and decode the PNG image at `url`, returning it as a matrix of
RGBA pixels normalised to the `N0f8` (8-bit) fixed-point range.

Results are automatically cached via DataCaches.jl using `url` as the
cache key.  A cached matrix is returned on all subsequent calls for the
same URL within the same cache lifetime, with no network activity.

## Arguments

- `url`: HTTPS URL to a PNG image (typically `rec.phylopic_thumbnail` from
  [`PaleobiologyDB.Taxonomy.acquire_phylopic`](@ref)).

## Returns

A `Matrix{RGBA{N0f8}}` ready for use with `Makie.image!`.  The matrix
represents the image in column-major (Julia) order; callers should apply
`rotr90` before passing to `image!` to correct for Makie's row-major
convention.

## Errors

Throws if the download or image decoding fails and no cached result is
available.

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy
using CairoMakie, FileIO

rec = acquire_phylopic("Tyrannosaurus")
img = PaleobiologyDB.PhyloPicMakie._load_phylopic_image(rec.phylopic_thumbnail)
# img isa Matrix{RGBA{N0f8}}
```
"""
function _load_phylopic_image(url::AbstractString)::Matrix{RGBA{N0f8}}
    _do_fetch = () -> begin
        @debug "PhyloPicMakie: downloading image" url
        tmp = _downloads_download(url)
        try
            raw = FileIO.load(tmp)
            @debug "PhyloPicMakie: image decoded" url size = size(raw)
            return Matrix{RGBA{N0f8}}(RGBA{N0f8}.(raw))
        finally
            rm(tmp; force = true)
        end
    end
    return autocache(
        _do_fetch,
        _load_phylopic_image,
        "phylopic/image",
        (; url = url),
    )
end
