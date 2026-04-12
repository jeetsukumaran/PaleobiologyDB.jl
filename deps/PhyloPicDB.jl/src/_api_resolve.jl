# ---------------------------------------------------------------------------
# PhyloPicDB — external identifier resolution API
#
# Public:
#   resolve_node(authority, namespace, object_ids; build)  → Union{String, Nothing}
#   resolve_pbdb_node(pbdb_ids; build)                     → Union{String, Nothing}
# ---------------------------------------------------------------------------

"""
    resolve_node(authority, namespace, object_ids; build = nothing)
        -> Union{String, Nothing}

Resolve a list of external identifiers to the closest matching PhyloPic node
UUID.

Sends a request to `/resolve/{authority}/{namespace}?objectIDs={ids}`.
Identifiers earlier in `object_ids` take priority: PhyloPic returns the node
matching the first identifier for which a match exists.

# Arguments

- `authority`: external database authority string (e.g. `"paleobiodb.org"`,
  `"gbif.org"`).
- `namespace`: namespace within the authority (e.g. `"txn"`, `"species"`).
- `object_ids`: ordered vector of identifier strings to try.  The first
  element has the highest priority.
- `build`: PhyloPic build index.  `nothing` fetches the current build.

# Returns

The matched PhyloPic node UUID as a `String`, or `nothing` if no match is
found or any error occurs.

# Examples

```julia
# Resolve GBIF species keys (most specific first)
uuid = resolve_node(
    "gbif.org", "species",
    ["5421410", "3191248", "5399"];
)
```
"""
function resolve_node(
    authority::AbstractString,
    namespace::AbstractString,
    object_ids::AbstractVector{<:AbstractString};
    build::Union{Int, Nothing} = nothing,
)::Union{String, Nothing}
    isempty(object_ids) && return nothing

    b       = ensure_build(build)
    ids_str = join(object_ids, ",")
    url     = "$PHYLOPIC_BASE_URL/resolve/$authority/$namespace" *
              "?build=$b&objectIDs=$ids_str"
    try
        resp = phylopic_get(url)
        obj  = JSON3.read(resp.body)

        # HTTP.jl follows the 308 redirect to the /nodes/{uuid} endpoint.
        # The final response body includes a top-level :uuid field.
        hasproperty(obj, :uuid) && return string(obj.uuid)

        # If the redirect was not followed, the 308 body is:
        # {"href": "/nodes/<uuid>?build=...", "title": "..."}
        if hasproperty(obj, :href)
            path = first(split(string(obj.href), '?'))
            uuid = last(split(path, '/'))
            isempty(uuid) || return uuid
        end

        return nothing
    catch err
        err isa HTTP.Exceptions.StatusError && err.status == 404 && return nothing
        return nothing
    end
end

"""
    resolve_pbdb_node(pbdb_ids; build = nothing) -> Union{String, Nothing}

Convenience wrapper for [`resolve_node`](@ref) using the Paleobiology Database
(`paleobiodb.org / txn`) as the authority.

`pbdb_ids` should be in priority order (most specific taxon first, then
progressively more inclusive ancestors), matching the ordering expected by the
PhyloPic `/resolve` endpoint.

# Arguments

- `pbdb_ids`: ordered vector of PBDB `orig_no` integer values, most-specific
  first.
- `build`: PhyloPic build index.  `nothing` fetches the current build.

# Returns

The matched PhyloPic node UUID as a `String`, or `nothing` if no match is
found.

# Examples

```julia
# Tyrannosaurus rex lineage: taxon first, ancestors after
uuid = resolve_pbdb_node([133360, 133359, 39168, 37177])
```
"""
function resolve_pbdb_node(
    pbdb_ids::AbstractVector{<:Integer};
    build::Union{Int, Nothing} = nothing,
)::Union{String, Nothing}
    isempty(pbdb_ids) && return nothing
    return resolve_node(
        "paleobiodb.org",
        "txn",
        string.(pbdb_ids);
        build = build,
    )
end
