
# ---------------------------------------------------------------------------
# LocalStore: general scratch-backed local data store infrastructure
#
# Provides a named, Scratch.jl-managed cache for large remote datasets that
# are expensive to query but change infrequently.  Each store has a URL,
# a local filename, a staleness threshold, and a human-readable description.
#
# Concrete stores (e.g. the PBDB taxa list) are registered at module load
# time via `_register_store!` and populated lazily on first access.
#
# Management functions (_refresh_store!, _delete_store!, _store_info,
# _list_stores) are exposed to users through the DataCurator.Store submodule.
# ---------------------------------------------------------------------------

using Scratch, Downloads

# Package UUID — used to key the Scratch space to PaleobiologyDB.
const _PKG_UUID = Base.UUID("c9cb2f45-518b-476d-9b58-4dd79871b05b")

# ---------------------------------------------------------------------------
# Type
# ---------------------------------------------------------------------------

"""
    LocalStore(name, url, filename, max_age_days, description)

Descriptor for a scratch-backed remote dataset.

Fields
- `name`         — registry key (e.g. `:taxa_list`)
- `url`          — full source URL including any required query parameters
- `filename`     — name of the file saved inside the scratch directory
- `max_age_days` — number of days before the snapshot is considered stale
- `description`  — human-readable label used in log messages
"""
struct LocalStore
    name::Symbol
    url::String
    filename::String
    max_age_days::Int
    description::String
end

# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------

const _REGISTERED_STORES = Dict{Symbol, LocalStore}()

function _register_store!(store::LocalStore)
    _REGISTERED_STORES[store.name] = store
end

function _get_store(name::Symbol)
    haskey(_REGISTERED_STORES, name) ||
        error("Unknown local store: :$name.  " *
              "Registered stores: $(join(keys(_REGISTERED_STORES), ", "))")
    _REGISTERED_STORES[name]
end

# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

"""Return (and create if necessary) the shared scratch directory."""
function _curator_scratch_dir()
    Scratch.get_scratch!(_PKG_UUID, "curator_data")
end

"""Absolute path to the local file for `store`."""
function _store_path(store::LocalStore)
    joinpath(_curator_scratch_dir(), store.filename)
end

# ---------------------------------------------------------------------------
# Freshness
# ---------------------------------------------------------------------------

function _is_fresh(store::LocalStore)
    path = _store_path(store)
    isfile(path) && (time() - mtime(path)) < store.max_age_days * 86400
end

# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------

function _download_store!(store::LocalStore)
    path = _store_path(store)
    dir  = dirname(path)
    isdir(dir) || mkpath(dir)

    @info "$(store.description): starting download" url=store.url

    last_logged = Ref(time())
    tmp = path * ".download"

    try
        Downloads.download(
            store.url, tmp;
            progress = (total, now) -> begin
                now > 0 || return
                time() - last_logged[] >= 2.0 || return
                mb_n = round(now / 1e6; digits = 1)
                if total > 0
                    pct  = round(100 * now / total; digits = 1)
                    mb_t = round(total / 1e6; digits = 1)
                    @info "$(store.description): $mb_n / $mb_t MB ($pct%)"
                else
                    @info "$(store.description): $mb_n MB received"
                end
                last_logged[] = time()
            end,
        )
        mv(tmp, path; force = true)
        mb = round(stat(path).size / 1e6; digits = 1)
        @info "$(store.description): download complete" size_mb=mb path=path
    catch
        isfile(tmp) && rm(tmp; force = true)
        rethrow()
    end
end

# ---------------------------------------------------------------------------
# Ensure populated (lazy, called internally before any lookup)
# ---------------------------------------------------------------------------

function _ensure_populated!(store::LocalStore; force::Bool = false)
    if force || !_is_fresh(store)
        _download_store!(store)
    end
end

# ---------------------------------------------------------------------------
# Management functions (surfaced via DataCurator.Store submodule)
# ---------------------------------------------------------------------------

function _refresh_store!(name::Symbol; force::Bool = true)
    _ensure_populated!(_get_store(name); force = force)
end

function _delete_store!(name::Symbol)
    store = _get_store(name)
    path  = _store_path(store)
    if isfile(path)
        rm(path)
        @info "$(store.description): local snapshot deleted." path=path
    else
        @info "$(store.description): no local snapshot found." path=path
    end
end

"""
Return a NamedTuple with metadata about the named store.

Fields: `name`, `description`, `path`, `exists`, `size_mb`, `age_days`,
`max_age_days`, `is_fresh`.
"""
function _store_info(name::Symbol)
    store    = _get_store(name)
    path     = _store_path(store)
    exists   = isfile(path)
    size_mb  = exists ? round(stat(path).size / 1e6; digits = 2) : nothing
    age_days = exists ? round((time() - mtime(path)) / 86400; digits = 1) : nothing
    fresh    = exists && _is_fresh(store)
    (
        name         = name,
        description  = store.description,
        path         = path,
        exists       = exists,
        size_mb      = size_mb,
        age_days     = age_days,
        max_age_days = store.max_age_days,
        is_fresh     = fresh,
    )
end

"""Return a vector of info NamedTuples for all registered stores."""
function _list_stores()
    [_store_info(k) for k in sort!(collect(keys(_REGISTERED_STORES)))]
end
