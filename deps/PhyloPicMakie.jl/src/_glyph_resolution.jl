"""
    _resolve_images_by_uuid(
        node_uuids::Union{AbstractVector{<:Union{AbstractString, Nothing}}, Nothing},
        glyph::Union{AbstractMatrix, Nothing},
        n::Integer;
        image_rendering::Symbol = :thumbnail,
    ) -> Vector{Union{Matrix{RGBA{N0f8}}, Nothing}}

For each of the `n` data points, return either a decoded image matrix or
`nothing` (when the image could not be resolved).

Exactly one of `node_uuids` or `glyph` must be non-`nothing`:

- If `glyph` is provided, it is broadcast to all `n` points.
- If `node_uuids` is provided, [`PhyloPicDB.primary_image`](@ref) is called
  for each unique non-`nothing` UUID, the selected URL is extracted via
  [`_select_image_url`](@ref), and the image is downloaded via
  [`_load_phylopic_image`](@ref).

`image_rendering` controls which URL is fetched; see
[`_select_image_url`](@ref) for the full symbol table.

`nothing` entries in `node_uuids`, as well as UUIDs for which image
resolution fails, produce `nothing` in the output.  The caller handles
these according to its `on_missing` policy.
"""
function _resolve_images_by_uuid(
    node_uuids::Union{AbstractVector{<:Union{AbstractString, Nothing}}, Nothing},
    glyph::Union{AbstractMatrix, Nothing},
    n::Integer;
    image_rendering::Symbol = :thumbnail,
)::Vector{Union{Matrix{RGBA{N0f8}}, Nothing}}
    if !isnothing(glyph)
        # Broadcast the single pre-loaded image to every data point.
        img_rgba = Matrix{RGBA{N0f8}}(RGBA{N0f8}.(glyph))
        return fill(img_rgba, n)
    end

    isnothing(node_uuids) && throw(ArgumentError(
        "_resolve_images_by_uuid: one of `node_uuids` or `glyph` must be provided."
    ))
    length(node_uuids) == n || throw(ArgumentError(
        "_resolve_images_by_uuid: `node_uuids` length ($(length(node_uuids))) must match " *
        "coordinate length ($n)."
    ))

    # Deduplicate: fetch primary image once per unique non-nothing, non-empty UUID.
    unique_uuids = unique(
        u for u in node_uuids
        if !isnothing(u) && !isempty(strip(u))
    )
    image_cache = Dict{String, Union{Matrix{RGBA{N0f8}}, Nothing}}()
    for uuid in unique_uuids
        img = PhyloPicDB.primary_image(uuid)
        if isnothing(img)
            image_cache[uuid] = nothing
        else
            url = _select_image_url(img, image_rendering)
            if ismissing(url)
                image_cache[uuid] = nothing
            else
                try
                    image_cache[uuid] = _load_phylopic_image(url)
                catch err
                    @warn "_resolve_images_by_uuid: could not load image for UUID \"$uuid\"" exception = err
                    image_cache[uuid] = nothing
                end
            end
        end
    end

    results = Vector{Union{Matrix{RGBA{N0f8}}, Nothing}}(undef, n)
    for i in 1:n
        uuid = node_uuids[i]
        results[i] = if isnothing(uuid) || isempty(strip(uuid))
            nothing
        else
            get(image_cache, uuid, nothing)
        end
    end
    return results
end
