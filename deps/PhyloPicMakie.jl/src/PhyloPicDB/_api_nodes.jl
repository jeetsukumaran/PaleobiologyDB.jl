# ---------------------------------------------------------------------------
# PhyloPicDB — node API
#
# Public:
#   fetch_node(uuid; build)                   → Union{PhyloPicNode, Nothing}
#   fetch_node_with_primary_image(uuid; build) → Tuple{Union{PhyloPicNode,Nothing},
#                                                      Union{PhyloPicImage,Nothing}}
# ---------------------------------------------------------------------------

"""
    fetch_node(uuid; build = nothing) -> Union{PhyloPicNode, Nothing}

Fetch a single [`PhyloPicNode`](@ref) by its UUID from the PhyloPic API.

# Arguments

- `uuid`: The PhyloPic node UUID string.
- `build`: PhyloPic build index.  `nothing` (default) fetches the current
  build automatically via [`ensure_build`](@ref).

# Returns

A [`PhyloPicNode`](@ref), or `nothing` if the node is not found (404) or any
other error occurs.

# Examples

```julia
node = fetch_node("8f901db5-84c1-4dc0-93ba-2300eeddf4ab")
isnothing(node) || println(node.preferred_name)
```
"""
function fetch_node(
    uuid::AbstractString;
    build::Union{Int, Nothing} = nothing,
)::Union{PhyloPicNode, Nothing}
    b   = ensure_build(build)
    url = "$PHYLOPIC_BASE_URL/nodes/$uuid?build=$b"
    try
        resp = phylopic_get(url)
        return _parse_node_json(JSON3.read(resp.body), b)
    catch
        return nothing
    end
end

"""
    fetch_node_with_primary_image(uuid; build)
        -> Tuple{Union{PhyloPicNode, Nothing}, Union{PhyloPicImage, Nothing}}

Fetch a node and its embedded primary image in a single API request.

Uses `?embed_primaryImage=true` to retrieve both records in one round trip.
The second element of the returned tuple is `nothing` when the node has no
primary image or when the image data cannot be parsed.

# Arguments

- `uuid`: The PhyloPic node UUID string.
- `build`: PhyloPic build index.  `nothing` fetches the current build.

# Returns

A two-element tuple `(node, image)`:
- `node`: a [`PhyloPicNode`](@ref), or `nothing` on error.
- `image`: a [`PhyloPicImage`](@ref), or `nothing` if absent or on error.

# Examples

```julia
node, img = fetch_node_with_primary_image("8f901db5-84c1-4dc0-93ba-2300eeddf4ab")
if !isnothing(img)
    println(img.thumbnail_url)
end
```
"""
function fetch_node_with_primary_image(
    uuid::AbstractString;
    build::Union{Int, Nothing} = nothing,
)::Tuple{Union{PhyloPicNode, Nothing}, Union{PhyloPicImage, Nothing}}
    b   = ensure_build(build)
    url = "$PHYLOPIC_BASE_URL/nodes/$uuid?build=$b&embed_primaryImage=true"
    try
        resp = phylopic_get(url)
        obj  = JSON3.read(resp.body)
        node = _parse_node_json(obj, b)

        img = nothing
        try
            img_obj = obj._embedded.primaryImage
            if !isnothing(img_obj)
                img = _parse_image_json(img_obj, b)
                # An image with no UUID is effectively absent.
                isempty(img.uuid) && (img = nothing)
            end
        catch
        end

        return (node, img)
    catch
        return (nothing, nothing)
    end
end
