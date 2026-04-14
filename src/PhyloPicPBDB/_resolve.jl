
# ---------------------------------------------------------------------------
# PhyloPicPBDB — PBDB taxon name → PhyloPic node UUID bridge
#
# Provides:
#   _phylopic_field_for_rendering(image_rendering) → Symbol
#   _resolve_images(taxon, glyph, n; image_rendering) → Vector{…}
#
# _phylopic_field_for_rendering is PBDB-specific: it maps image_rendering
# symbols to the prefixed field names in the NamedTuple returned by
# acquire_phylopic (e.g. :thumbnail → :phylopic_thumbnail).
#
# _resolve_images is the PBDB name-resolution bridge:
#   1. Maps unique taxon names → PhyloPic node UUIDs via phylopic_node.
#   2. Delegates image fetching to
#      PhyloPicMakie._resolve_images_by_uuid, which is the
#      PhyloPic-native implementation (node UUID → primary_image → URL →
#      _load_phylopic_image).
#
# Image download and caching is handled entirely within PhyloPicMakie.
# The PBDB-specific taxon → node mapping is the only work done here.
# ---------------------------------------------------------------------------

# PhyloPicMakie, PhyloPicDB, and phylopic_node are all in scope from
# the enclosing PhyloPicPBDB module (phylopic.jl).

# ---------------------------------------------------------------------------
# Internal: image rendering field resolution (PBDB-specific)
# ---------------------------------------------------------------------------

"""
    _phylopic_field_for_rendering(image_rendering::Symbol) -> Symbol

Map an `image_rendering` symbol to the corresponding field key in the
NamedTuple returned by `acquire_phylopic` (with the default `"phylopic_"`
prefix).

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
# Internal: PBDB name → UUID bridge + image resolution
# ---------------------------------------------------------------------------

"""
    _resolve_images(
        taxon::Union{AbstractVector, Nothing},
        glyph::Union{AbstractMatrix, Nothing},
        n::Integer;
        image_rendering::Symbol = :thumbnail,
    ) -> Vector{Union{Matrix{RGBA{N0f8}}, Nothing}}

For each of the `n` data points, return either a decoded image matrix or
`nothing` (when the image could not be resolved).

Exactly one of `taxon` or `glyph` must be non-`nothing`:

- If `glyph` is provided, it is broadcast to all `n` points.
- If `taxon` is provided, each unique non-empty name is resolved to a
  PhyloPic node UUID via [`PaleobiologyDB.Taxonomy.phylopic_node`](@ref)
  (which is cached via `autocache`).  The UUID vector is then forwarded to
  [`PhyloPicMakie._resolve_images_by_uuid`](@ref) for image fetching.

`image_rendering` controls which URL is fetched; see
[`PhyloPicMakie._select_image_url`](@ref) for the full symbol table.
"""
function _resolve_images(
    taxon::Union{AbstractVector, Nothing},
    glyph::Union{AbstractMatrix, Nothing},
    n::Integer;
    image_rendering::Symbol = :thumbnail,
)::Vector{Union{Matrix{RGBA{N0f8}}, Nothing}}
    if !isnothing(glyph)
        # Delegate glyph broadcast to PhyloPicMakie.
        return PhyloPicMakie._resolve_images_by_uuid(
            nothing, glyph, n; image_rendering,
        )
    end

    isnothing(taxon) && throw(ArgumentError(
        "augment_phylopic: one of `taxon` or `glyph` must be provided."
    ))
    length(taxon) == n || throw(ArgumentError(
        "augment_phylopic: `taxon` length ($(length(taxon))) must match " *
        "coordinate length ($n)."
    ))

    # Resolve each unique non-missing, non-empty taxon name to a PhyloPic
    # node UUID.  phylopic_node is cached via autocache so repeated calls
    # for the same name within a session incur no extra PBDB API traffic.
    unique_names = unique(v for v in taxon if !ismissing(v) && !isempty(strip(string(v))))
    uuid_cache   = Dict{String, Union{String, Nothing}}()
    for name in unique_names
        s    = string(name)
        node = phylopic_node(s)
        uuid_cache[s] = isnothing(node) ? nothing : node.uuid
    end

    # Build a UUID vector aligned with the `n` taxon entries.
    node_uuids = Vector{Union{String, Nothing}}(undef, n)
    for i in 1:n
        v = taxon[i]
        node_uuids[i] = if ismissing(v)
            nothing
        else
            s = string(v)
            isempty(strip(s)) ? nothing : get(uuid_cache, s, nothing)
        end
    end

    # Delegate image fetching to the PhyloPic-native implementation.
    return PhyloPicMakie._resolve_images_by_uuid(
        node_uuids, nothing, n; image_rendering,
    )
end
