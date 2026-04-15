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
  the PhyloPic API).

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
using PhyloPicMakie

img = PhyloPicMakie._load_phylopic_image(some_thumbnail_url)
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
