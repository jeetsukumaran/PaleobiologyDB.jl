"""
    set_autocaching!(enabled::Bool; cache::Union{DataCaches.DataCache, Nothing} = nothing) -> Union{DataCaches.DataCache, Nothing}
    set_autocaching!(enabled::Bool, func; cache::Union{DataCaches.DataCache, Nothing} = nothing) -> Union{DataCaches.DataCache, Nothing}
    set_autocaching!(enabled::Bool, funcs::AbstractVector; cache::Union{DataCaches.DataCache, Nothing} = nothing) -> Union{DataCaches.DataCache, Nothing}

PBDB-owned delegate to [`DataCaches.set_autocaching!`](@ref) for the
autocache-enabled PaleobiologyDB and PBDBMakie APIs.

Use this qualified entrypoint when you want cache control to live on the
`PaleobiologyDB` public surface:

```julia
PaleobiologyDB.set_autocaching!(true)
PaleobiologyDB.set_autocaching!(true, pbdb_occurrences)
```
"""
function set_autocaching!(
        enabled::Bool;
        cache::Union{DataCaches.DataCache, Nothing} = nothing
    )::Union{DataCaches.DataCache, Nothing}
    return DataCaches.set_autocaching!(enabled; cache = cache)
end

function set_autocaching!(
        enabled::Bool,
        func;
        cache::Union{DataCaches.DataCache, Nothing} = nothing
    )::Union{DataCaches.DataCache, Nothing}
    return DataCaches.set_autocaching!(enabled, func; cache = cache)
end

function set_autocaching!(
        enabled::Bool,
        funcs::AbstractVector;
        cache::Union{DataCaches.DataCache, Nothing} = nothing
    )::Union{DataCaches.DataCache, Nothing}
    return DataCaches.set_autocaching!(enabled, funcs; cache = cache)
end

public set_autocaching!
