module DataCaches

using CSV
using DataFrames
using Dates
import TOML
using Serialization
using UUIDs

export DataCache, CacheKey
export write!, relabel!, reindexcache!, keylabels, keypaths, clear!, showcache, label, path
export @filecache, @memcache
export default_filecache, set_default_filecache!, memcache_clear!
export setautocache!
export autocache

# =============================================================================
# CacheKey
# =============================================================================

"""
    CacheKey

A reference to a cached dataset in a [`DataCache`](@ref).

Fields are accessed directly:
- `key.id          :: String`    — unique identifier (UUID)
- `key.seq         :: Int`       — stable integer index (persisted; use `reindexcache!` to compact gaps)
- `key.label       :: String`    — lookup key (hash string, or user-provided label; empty if none)
- `key.path        :: String`    — absolute path to the backing data file
- `key.description :: String`    — human-readable source expression (empty if none was recorded)
- `key.datecached  :: DateTime`  — when the entry was written; `typemin(DateTime)` if unknown
"""
struct CacheKey
    id::String
    seq::Int              # stable integer index, persisted to TOML
    label::String
    path::String
    description::String   # human-readable source expression, or ""
    datecached::DateTime  # timestamp of last write; typemin(DateTime) = unknown (legacy entry)
end

function Base.show(io::IO, k::CacheKey)
    disp = !isempty(k.description) ? k.description :
           !isempty(k.label)       ? k.label        : k.id[1:8]
    print(io, "CacheKey($(repr(disp)))")
end

# Internal: format one CacheKey line with a given seq column width for alignment.
function _print_cachekey(io::IO, k::CacheKey, seq_width::Int)
    lbl    = !isempty(k.description) ? k.description :
             !isempty(k.label)       ? k.label       : "(unlabeled)"
    dt_str = k.datecached == typemin(DateTime) ?
             " " ^ 19 :
             Dates.format(k.datecached, "yyyy-mm-ddTHH:MM:SS")
    status = isfile(k.path) ? "" : "  *** FILE MISSING ***"
    seq_str = lpad(k.seq, seq_width)
    # prefix: "  [" + seq_str + "]  " + dt_str + "  " + uuid8 + "  "
    #          3   + seq_width + 3  +   19    +  2  +   8   +  2  = seq_width + 37
    prefix_len = seq_width + 37
    println(io, "  [$(seq_str)]  $(dt_str)  $(k.id[1:8])  $lbl$status")
    print(io,   " " ^ prefix_len * k.path)
end

function Base.show(io::IO, ::MIME"text/plain", k::CacheKey)
    _print_cachekey(io, k, ndigits(k.seq))
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
showcache(cache)
```
"""
mutable struct DataCache
    root::String
    _index::Dict{String,CacheKey}    # id → CacheKey
    _by_label::Dict{String,String}   # label → id
    _next_seq::Int                   # monotonically incrementing seq counter
end

const _INDEX_FILENAME = "cache_index.toml"

# NOTE: default dir intentionally keeps "PaleobiologyDB" while this package
# ships bundled with PaleobiologyDB.jl. Update to "DataCaches" when published
# as an independent package.
function _default_cache_dir()
    return get(ENV, "PBDB_CACHE_DIR", joinpath(homedir(), ".cache", "PaleobiologyDB"))
end

function DataCache(root::AbstractString = _default_cache_dir())
    root = abspath(root)
    mkpath(root)
    cache = DataCache(root, Dict{String,CacheKey}(), Dict{String,String}(), 1)
    _load_index!(cache)
    return cache
end

# --- Index I/O ---------------------------------------------------------------

_index_file(cache::DataCache) = joinpath(cache.root, _INDEX_FILENAME)

function _load_index!(cache::DataCache)
    p = _index_file(cache)
    isfile(p) || return
    data = TOML.parsefile(p)
    legacy = Tuple{String,String,String,String,DateTime}[]  # (id, lbl, fpath, desc, dt) for seq==0
    max_seq = 0
    for (id, entry) in get(data, "entries", Dict())
        lbl    = get(entry, "label",       "")
        fpath  = get(entry, "path",        "")
        desc   = get(entry, "description", "")
        seq    = get(entry, "seq",         0)
        dt_raw = get(entry, "datecached",  "")
        dt = if dt_raw isa DateTime
                 dt_raw
             elseif dt_raw isa AbstractString && !isempty(dt_raw)
                 try
                     DateTime(dt_raw, dateformat"yyyy-mm-ddTHH:MM:SS")
                 catch
                     typemin(DateTime)
                 end
             else
                 typemin(DateTime)
             end
        isfile(fpath) || continue
        if seq == 0
            push!(legacy, (id, lbl, fpath, desc, dt))
        else
            max_seq = max(max_seq, seq)
            key = CacheKey(id, seq, lbl, fpath, desc, dt)
            cache._index[id] = key
            isempty(lbl) || (cache._by_label[lbl] = id)
        end
    end
    # Assign seq to legacy entries (no seq in TOML), ordered by datecached
    sort!(legacy; by = t -> t[5])  # sort by dt
    for (id, lbl, fpath, desc, dt) in legacy
        max_seq += 1
        key = CacheKey(id, max_seq, lbl, fpath, desc, dt)
        cache._index[id] = key
        isempty(lbl) || (cache._by_label[lbl] = id)
    end
    cache._next_seq = max_seq + 1
end

function _save_index(cache::DataCache)
    entries = Dict{String,Any}()
    for (id, key) in cache._index
        entries[id] = Dict{String,Any}(
            "seq"         => key.seq,
            "label"       => key.label,
            "path"        => key.path,
            "description" => key.description,
            "datecached"  => key.datecached == typemin(DateTime) ? "" :
                             Dates.format(key.datecached, "yyyy-mm-ddTHH:MM:SS"),
        )
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
    seq   = cache._next_seq
    cache._next_seq += 1
    fpath = _data_path(cache, id, data)
    _write_file(fpath, data)
    if !isempty(label)
        old = get(cache._by_label, label, nothing)
        isnothing(old) || _remove_entry!(cache, old)
        cache._by_label[label] = id
    end
    key = CacheKey(id, seq, label, fpath, description, Dates.now())
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

The `Integer` form identifies the entry by its stable sequence index (as shown
in `showcache`). Use `reindexcache!` to compact gaps after many deletions.
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
    key = _resolve_by_seq(cache, Int(n))
    isnothing(key) && return cache
    _remove_entry!(cache, key.id)
    _save_index(cache)
    return cache
end

# --- Internal seq/relabel helpers --------------------------------------------

function _resolve_by_seq(cache::DataCache, n::Int)
    for key in values(cache._index)
        key.seq == n && return key
    end
    return nothing
end

function _relabel_by_id!(cache::DataCache, id::String, new_label::AbstractString)
    current = get(cache._index, id, nothing)
    isnothing(current) && error("No cache entry with id $(repr(id))")
    existing_id = get(cache._by_label, new_label, nothing)
    if !isnothing(existing_id) && existing_id != id
        error("Label $(repr(new_label)) is already used by another cache entry")
    end
    isempty(current.label) || delete!(cache._by_label, current.label)
    new_key = CacheKey(id, current.seq, new_label, current.path, current.description, current.datecached)
    cache._index[id] = new_key
    isempty(new_label) || (cache._by_label[new_label] = id)
    _save_index(cache)
    return new_key
end

"""
    relabel!(cache::DataCache, key::CacheKey, new_label::AbstractString) → CacheKey
    relabel!(cache::DataCache, old_label::AbstractString, new_label::AbstractString) → CacheKey
    relabel!(cache::DataCache, n::Integer, new_label::AbstractString) → CacheKey

Rename the label of an existing cache entry without touching its backing data file.

The `CacheKey` overload identifies the entry by its UUID. The `AbstractString`
overload first tries to match `old_label` as an exact label, then falls back to
UUID-prefix matching (same rules as `delete!`). The `Integer` overload identifies
the entry by its stable sequence index (as shown in `showcache`).

Raises an error if `new_label` is already in use by a different entry.
Returns the updated `CacheKey`.
"""
function relabel!(cache::DataCache, key::CacheKey, new_label::AbstractString)
    haskey(cache._index, key.id) || error("CacheKey not found in cache")
    return _relabel_by_id!(cache, key.id, new_label)
end

function relabel!(cache::DataCache, old_label::AbstractString, new_label::AbstractString)
    id = get(cache._by_label, old_label, nothing)
    if isnothing(id)
        matches = [k for k in Base.keys(cache._index) if startswith(k, old_label)]
        if length(matches) == 1
            id = only(matches)
        elseif length(matches) > 1
            error("Ambiguous UUID prefix $(repr(old_label)) matches $(length(matches)) entries")
        else
            error("No cache entry with label $(repr(old_label))")
        end
    end
    return _relabel_by_id!(cache, id, new_label)
end

function relabel!(cache::DataCache, n::Integer, new_label::AbstractString)
    key = _resolve_by_seq(cache, Int(n))
    isnothing(key) && error("No cache entry with index $n")
    return _relabel_by_id!(cache, key.id, new_label)
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
    reindexcache!(cache::DataCache)

Renumber all entries 1..n (sorted by current sequence order), closing gaps
left by deletions. After `reindexcache!`, integer indices in `showcache` output
restart from 1 with no gaps.

Use this after many write/delete cycles to keep index numbers manageable.
"""
function reindexcache!(cache::DataCache)
    sorted = sort(collect(values(cache._index)); by = k -> k.seq)
    for (new_seq, key) in enumerate(sorted)
        new_key = CacheKey(key.id, new_seq, key.label, key.path, key.description, key.datecached)
        cache._index[key.id] = new_key
    end
    cache._next_seq = length(sorted) + 1
    _save_index(cache)
    return cache
end

"""
    showcache(cache::DataCache)

Print a detailed summary of all entries in `cache`.
Equivalent to `show(stdout, MIME"text/plain"(), cache)`.
"""
function showcache(cache::DataCache)
    show(stdout, MIME"text/plain"(), cache)
end

function Base.show(io::IO, cache::DataCache)
    n = length(cache._index)
    print(io, "DataCache(\"$(cache.root)\", $n entr$(n == 1 ? "y" : "ies"))")
end

function Base.show(io::IO, ::MIME"text/plain", cache::DataCache)
    entries = sort(collect(values(cache._index)); by = k -> k.seq)
    if isempty(entries)
        print(io, "DataCache is empty: $(cache.root)")
        return
    end
    n = length(entries)
    seq_width = isempty(entries) ? 1 : ndigits(entries[end].seq)
    println(io, "DataCache: $(cache.root)  ($n entr$(n == 1 ? "y" : "ies"))")
    for (i, key) in enumerate(entries)
        _print_cachekey(io, key, seq_width)
        i < n && println(io)
    end
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

# Internal helpers — not exported

_log_ts() = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")

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

"""
    autocache(fetch_fn, func, endpoint, kwargs; force_refresh::Bool = false)

Integration hook for API clients: transparently apply autocaching around a fetch closure.

If autocache is enabled for `func`, checks the cache for a prior result keyed on
`(func, endpoint, kwargs)`. On a hit (and `force_refresh = false`) returns the cached
value immediately. On a miss, calls `fetch_fn()`, stores the result, and returns it.

If autocache is not active for `func`, calls `fetch_fn()` directly.

# Arguments
- `fetch_fn`:       Zero-argument callable that performs the real fetch.
- `func`:           The public API function whose autocache opt-in is checked.
- `endpoint`:       The API endpoint string (e.g. `"occs/list"`).
- `kwargs`:         Keyword arguments passed by the caller.
- `force_refresh`:  When `true`, bypasses the hit check and overwrites any existing entry.
"""
function autocache(fetch_fn, func, endpoint, kwargs; force_refresh::Bool = false)
    _autocache_active(func) || return fetch_fn()
    _store = _get_autocache_store()
    _ac_key, _ac_desc = _autocache_key(func, endpoint, kwargs)
    if haskey(_store, _ac_key) && !force_refresh
        @debug "$(_log_ts()) autocache: cache hit — $_ac_desc"
        return Base.read(_store, _ac_key)
    end
    @debug "$(_log_ts()) autocache: fetching live — $_ac_desc"
    result = fetch_fn()
    write!(_store, result; label = _ac_key, description = _ac_desc)
    return result
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
                @debug "$(DataCaches._log_ts()) @memcache: cache hit — $($func_name)"
                _memcache_store[_k]
            else
                @debug "$(DataCaches._log_ts()) @memcache: computing live — $($func_name)"
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
                @debug "$(DataCaches._log_ts()) @filecache: cache hit — $($expr_str)"
                Base.read(_c, _lbl)
            else
                @debug "$(DataCaches._log_ts()) @filecache: computing live — $($expr_str)"
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
