# ---------------------------------------------------------------------------
# PhyloPicDB — image API
#
# Public:
#   fetch_image(uuid; build)                              → Union{PhyloPicImage, Nothing}
#   fetch_images(node_uuid; build, filter, max_pages)     → Vector{PhyloPicImage}
# ---------------------------------------------------------------------------

# Number of images returned per page by the PhyloPic /images list endpoint.
const _IMAGES_PER_PAGE = 30

"""
    fetch_image(uuid; build = nothing) -> Union{PhyloPicImage, Nothing}

Fetch a single [`PhyloPicImage`](@ref) by its UUID from the PhyloPic API.

# Arguments

- `uuid`: The PhyloPic image UUID string.
- `build`: PhyloPic build index.  `nothing` fetches the current build.

# Returns

A [`PhyloPicImage`](@ref), or `nothing` if the image is not found or any
error occurs.

# Examples

```julia
img = fetch_image("045279d5-24e5-4838-bec9-0bea86812e35")
isnothing(img) || println(img.thumbnail_url)
```
"""
function fetch_image(
    uuid::AbstractString;
    build::Union{Int, Nothing} = nothing,
)::Union{PhyloPicImage, Nothing}
    b   = ensure_build(build)
    url = "$PHYLOPIC_BASE_URL/images/$uuid?build=$b"
    try
        resp = phylopic_get(url)
        img  = _parse_image_json(JSON3.read(resp.body), b)
        isempty(img.uuid) && return nothing
        return img
    catch
        return nothing
    end
end

# ---------------------------------------------------------------------------
# Internal: single-page fetch
# ---------------------------------------------------------------------------

# Fetch one page (zero-indexed) of the /images list for a node.
# filter_param is "filter_clade" or "filter_node".
# Returns a (possibly empty) Vector{PhyloPicImage} and the total page count,
# or (empty, 0) on any error.
function _fetch_images_page(
    node_uuid::AbstractString,
    build::Int,
    page::Int,
    filter_param::AbstractString,
)::Tuple{Vector{PhyloPicImage}, Int}
    url = "$PHYLOPIC_BASE_URL/images?build=$build" *
          "&$filter_param=$node_uuid&embed_items=true&page=$page"
    try
        resp    = phylopic_get(url)
        obj     = JSON3.read(resp.body)
        n_pages = try Int(obj.totalPages) catch; 1 end
        items   = try obj._embedded.items catch; return (PhyloPicImage[], n_pages) end
        images  = [_parse_image_json(item, build) for item in items]
        # Discard entries that failed to parse (empty uuid).
        filter!(img -> !isempty(img.uuid), images)
        return (images, n_pages)
    catch
        return (PhyloPicImage[], 0)
    end
end

"""
    fetch_images(node_uuid; build = nothing, filter = :clade, max_pages = nothing)
        -> Vector{PhyloPicImage}

Return all [`PhyloPicImage`](@ref)s associated with a PhyloPic node,
paging through the `/images` list endpoint.

# Arguments

- `node_uuid`: PhyloPic node UUID string.
- `build`: PhyloPic build index.  `nothing` fetches the current build.
- `filter`: image scope.
  - `:clade` (default): images for the node and all its descendants, ordered
    from most-basal to most-nested.
  - `:node`: only images tagged to exactly this node.
- `max_pages`: if provided, fetch at most this many pages (each page contains
  up to $(repr(_IMAGES_PER_PAGE)) images).  `nothing` (default) fetches all
  pages.

# Returns

A `Vector{PhyloPicImage}`.  An empty vector is returned when the node has no
images or cannot be resolved.

# Throws

`ArgumentError` if `filter` is not `:clade` or `:node`.

# Examples

```julia
# All clade images for the Carnivora node
imgs = fetch_images("36c04f2f-b7d2-4891-a4a9-138d79592bf2"; max_pages = 2)
length(imgs)  # up to 60

# Only images directly tagging this node
imgs_node = fetch_images("36c04f2f-b7d2-4891-a4a9-138d79592bf2"; filter = :node)
```
"""
function fetch_images(
    node_uuid::AbstractString;
    build::Union{Int, Nothing}     = nothing,
    filter::Symbol                 = :clade,
    max_pages::Union{Int, Nothing} = nothing,
)::Vector{PhyloPicImage}
    filter in (:clade, :node) ||
        throw(ArgumentError(
            "fetch_images: `filter` must be :clade or :node, got :$filter"
        ))

    b            = ensure_build(build)
    filter_param = filter === :clade ? "filter_clade" : "filter_node"

    # Fetch page 0 to learn totalPages.
    first_page, n_pages = _fetch_images_page(node_uuid, b, 0, filter_param)
    n_pages == 0 && return PhyloPicImage[]

    limit = isnothing(max_pages) ? n_pages : min(n_pages, max_pages)

    results = copy(first_page)
    sizehint!(results, limit * _IMAGES_PER_PAGE)

    for page in 1:(limit - 1)
        page_imgs, _ = _fetch_images_page(node_uuid, b, page, filter_param)
        append!(results, page_imgs)
    end

    return results
end
