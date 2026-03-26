module DataCaches 

using CSV
using DataFrames
import TOML
using Serialization
using UUIDs

export DataCache, CacheKey
export write!, keylabels, keypaths, clear!, describe, label, path
export @filecache, @memcache
export default_filecache, set_default_filecache!, memcache_clear!
export setautocache!

# =============================================================================
# CacheKey
# =============================================================================

"""
    CacheKey

A reference to a cached dataset in a [`DataCache`](@ref).

Fields are accessed directly:
- `key.id          :: String`  — unique identifier (UUID)
- `key.label       :: String`  — lookup key (hash string, or user-provided label; empty if none)
- `key.path        :: String`  — absolute path to the backing data file
- `key.description :: String`  — human-readable source expression (empty if none was recorded)
"""
struct CacheKey
    id::String
    label::String
    path::String
    description::String   # human-readable source expression, or ""
end

function Base.show(io::IO, k::CacheKey)
    disp = !isempty(k.description) ? k.description :
           !isempty(k.label)       ? k.label        : k.id[1:8] * "…"
    print(io, "CacheKey($(repr(disp)))")
end

# =============================================================================
# DataCache
# =============================================================================

"""
    DataCache([root::AbstractString])

A labeled, file-backed key-value store for caching query results across
Julia sessions.

Data is persisted in `root` as CSV files (for `DataFrame` values) or
serialized Julia objects (`.jls`) for anything else. An index file
(`cache_index.toml`) in `root` keeps track of all entries.

The default root directory is `\$HOME/.cache/PaleobiologyDB/` (overridden
by the `PBDB_CACHE_DIR` environment variable).

# Examples
```julia
cache = DataCache()
cache = DataCache("/my/project/cache")

# Write
key = write!(cache, df)
key = write!(cache, df; label="Dinosaur families")
cache["Trilobites"] = df          # setindex! sugar

# Read
df = read(cache, key)
df = read(cache, "Dinosaur families")
df = cache["Dinosaur families"]
df = cache[key]

# Introspect
keys(cache)       # → Vector{CacheKey}
keylabels(cache)  # → Vector{String}
keypaths(cache)   # → Vector{String}
label(cache, key) # → String
path(cache, key)  # → String
haskey(cache, "Dinosaur families")

# Manage
delete!(cache, key)
delete!(cache, "Dinosaur families")
clear!(cache)
describe(cache)
```
"""
mutable struct DataCache
    root::String
    _index::Dict{String,CacheKey}    # id → CacheKey
    _by_label::Dict{String,String}   # label → id
end

const _INDEX_FILENAME = "cache_index.toml"

function _default_cache_dir()
    return get(ENV, "PBDB_CACHE_DIR", joinpath(homedir(), ".cache", "PaleobiologyDB"))
end

function DataCache(root::AbstractString = _default_cache_dir())
    root = abspath(root)
    mkpath(root)
    cache = DataCache(root, Dict{String,CacheKey}(), Dict{String,String}())
    _load_index!(cache)
    return cache
end

# --- Index I/O ---------------------------------------------------------------

_index_file(cache::DataCache) = joinpath(cache.root, _INDEX_FILENAME)

function _load_index!(cache::DataCache)
    p = _index_file(cache)
    isfile(p) || return
    data = TOML.parsefile(p)
    for (id, entry) in get(data, "entries", Dict())
        lbl   = get(entry, "label",       "")
        fpath = get(entry, "path",        "")
        desc  = get(entry, "description", "")
        isfile(fpath) || continue
        key = CacheKey(id, lbl, fpath, desc)
        cache._index[id] = key
        isempty(lbl) || (cache._by_label[lbl] = id)
    end
end

function _save_index(cache::DataCache)
    entries = Dict{String,Any}()
    for (id, key) in cache._index
        entries[id] = Dict{String,Any}("label" => key.label, "path" => key.path, "description" => key.description)
    end
    open(_index_file(cache), "w") do io
        TOML.print(io, Dict{String,Any}("entries" => entries))
    end
end

# --- Storage helpers ---------------------------------------------------------

function _data_path(cache::DataCache, id::String, data)
    ext = data isa AbstractDataFrame ? ".csv" : ".jls"
    return joinpath(cache.root, id * ext)
end

function _write_file(fpath::String, data)
    if data isa AbstractDataFrame
        CSV.write(fpath, data)
    else
        open(fpath, "w") do io
            serialize(io, data)
        end
    end
end

function _read_file(key::CacheKey)
    if endswith(key.path, ".csv")
        return DataFrame(CSV.File(key.path; normalizenames = true))
    else
        return open(deserialize, key.path)
    end
end

# --- Internal removal --------------------------------------------------------

function _remove_entry!(cache::DataCache, id::String)
    key = get(cache._index, id, nothing)
    isnothing(key) && return
    isfile(key.path) && rm(key.path; force = true)
    delete!(cache._index, id)
    isempty(key.label) || delete!(cache._by_label, key.label)
end

# --- Public write/read -------------------------------------------------------

"""
    write!(cache::DataCache, data; label::AbstractString = "", description::AbstractString = "") → CacheKey

Store `data` in `cache` and return a [`CacheKey`](@ref).

If `label` is given and another entry with that label already exists,
it is silently replaced. `DataFrame` values are stored as CSV; all other
values use Julia `Serialization`. `description` is an optional human-readable
string (e.g. the source expression) stored alongside the entry for display.
"""
function write!(cache::DataCache, data; label::AbstractString = "", description::AbstractString = "")
    id    = string(uuid4())
    fpath = _data_path(cache, id, data)
    _write_file(fpath, data)
    if !isempty(label)
        old = get(cache._by_label, label, nothing)
        isnothing(old) || _remove_entry!(cache, old)
        cache._by_label[label] = id
    end
    key = CacheKey(id, label, fpath, description)
    cache._index[id] = key
    _save_index(cache)
    return key
end

"""
    read(cache::DataCache, key::CacheKey) → data
    read(cache::DataCache, label::AbstractString) → data

Retrieve a cached dataset by [`CacheKey`](@ref) or label string.
"""
function Base.read(cache::DataCache, key::CacheKey)
    isfile(key.path) || error("Cache file missing: $(key.path)")
    return _read_file(key)
end

function Base.read(cache::DataCache, lbl::AbstractString)
    id = get(cache._by_label, lbl, nothing)
    isnothing(id) && error("No cache entry with label $(repr(lbl))")
    return Base.read(cache, cache._index[id])
end

Base.getindex(cache::DataCache, lbl::AbstractString) = Base.read(cache, lbl)
Base.getindex(cache::DataCache, key::CacheKey)        = Base.read(cache, key)
Base.setindex!(cache::DataCache, data, lbl::AbstractString) = write!(cache, data; label = lbl)

# --- Introspection -----------------------------------------------------------

Base.haskey(cache::DataCache, lbl::AbstractString) = haskey(cache._by_label, lbl)
Base.haskey(cache::DataCache, key::CacheKey)        = haskey(cache._index, key.id)
Base.length(cache::DataCache)  = length(cache._index)
Base.isempty(cache::DataCache) = isempty(cache._index)

"""
    keys(cache::DataCache) → Vector{CacheKey}

Return all [`CacheKey`](@ref) objects stored in `cache`.
"""
Base.keys(cache::DataCache) = collect(values(cache._index))

"""
    keylabels(cache::DataCache) → Vector{String}

Return all labels of entries in `cache` (empty string for unlabeled entries).
"""
keylabels(cache::DataCache) = [k.label for k in values(cache._index)]

"""
    keypaths(cache::DataCache) → Vector{String}

Return the file paths of all entries in `cache`.
"""
keypaths(cache::DataCache) = [k.path for k in values(cache._index)]

"""
    label(cache::DataCache, key::CacheKey) → String

Return the label associated with `key` (same as `key.label`).
"""
label(::DataCache, key::CacheKey) = key.label

"""
    path(cache::DataCache, key::CacheKey) → String

Return the file path of the data file backing `key` (same as `key.path`).
"""
path(::DataCache, key::CacheKey) = key.path

# --- Management --------------------------------------------------------------

"""
    delete!(cache::DataCache, key::CacheKey)
    delete!(cache::DataCache, label::AbstractString)
    delete!(cache::DataCache, uuid_prefix::AbstractString)
    delete!(cache::DataCache, n::Integer)

Remove an entry from `cache` and delete its backing file from disk.

The `AbstractString` form first tries to match a label exactly, then falls back
to matching the UUID prefix shown in brackets by `describe` (e.g. `"2a9d4a87"`).
An ambiguous prefix (matching more than one entry) is an error.

The `Integer` form converts `n` to a string and delegates to the string form,
which is useful for numeric hash labels produced by `@filecache`.
"""
function Base.delete!(cache::DataCache, key::CacheKey)
    _remove_entry!(cache, key.id)
    _save_index(cache)
    return cache
end

function Base.delete!(cache::DataCache, lbl::AbstractString)
    id = get(cache._by_label, lbl, nothing)
    if isnothing(id)
        matches = [k for k in Base.keys(cache._index) if startswith(k, lbl)]
        if length(matches) == 1
            id = only(matches)
        elseif length(matches) > 1
            error("Ambiguous UUID prefix $(repr(lbl)) matches $(length(matches)) entries")
        else
            return cache
        end
    end
    _remove_entry!(cache, id)
    _save_index(cache)
    return cache
end

function Base.delete!(cache::DataCache, n::Integer)
    return Base.delete!(cache, string(n))
end

"""
    clear!(cache::DataCache)

Remove **all** entries from `cache` and delete their backing files from disk.
"""
function clear!(cache::DataCache)
    for id in collect(Base.keys(cache._index))
        _remove_entry!(cache, id)
    end
    _save_index(cache)
    return cache
end

"""
    describe(cache::DataCache)

Print a summary table of all entries in `cache`.
"""
function describe(cache::DataCache)
    entries = sort(collect(values(cache._index)); by = k -> k.label)
    if isempty(entries)
        println("DataCache is empty: $(cache.root)")
        return
    end
    n = length(entries)
    println("DataCache: $(cache.root)  ($n entr$(n == 1 ? "y" : "ies"))")
    for key in entries
        lbl    = !isempty(key.description) ? key.description :
                 !isempty(key.label)       ? key.label       : "(unlabeled)"
        status = isfile(key.path) ? "" : "  *** FILE MISSING ***"
        println("  [$(key.id[1:8])…]  $lbl$status")
        println("              $(key.path)")
    end
end

function Base.show(io::IO, cache::DataCache)
    n = length(cache._index)
    print(io, "DataCache(\"$(cache.root)\", $n entr$(n == 1 ? "y" : "ies"))")
end

# =============================================================================
# Memoization macros  (@mcache / @fcache)
# =============================================================================

# Module-level stores
const _memcache_store = Dict{UInt64,Any}()
const _filecache_ref  = Ref{Union{DataCache,Nothing}}(nothing)

# Autocache state
const _autocache_enabled_ref = Ref{Bool}(false)
const _autocache_cache_ref   = Ref{Union{DataCache,Nothing}}(nothing)
# nothing = all functions (global mode); Set = per-function allowlist
const _autocache_funcs_ref   = Ref{Union{Nothing,Set{Any}}}(nothing)

"""
    default_filecache() → DataCache

Return the module-level default [`DataCache`](@ref) used by [`@filecache`](@ref).
Created lazily on first access (root: `~/.cache/PaleobiologyDB/` by default).
"""
function default_filecache()
    if isnothing(_filecache_ref[])
        _filecache_ref[] = DataCache()
    end
    return _filecache_ref[]
end

"""
    set_default_filecache!(cache::DataCache)

Replace the module-level default cache used by [`@filecache`](@ref).
"""
function set_default_filecache!(cache::DataCache)
    _filecache_ref[] = cache
    return cache
end

"""
    memcache_clear!()

Discard all results stored by [`@memcache`](@ref) for this session.
"""
function memcache_clear!()
    empty!(_memcache_store)
end

"""
    setautocache!(enabled::Bool; cache::Union{DataCache,Nothing}=nothing) -> Union{DataCache,Nothing}

Enable or disable automatic caching for **all** `pbdb_*` API functions.

When `enabled=true`, every call to a `pbdb_*` function automatically stores its result
in a [`DataCache`](@ref) and returns the cached result on subsequent identical calls.
Pass `cache` to use a specific store; otherwise [`default_filecache()`](@ref) is used.

Returns the active [`DataCache`](@ref), or `nothing` when disabling.

# Examples
```julia
DataCaches.setautocache!(true)
DataCaches.setautocache!(false)
DataCaches.setautocache!(true; cache=DataCache("/my/project/cache"))
```
"""
function setautocache!(enabled::Bool; cache::Union{DataCache,Nothing}=nothing)
    _autocache_enabled_ref[] = enabled
    _autocache_funcs_ref[]   = nothing  # global mode
    if enabled
        _autocache_cache_ref[] = isnothing(cache) ? default_filecache() : cache
    else
        _autocache_cache_ref[] = nothing
    end
    return _autocache_cache_ref[]
end

"""
    setautocache!(enabled::Bool, func; cache::Union{DataCache,Nothing}=nothing) -> Union{DataCache,Nothing}
    setautocache!(enabled::Bool, funcs::AbstractVector; cache::Union{DataCache,Nothing}=nothing) -> Union{DataCache,Nothing}

Enable or disable automatic caching for a specific function (or list of functions).

When `enabled=true`, autocache is activated for `func` (additive — does not affect
other per-function settings). If global autocache is currently on, calling this switches
to per-function mode with only `{func}`.

When `enabled=false` and per-function mode is active, removes `func` from the allowlist.
If the allowlist becomes empty, autocache is fully disabled.

**Note:** `setautocache!(false, func)` has no effect when global autocache is on; call
`setautocache!(false)` to disable globally.

Returns the active [`DataCache`](@ref), or `nothing` when fully disabled.

# Examples
```julia
DataCaches.setautocache!(true, pbdb_occurrences)
DataCaches.setautocache!(true, [pbdb_occurrences, pbdb_taxa])
DataCaches.setautocache!(false, pbdb_occurrences)
```
"""
function setautocache!(enabled::Bool, func; cache::Union{DataCache,Nothing}=nothing)
    if enabled
        _autocache_enabled_ref[] = true
        if isnothing(_autocache_cache_ref[]) || !isnothing(cache)
            _autocache_cache_ref[] = isnothing(cache) ? default_filecache() : cache
        end
        existing = _autocache_funcs_ref[]
        if isnothing(existing)
            _autocache_funcs_ref[] = Set{Any}([func])
        else
            push!(existing, func)
        end
    else
        existing = _autocache_funcs_ref[]
        if isnothing(existing)
            @warn "setautocache!(false, func) has no effect when global autocache is active. " *
                  "Call setautocache!(false) to disable autocache globally."
            return _autocache_cache_ref[]
        end
        delete!(existing, func)
        if isempty(existing)
            _autocache_enabled_ref[] = false
            _autocache_funcs_ref[]   = nothing
            _autocache_cache_ref[]   = nothing
        end
    end
    return _autocache_cache_ref[]
end

function setautocache!(enabled::Bool, funcs::AbstractVector; cache::Union{DataCache,Nothing}=nothing)
    for f in funcs
        setautocache!(enabled, f; cache=cache)
    end
    return _autocache_cache_ref[]
end

# Internal helpers — not exported; called from dbapi.jl

function _autocache_active(func)
    _autocache_enabled_ref[] || return false
    get(task_local_storage(), :_pbdb_in_explicit_cache, false) && return false
    funcs = _autocache_funcs_ref[]
    isnothing(funcs) && return true  # global mode: all functions
    return func in funcs
end

function _get_autocache_store()
    c = _autocache_cache_ref[]
    isnothing(c) && error("Autocache is enabled but no cache is configured.")
    return c
end

function _autocache_key(func, endpoint, kwargs)
    sorted_kw = sort(collect(pairs(kwargs)); by=first)
    label = string(hash(("_autocache_", nameof(func), endpoint, sorted_kw)))
    kw_str = join(["$(k) = $(repr(v))" for (k, v) in sorted_kw], ", ")
    desc = isempty(kw_str) ? "$(nameof(func))($(endpoint))" :
                             "$(nameof(func))($(endpoint); $(kw_str))"
    return (label, desc)
end

# Build the runtime hash-key expression for both macros.
# Positional args are hashed by value; keyword args by (name, value) pairs.
function _cache_hash_expr(func_name::String, raw_args)
    pos = Any[]
    kw  = Any[]
    for a in raw_args
        if a isa Expr && a.head == :kw
            push!(kw, :($(QuoteNode(a.args[1])) => $(esc(a.args[2]))))
        elseif a isa Expr && a.head == :parameters
            for pa in a.args
                if pa isa Expr && pa.head == :kw
                    push!(kw, :($(QuoteNode(pa.args[1])) => $(esc(pa.args[2]))))
                end
            end
        else
            push!(pos, esc(a))
        end
    end
    return :(hash(($func_name, ($(pos...),), ($(kw...),))))
end

function _memcache_impl(expr)
    expr isa Expr && expr.head == :call ||
        error("@memcache: expected a function call, got: $expr")
    func_name = string(expr.args[1])
    key_expr  = _cache_hash_expr(func_name, expr.args[2:end])
    return quote
        let _k = $key_expr
            if haskey(_memcache_store, _k)
                _memcache_store[_k]
            else
                _r = $(esc(expr))
                _memcache_store[_k] = _r
                _r
            end
        end
    end
end

function _filecache_impl(expr, cache_expr)
    expr isa Expr && expr.head == :call ||
        error("@filecache: expected a function call, got: $expr")
    func_name = string(expr.args[1])
    key_expr  = _cache_hash_expr(func_name, expr.args[2:end])
    expr_str  = sprint(Base.show_unquoted, expr)
    return quote
        let _c = $cache_expr,
            _lbl = string($key_expr)
            if haskey(_c, _lbl)
                Base.read(_c, _lbl)
            else
                _r = task_local_storage(:_pbdb_in_explicit_cache, true) do
                    $(esc(expr))
                end
                write!(_c, _r; label = _lbl, description = $expr_str)
                _r
            end
        end
    end
end

"""
    @memcache expr

Evaluate `expr` (a function call) and cache the result **in memory** for
the current Julia session. Subsequent calls with identical arguments return
the cached value without re-executing the function.

The cache is keyed on the runtime values of all arguments. Use
[`memcache_clear!`](@ref) to discard cached results.

# Example
```julia
occs = @memcache pbdb_occurrences(base_name="Canidae", show="full")
taxa = @memcache pbdb_taxa(name="Dinosauria")
```
"""
macro memcache(expr)
    return _memcache_impl(expr)
end

"""
    @filecache expr
    @filecache cache expr

Evaluate `expr` (a function call) and store the result in a
[`DataCache`](@ref), persisting it **across Julia sessions**.
Subsequent calls with identical arguments load from cache without
executing the function again.

The one-argument form uses [`default_filecache()`](@ref). Pass an explicit
`DataCache` as the first argument to use a different store.

# Examples
```julia
occs = @filecache pbdb_occurrences(base_name="Canidae", show="full")

my_cache = DataCache("/data/pbdb_cache")
occs = @filecache my_cache pbdb_occurrences(base_name="Canidae")
```
"""
macro filecache(expr)
    return _filecache_impl(expr, :(default_filecache()))
end

macro filecache(cache, expr)
    return _filecache_impl(expr, esc(cache))
end

end # module