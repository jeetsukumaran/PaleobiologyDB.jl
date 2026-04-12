# ---------------------------------------------------------------------------
# PhyloPicDB — build number management
#
# The PhyloPic API versions all responses by a discrete "build" index.
# Callers that pass `build=nothing` to any API function get the current build
# fetched automatically (with a 1-hour TTL cache, thread-safe).
#
# Public API:
#   fetch_current_build(; force) → Int
#   ensure_build(build; force)   → Int
# ---------------------------------------------------------------------------

"How long (in seconds) to reuse a cached build number before re-fetching."
const BUILD_TTL = 3600.0

# Thread-safe module-level build cache.
const _BUILD_LOCK  = ReentrantLock()
const _BUILD_CACHE = Ref{Union{Nothing, Int}}(nothing)
const _BUILD_TIME  = Ref{Float64}(0.0)

"""
    fetch_current_build(; force = false) -> Int

Return the current PhyloPic build index.

The result is cached in memory with a TTL of [`BUILD_TTL`](@ref) seconds
(default one hour).  Concurrent callers share the same cached value — the
underlying HTTP request is made at most once per TTL window regardless of
how many threads call this function simultaneously.

# Arguments

- `force`: if `true`, bypass the cache and unconditionally re-fetch the build
  number from the API.  Default `false`.

# Returns

The current build index as an `Int`.

# Throws

Propagates any network error raised by the underlying `phylopic_get` call.

# Examples

```julia
build = fetch_current_build()   # fetches from API on first call
build2 = fetch_current_build()  # returns cached value
build3 = fetch_current_build(; force = true)  # forces a new request
```
"""
function fetch_current_build(; force::Bool = false)::Int
    lock(_BUILD_LOCK) do
        expired = (time() - _BUILD_TIME[]) > BUILD_TTL
        if isnothing(_BUILD_CACHE[]) || expired || force
            resp = phylopic_get(PHYLOPIC_BASE_URL)
            obj  = JSON3.read(resp.body)
            _BUILD_CACHE[] = Int(obj.build)
            _BUILD_TIME[]  = time()
        end
        return _BUILD_CACHE[]
    end
end

"""
    ensure_build(build; force = false) -> Int

Return `build` if it is not `nothing`; otherwise call
[`fetch_current_build`](@ref).

This is the canonical entry point used by all API functions that accept an
optional `build` parameter.  It lets callers avoid redundant build fetches
by passing a previously obtained build index, while defaulting to automatic
fetching when `nothing` is passed.

# Arguments

- `build`: an explicit build index, or `nothing` to fetch automatically.
- `force`: forwarded to [`fetch_current_build`](@ref) when `build` is
  `nothing`.  Default `false`.

# Returns

An `Int` build index.

# Examples

```julia
ensure_build(537)      # → 537  (no network call)
ensure_build(nothing)  # → fetch_current_build()
```
"""
function ensure_build(build::Union{Int, Nothing}; force::Bool = false)::Int
    isnothing(build) ? fetch_current_build(; force = force) : build
end
