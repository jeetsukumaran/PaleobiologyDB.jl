
# ---------------------------------------------------------------------------
# PhyloPicPBDB — image resolution: taxon name → PhyloPic URL → image matrix
#
# Provides:
#   _phylopic_field_for_rendering(image_rendering) → Symbol
#   _resolve_images(taxon, glyph, n; image_rendering) → Vector{…}
#
# Image download and caching is delegated to
# PhyloPicDB.PhyloPicMakie._load_phylopic_image.  Taxon-name → PhyloPic URL
# resolution is handled by PaleobiologyDB.Taxonomy.acquire_phylopic, which
# requires a live PBDB connection and cannot live in PhyloPicDB.
# ---------------------------------------------------------------------------

import PhyloPicDB
using PaleobiologyDB.Taxonomy: acquire_phylopic

# ---------------------------------------------------------------------------
# Internal: image rendering field resolution
# ---------------------------------------------------------------------------

"""
    _phylopic_field_for_rendering(image_rendering::Symbol) -> Symbol

Map an `image_rendering` symbol to the corresponding field key in the
NamedTuple returned by `acquire_phylopic` (with the default `"phylopic_"` prefix).

| `image_rendering` | `acquire_phylopic` field | Format |
|---|---|---|
| `:thumbnail`   | `:phylopic_thumbnail`   | PNG; square thumbnail, largest available (default) |
| `:raster`      | `:phylopic_raster`      | PNG; full-resolution, largest available |
| `:og_image`    | `:phylopic_og_image`    | PNG; Open Graph social-media preview |
| `:vector`      | `:phylopic_vector`      | SVG; black silhouette on transparent — requires SVG-capable `FileIO` plugin |
| `:source_file` | `:phylopic_source_file` | SVG or raster — format matches the original upload |

Throws `ArgumentError` for unrecognised symbols.
"""
function _phylopic_field_for_rendering(image_rendering::Symbol)::Symbol
    image_rendering === :thumbnail   && return :phylopic_thumbnail
    image_rendering === :raster      && return :phylopic_raster
    image_rendering === :og_image    && return :phylopic_og_image
    image_rendering === :vector      && return :phylopic_vector
    image_rendering === :source_file && return :phylopic_source_file
    throw(ArgumentError(
        "_phylopic_field_for_rendering: unknown `image_rendering` value " *
        "`:$image_rendering`. " *
        "Valid values: $(join(string.(':', PhyloPicDB.PHYLOPIC_IMAGE_RENDERINGS), ", "))."
    ))
end

# ---------------------------------------------------------------------------
# Internal: resolve images for a vector of taxa / glyphs
# ---------------------------------------------------------------------------

"""
    _resolve_images(
        taxon::Union{AbstractVector, Nothing},
        glyph::Union{AbstractMatrix{<:Colorant}, Nothing},
        n::Integer;
        image_rendering::Symbol = :thumbnail,
    ) -> Vector{Union{Matrix{RGBA{N0f8}}, Nothing}}

For each of the `n` data points, return either a decoded image matrix or
`nothing` (when the image could not be resolved).

Exactly one of `taxon` or `glyph` must be non-`nothing`:
- If `glyph` is provided, it is broadcast to all `n` points.
- If `taxon` is provided, `acquire_phylopic` is called for each unique name
  and the selected URL is downloaded via
  `PhyloPicDB.PhyloPicMakie._load_phylopic_image`.

`image_rendering` controls which URL is fetched; see
[`_phylopic_field_for_rendering`](@ref) for the full symbol table.
"""
function _resolve_images(
    taxon::Union{AbstractVector, Nothing},
    glyph::Union{AbstractMatrix, Nothing},
    n::Integer;
    image_rendering::Symbol = :thumbnail,
)::Vector{Union{Matrix{RGBA{N0f8}}, Nothing}}
    if !isnothing(glyph)
        # Broadcast the single pre-loaded image to every data point.
        img_rgba = Matrix{RGBA{N0f8}}(RGBA{N0f8}.(glyph))
        return fill(img_rgba, n)
    end

    isnothing(taxon) && throw(ArgumentError(
        "augment_phylopic: one of `taxon` or `glyph` must be provided."
    ))
    length(taxon) == n || throw(ArgumentError(
        "augment_phylopic: `taxon` length ($(length(taxon))) must match " *
        "coordinate length ($n)."
    ))

    field = _phylopic_field_for_rendering(image_rendering)

    # Deduplicate: call acquire_phylopic once per unique non-missing name.
    unique_names = unique(skipmissing(taxon))
    url_cache = Dict{String, Union{String, Missing}}()
    for name in unique_names
        s = string(name)
        isempty(strip(s)) && continue
        rec = acquire_phylopic(s)
        url_cache[s] = get(rec, field, missing)
    end

    results = Vector{Union{Matrix{RGBA{N0f8}}, Nothing}}(undef, n)
    for i in 1:n
        v = taxon[i]
        if ismissing(v)
            results[i] = nothing
            continue
        end
        s = string(v)
        if isempty(strip(s))
            results[i] = nothing
            continue
        end
        url = get(url_cache, s, missing)
        if ismissing(url)
            results[i] = nothing
        else
            try
                results[i] = PhyloPicDB.PhyloPicMakie._load_phylopic_image(url)
            catch err
                @warn "augment_phylopic: could not load image for \"$s\"" exception = err
                results[i] = nothing
            end
        end
    end
    return results
end
