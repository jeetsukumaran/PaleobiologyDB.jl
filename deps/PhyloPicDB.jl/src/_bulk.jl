# ---------------------------------------------------------------------------
# PhyloPicDB — bulk query operations
#
# Deduplicating batch fetchers that minimise API calls when the same node
# UUID appears multiple times in a collection.  Both functions use
# DataCaches.autocache to persist results across calls.
#
# Public:
#   batch_primary_images(node_uuids; build)                        → Dict{...}
#   batch_images(node_uuids; build, filter, max_pages)             → Dict{...}
# ---------------------------------------------------------------------------

import DataCaches: autocache

"""
    batch_primary_images(
        node_uuids;
        build = nothing,
        add_node_name::Bool = false,
    ) -> Dict{String, Union{PhyloPicImage, Nothing}}

Fetch the primary image for each node UUID in `node_uuids`, deduplicating
so that each unique UUID triggers at most one API call.  Results are cached
via DataCaches so that repeated calls across different collections reuse
previously fetched images without additional network requests.

# Arguments

- `node_uuids`: a vector of PhyloPic node UUID strings.  May contain
  duplicates; each unique UUID is fetched exactly once.
- `build`: PhyloPic build index.  `nothing` fetches the current build.
  The build number is included in the cache key, so results are automatically
  invalidated if the build changes.
- `add_node_name`: if `true`, populate `node_name` on each returned image.
  Included in the cache key so enriched and plain results are cached
  separately.  Default `false`.

# Returns

A `Dict{String, Union{PhyloPicImage, Nothing}}` mapping each input UUID to
its primary image (or `nothing` if absent).  Duplicates in `node_uuids` map
to the same entry.

# Examples

```julia
uuids = ["8f901db5-84c1-4dc0-93ba-2300eeddf4ab",
         "36c04f2f-b7d2-4891-a4a9-138d79592bf2",
         "8f901db5-84c1-4dc0-93ba-2300eeddf4ab"]  # duplicate

result = batch_primary_images(uuids)
# Only 2 API calls; both entries for the first UUID point to the same image.
```
"""
function batch_primary_images(
    node_uuids::AbstractVector{<:AbstractString};
    build::Union{Int, Nothing} = nothing,
    add_node_name::Bool        = false,
)::Dict{String, Union{PhyloPicImage, Nothing}}
    b            = ensure_build(build)
    unique_uuids = unique(node_uuids)

    out = Dict{String, Union{PhyloPicImage, Nothing}}()
    for uuid in unique_uuids
        img = autocache(
            () -> primary_image(uuid; build = b, add_node_name = add_node_name),
            batch_primary_images,
            "phylopic/primary_image",
            (; uuid = uuid, build = b, add_node_name = add_node_name),
        )
        out[uuid] = img
    end

    return out
end

"""
    batch_images(
        node_uuids;
        build = nothing,
        filter = :clade,
        max_pages = nothing,
        add_node_name::Bool = false,
    ) -> Dict{String, Vector{PhyloPicImage}}

Fetch all images for each node UUID in `node_uuids`, deduplicating so that
each unique UUID triggers at most one paginated fetch.  Results are cached
per `(uuid, build, filter, max_pages, add_node_name)` key.

# Arguments

- `node_uuids`: a vector of PhyloPic node UUID strings.
- `build`: PhyloPic build index.  `nothing` fetches the current build.
- `filter`: `:clade` (default) or `:node` — passed through to
  [`fetch_images`](@ref).
- `max_pages`: maximum pages to fetch per node.  `nothing` fetches all pages.
- `add_node_name`: if `true`, populate `node_name` on each returned image.
  Included in the cache key so enriched and plain results are cached
  separately.  Default `false`.

# Returns

A `Dict{String, Vector{PhyloPicImage}}` mapping each input UUID to its list
of images.  Duplicates map to the same vector.

# Examples

```julia
uuids = ["8f901db5-84c1-4dc0-93ba-2300eeddf4ab",
         "36c04f2f-b7d2-4891-a4a9-138d79592bf2"]

result = batch_images(uuids; max_pages = 2)
length(result["8f901db5-84c1-4dc0-93ba-2300eeddf4ab"])  # ≤ 60
```
"""
function batch_images(
    node_uuids::AbstractVector{<:AbstractString};
    build::Union{Int, Nothing}     = nothing,
    filter::Symbol                 = :clade,
    max_pages::Union{Int, Nothing} = nothing,
    add_node_name::Bool            = false,
)::Dict{String, Vector{PhyloPicImage}}
    b            = ensure_build(build)
    unique_uuids = unique(node_uuids)

    out = Dict{String, Vector{PhyloPicImage}}()
    for uuid in unique_uuids
        imgs = autocache(
            () -> fetch_images(uuid;
                build         = b,
                filter        = filter,
                max_pages     = max_pages,
                add_node_name = add_node_name,
            ),
            batch_images,
            "phylopic/images",
            (; uuid = uuid, build = b, filter = filter, max_pages = max_pages,
               add_node_name = add_node_name),
        )
        out[uuid] = imgs
    end

    return out
end
