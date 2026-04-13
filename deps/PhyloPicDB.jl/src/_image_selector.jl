# ---------------------------------------------------------------------------
# PhyloPicDB — image selector layer
#
# High-level functions that combine a node UUID with an image-retrieval
# strategy, and a pure dispatch function for choosing one image from a list.
#
# Public:
#   with_node_names(images; build)                     → Vector{PhyloPicImage}
#   primary_image(node_uuid; build, add_node_name)     → Union{PhyloPicImage, Nothing}
#   clade_images(node_uuid; build, max_pages,
#                add_node_name)                        → Vector{PhyloPicImage}
#   node_images(node_uuid; build, max_pages,
#               add_node_name)                         → Vector{PhyloPicImage}
#   select_image(images, selector)                     → Union{PhyloPicImage, Nothing}
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Node-name enrichment
# ---------------------------------------------------------------------------

"""
    with_node_names(
        images::AbstractVector{PhyloPicImage};
        build::Union{Int, Nothing} = nothing,
    ) -> Vector{PhyloPicImage}

Return a copy of `images` with `node_name` populated for every image that has
a `specific_node_uuid`.

Node lookups are deduplicated: each unique UUID triggers at most one call to
[`fetch_node`](@ref).  Images whose `specific_node_uuid` is `nothing`, or
whose node cannot be fetched, are returned unchanged.

This function makes network requests and is therefore not pure.

# Arguments

- `images`: vector of [`PhyloPicImage`](@ref) values to enrich.
- `build`: PhyloPic build index.  `nothing` (default) fetches the current
  build automatically.

# Returns

A `Vector{PhyloPicImage}` of the same length as `images`, with `node_name`
set wherever the corresponding node was reachable.

# Examples

```julia
imgs = clade_images(uuid; max_pages = 1)
enriched = with_node_names(imgs)
enriched[1].node_name   # → "Tyrannosaurus" (or nothing if node unreachable)
```
"""
function with_node_names(
    images::AbstractVector{PhyloPicImage};
    build::Union{Int, Nothing} = nothing,
)::Vector{PhyloPicImage}
    b = ensure_build(build)
    uuid_to_name = Dict{String, String}()
    for img in images
        isnothing(img.specific_node_uuid) && continue
        uuid = img.specific_node_uuid::String
        haskey(uuid_to_name, uuid) && continue
        node = fetch_node(uuid; build = b)
        isnothing(node) || (uuid_to_name[uuid] = node.preferred_name)
    end
    return [
        let u = img.specific_node_uuid
            (!isnothing(u) && haskey(uuid_to_name, u::String)) ?
                _with_node_name(img, uuid_to_name[u::String]) : img
        end
        for img in images
    ]
end

"""
    primary_image(
        node_uuid;
        build = nothing,
        add_node_name::Bool = false,
    ) -> Union{PhyloPicImage, Nothing}

Return the designated primary image for a PhyloPic node, fetching both the
node and image in a single API request via `embed_primaryImage=true`.

This is the fastest way to get one representative image for a node: it
requires exactly one HTTP round trip (plus one additional round trip when
`add_node_name = true` and the image has a `specific_node_uuid`).

# Arguments

- `node_uuid`: PhyloPic node UUID string.
- `build`: PhyloPic build index.  `nothing` fetches the current build.
- `add_node_name`: if `true`, fetch the node at `specific_node_uuid` and
  populate `img.node_name` with its `preferred_name`.  Default `false`.

# Returns

A [`PhyloPicImage`](@ref), or `nothing` if the node has no primary image or
the request fails.

# Examples

```julia
img = primary_image("8f901db5-84c1-4dc0-93ba-2300eeddf4ab")
isnothing(img) || println(img.thumbnail_url)

img2 = primary_image("8f901db5-84c1-4dc0-93ba-2300eeddf4ab"; add_node_name = true)
isnothing(img2) || println(img2.node_name)
```
"""
function primary_image(
    node_uuid::AbstractString;
    build::Union{Int, Nothing} = nothing,
    add_node_name::Bool        = false,
)::Union{PhyloPicImage, Nothing}
    _, img = fetch_node_with_primary_image(node_uuid; build = build)
    isnothing(img) && return nothing
    add_node_name || return img
    enriched = with_node_names([img]; build = build)
    return enriched[1]
end

"""
    clade_images(
        node_uuid;
        build = nothing,
        max_pages = nothing,
        add_node_name::Bool = false,
    ) -> Vector{PhyloPicImage}

Return all images illustrating the node or any of its descendants, paging
through the PhyloPic `/images` list with `filter_clade`.

Images are ordered from most-basal (closest to the query node in the tree)
to most-nested (deepest descendant).  Within a build, this ordering is
deterministic, so integer-index selection via [`select_image`](@ref) is
stable across calls.

# Arguments

- `node_uuid`: PhyloPic node UUID string.
- `build`: PhyloPic build index.  `nothing` fetches the current build.
- `max_pages`: if provided, fetch at most this many pages (~30 images each).
- `add_node_name`: if `true`, populate `node_name` on each returned image
  via deduplicated [`fetch_node`](@ref) calls.  Default `false`.

# Returns

A `Vector{PhyloPicImage}`.  Empty when the clade has no images.

# Examples

```julia
imgs = clade_images("36c04f2f-b7d2-4891-a4a9-138d79592bf2"; max_pages = 2)
length(imgs)   # ≤ 60

imgs2 = clade_images("36c04f2f-b7d2-4891-a4a9-138d79592bf2"; add_node_name = true)
imgs2[1].node_name   # → e.g. "Carnivora"
```
"""
function clade_images(
    node_uuid::AbstractString;
    build::Union{Int, Nothing}     = nothing,
    max_pages::Union{Int, Nothing} = nothing,
    add_node_name::Bool            = false,
)::Vector{PhyloPicImage}
    return fetch_images(node_uuid;
        build          = build,
        filter         = :clade,
        max_pages      = max_pages,
        add_node_name  = add_node_name,
    )
end

"""
    node_images(
        node_uuid;
        build = nothing,
        max_pages = nothing,
        add_node_name::Bool = false,
    ) -> Vector{PhyloPicImage}

Return only images tagged directly to this node (not descendants).

Uses `filter_node` on the `/images` list endpoint.  Results are typically
fewer than [`clade_images`](@ref).

# Arguments

- `node_uuid`: PhyloPic node UUID string.
- `build`: PhyloPic build index.  `nothing` fetches the current build.
- `max_pages`: if provided, fetch at most this many pages.
- `add_node_name`: if `true`, populate `node_name` on each returned image
  via deduplicated [`fetch_node`](@ref) calls.  Default `false`.

# Returns

A `Vector{PhyloPicImage}`.

# Examples

```julia
imgs = node_images("36c04f2f-b7d2-4891-a4a9-138d79592bf2")
length(imgs)   # usually fewer than clade_images
```
"""
function node_images(
    node_uuid::AbstractString;
    build::Union{Int, Nothing}     = nothing,
    max_pages::Union{Int, Nothing} = nothing,
    add_node_name::Bool            = false,
)::Vector{PhyloPicImage}
    return fetch_images(node_uuid;
        build         = build,
        filter        = :node,
        max_pages     = max_pages,
        add_node_name = add_node_name,
    )
end

# ---------------------------------------------------------------------------
# select_image — pure dispatch over selector types
# ---------------------------------------------------------------------------

"""
    select_image(images, selector) -> Union{PhyloPicImage, Nothing}

Select one image from `images` according to `selector`.

This is a pure function — it performs no I/O and makes no network requests.

# Selector behaviour

| `selector` value | Behaviour |
|---|---|
| `:first` | Return `images[1]` if non-empty, else `nothing`. |
| `Int n` | Return `images[n]` if `1 ≤ n ≤ length(images)`, else `nothing`. Out-of-bounds is not an error — it silently returns `nothing`. |
| Callable `f` | Return `f(images)`.  `f` receives the full `Vector{PhyloPicImage}` and must return a `PhyloPicImage` or `nothing`. |

# Arguments

- `images`: a vector of [`PhyloPicImage`](@ref) values.
- `selector`: a `Symbol` (`:first`), `Int`, or callable.

# Returns

A [`PhyloPicImage`](@ref) or `nothing`.

# Throws

`ArgumentError` for unrecognised `Symbol` selectors.

# Examples

```julia
imgs = clade_images("36c04f2f-b7d2-4891-a4a9-138d79592bf2"; max_pages = 1)

select_image(imgs, :first)   # first image, or nothing if empty
select_image(imgs, 3)        # third image, or nothing if fewer than 3
select_image(imgs, 999)      # nothing (out of bounds)
select_image(imgs, v -> last(v))   # last image via callable
```
"""
function select_image(
    images::AbstractVector{PhyloPicImage},
    selector::Symbol,
)::Union{PhyloPicImage, Nothing}
    selector === :first && return isempty(images) ? nothing : images[1]
    throw(ArgumentError(
        "select_image: unrecognised Symbol selector :$selector. " *
        "Valid symbol: :first."
    ))
end

function select_image(
    images::AbstractVector{PhyloPicImage},
    selector::Int,
)::Union{PhyloPicImage, Nothing}
    (isempty(images) || selector < 1 || selector > length(images)) && return nothing
    return images[selector]
end

function select_image(
    images::AbstractVector{PhyloPicImage},
    selector,
)::Union{PhyloPicImage, Nothing}
    return selector(images)
end
