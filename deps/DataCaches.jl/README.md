# DataCaches.jl

A lightweight, file-backed key-value cache for Julia — designed for workflows
that make expensive function calls (remote API queries, long-running computations)
and need results to survive across Julia sessions.

Three levels of caching are provided, from manual to fully automatic:

| Level | Mechanism | Persistence | Library integration required? |
|---|---|---|---|
| Explicit | `dc["label"] = result` | Across sessions | No |
| Memoized | `@filecache`, `@memcache` | Across sessions / in-session | No |
| Automatic | `setautocache!` | Across sessions | Yes (or thin wrapper) |

---

## Installation

```julia
] add DataCaches
```

---

## Quick Start

```julia
using DataCaches

# Create a cache backed by a directory on disk
dc = DataCache(joinpath(homedir(), ".datacaches", "myproject"))

# Store and retrieve a result by label
dc["dinosaurs"] = pbdb_occurrences(base_name = "Dinosauria", show = "full")
df = dc["dinosaurs"]
```

---

## Usage Patterns

### Pattern 1 — Explicit label assignment

The most transparent pattern. You control exactly what is stored and when it is
retrieved, using dictionary-style indexing. Works with any data source.

```julia
using DataCaches, PaleobiologyDB

dc = DataCache(joinpath(homedir(), ".datacaches", "project1"))

# Store
dc["canidae_occs"]  = pbdb_occurrences(base_name = "Canidae", show = "full")
dc["dinosaur_taxa"] = pbdb_taxa(name = "Dinosauria", vocab = "pbdb")

# Retrieve
occs = dc["canidae_occs"]
taxa = dc["dinosaur_taxa"]

# Conditionally fetch
if !haskey(dc, "trilobites")
    dc["trilobites"] = pbdb_occurrences(base_name = "Trilobita")
end
df = dc["trilobites"]
```

Manage the store:

```julia
# Overwrite an existing label
dc["canidae_occs"] = pbdb_occurrences(base_name = "Canidae", show = "coords")

# Summarize contents
showcache(dc)
# DataCache: /home/user/.datacaches/project1  (3 entries)
#   [1]  2025-08-25T14:23:01  2a9d4a87  canidae_occs
#                                        /home/user/.datacaches/project1/2a9d4a87-....csv
#   ...

# Rename a label
relabel!(dc, "canidae_occs", "canidae")   # by label
relabel!(dc, 2, "canidae")                # by sequence index

# Remove entries
delete!(dc, "trilobites")   # by label
delete!(dc, 2)              # by sequence index
clear!(dc)                  # remove all entries

# Compact sequence numbers after many deletions
reindexcache!(dc)
```

### Pattern 2 — Memoized function calls

`@filecache` and `@memcache` wrap a single function call expression and cache
its result automatically, keyed on the runtime values of all arguments. If the
same call appears again (even in a new session, for `@filecache`), the cached
result is returned immediately without re-executing the function.

These macros are generic: they work with any function from any library, with no
integration required on the library's part.

#### `@filecache` — persist across Julia sessions

```julia
using DataCaches, PaleobiologyDB

dc = DataCache(joinpath(homedir(), ".datacaches", "project1"))
set_default_filecache!(dc)

# First call: runs the query and stores the result
occs = @filecache pbdb_occurrences(base_name = "Canidae", show = "full")

# Subsequent calls (same or new session): returns from disk immediately
occs = @filecache pbdb_occurrences(base_name = "Canidae", show = "full")
```

Pass an explicit cache as the first argument to target a specific store
without changing the global default:

```julia
project_cache = DataCache("/data/research/pbdb_cache")
occs = @filecache project_cache pbdb_occurrences(base_name = "Canidae")
taxa = @filecache project_cache pbdb_taxa(name = "Dinosauria")
```

Since `@filecache` is generic, it works equally well with any third-party library:

```julia
using DataCaches, GBIF2

dc = DataCache(joinpath(homedir(), ".datacaches", "biodiversity"))
set_default_filecache!(dc)

occs = @filecache GBIF2.occurrence_search(taxonKey = 212, limit = 300)
# Next session: same call returns from disk, no network request
```

#### `@memcache` — deduplicate within a session

`@memcache` is the in-process equivalent: results live in memory for the
duration of the Julia session and are discarded when the process exits.
Useful for avoiding redundant calls within a notebook or long script.

```julia
occs = @memcache pbdb_occurrences(base_name = "Canidae", show = "full")
taxa = @memcache pbdb_taxa(name = "Canis")

memcache_clear!()   # discard all in-memory results
```

### Pattern 3 — Automatic caching

`setautocache!` installs a global hook that intercepts every call to an
instrumented function and transparently caches the result. Existing call sites
require no modification.

**This pattern requires the library to integrate DataCaches.jl** by calling the
`autocache` hook function internally (see [Integration API](#integration-api-for-library-authors)).
For libraries that have not done this, Pattern 2 (`@filecache`) is the practical
alternative — or you can write a thin wrapper yourself (shown below).

#### With a natively integrated library (e.g. PaleobiologyDB.jl)

```julia
using DataCaches, PaleobiologyDB

dc = DataCache(joinpath(homedir(), ".datacaches", "project1"))
setautocache!(true; cache = dc)

# All pbdb_* calls now cache automatically — no changes to call sites
occs  = pbdb_occurrences(base_name = "Canidae")           # fetches + stores
occs2 = pbdb_occurrences(base_name = "Canidae")           # instant, from cache
taxa  = pbdb_taxa(name = "Dinosauria", vocab = "pbdb")    # fetches + stores

setautocache!(false)
```

Enable caching for specific functions only:

```julia
setautocache!(true, pbdb_occurrences; cache = dc)         # only this function
setautocache!(true, pbdb_taxa; cache = dc)                # add another
setautocache!(false, pbdb_occurrences)                    # remove one
setautocache!(false)                                      # disable entirely

# Multiple functions at once
setautocache!(true, [pbdb_occurrences, pbdb_taxa, pbdb_collections]; cache = dc)
```

#### With any third-party library — thin wrapper approach

For a library that has not integrated DataCaches.jl, write a one-time thin
wrapper that calls the `autocache` hook. The wrapper is a drop-in replacement
for the original function, and from that point on the full `setautocache!`
interface works as normal.

```julia
using DataCaches, GBIF2
import DataCaches: autocache

# One-time wrapper — mirrors the signature of the original function
function gbif_occurrence_search(; kwargs...)
    return autocache(
        () -> GBIF2.occurrence_search(; kwargs...),
        gbif_occurrence_search,
        "occurrence/search",
        kwargs,
    )
end

# Now use the wrapper exactly like a natively integrated function
dc = DataCache(joinpath(homedir(), ".datacaches", "biodiversity"))
setautocache!(true; cache = dc)

occs  = gbif_occurrence_search(taxonKey = 212, limit = 300)  # fetches + stores
occs2 = gbif_occurrence_search(taxonKey = 212, limit = 300)  # from cache
taxa  = gbif_occurrence_search(taxonKey = 5219857)           # fetches + stores

setautocache!(false)
```

The wrapper body has three moving parts:

| Argument | Purpose | What to put here |
|---|---|---|
| `() -> ...` | The real fetch, as a closure | Call the original function |
| `gbif_occurrence_search` | Identity for the autocache allowlist | Your wrapper function itself |
| `"occurrence/search"` | Endpoint string (part of cache key) | Any stable string identifying the resource |
| `kwargs` | Argument values (part of cache key) | Pass through from the wrapper |

---

## DataCache API Reference

### Construction

```julia
DataCache()                                           # default directory
DataCache(joinpath(homedir(), ".datacaches", "p1"))  # explicit directory
```

The directory is created if it does not exist. An index file
(`cache_index.toml`) and data files (`.csv` for `DataFrame` values,
`.jls` for everything else) are written there.

A `DataCache` constructed from the same directory in a new Julia session
automatically reloads all previously saved entries.

### Write

```julia
key = write!(dc, data)
key = write!(dc, data; label = "my label")
key = write!(dc, data; label = "q1", description = "query for paper §3")
dc["my label"] = data                  # setindex! sugar (label required)
```

`write!` returns a `CacheKey`. If `label` is given and an entry with that
label already exists, the old entry (and its backing file) is silently
replaced.

`DataFrame` values are stored as CSV. All other values are serialized with
Julia's `Serialization` standard library.

### Read

```julia
data = read(dc, key)          # by CacheKey
data = read(dc, "my label")   # by label string
data = dc["my label"]         # getindex sugar
data = dc[key]
```

### Introspection

```julia
haskey(dc, "my label")  # → Bool
haskey(dc, key)         # → Bool
length(dc)              # → Int
isempty(dc)             # → Bool

keys(dc)                # → Vector{CacheKey}
keylabels(dc)           # → Vector{String}
keypaths(dc)            # → Vector{String}

label(dc, key)          # → String  (same as key.label)
path(dc, key)           # → String  (same as key.path)

showcache(dc)           # prints a summary table to stdout
```

### Delete

```julia
delete!(dc, key)          # by CacheKey
delete!(dc, "my label")   # by label
delete!(dc, "2a9d4a87")   # by UUID prefix (shown by showcache)
delete!(dc, 3)            # by sequence index (shown by showcache)
clear!(dc)                # remove all entries
```

### Relabel

Rename a label without touching the backing data file.

```julia
relabel!(dc, "old label", "new label")   # by label
relabel!(dc, key, "new label")           # by CacheKey
relabel!(dc, 3, "new label")             # by sequence index
```

### Reindex

After many write/delete cycles, sequence numbers can grow large. `reindexcache!`
renumbers all entries 1..n (in existing sequence order), closing all gaps.

```julia
reindexcache!(dc)
```

---

## CacheKey

`write!` returns a `CacheKey` struct with six fields:

| Field | Type | Description |
|---|---|---|
| `id` | `String` | UUID (unique per write) |
| `seq` | `Int` | Stable integer index; survives reloads; use `reindexcache!` to compact gaps |
| `label` | `String` | User-provided label, or `""` |
| `path` | `String` | Absolute path to the backing file |
| `description` | `String` | Human-readable annotation, or `""` |
| `datecached` | `DateTime` | Timestamp of last write |

`CacheKey` objects can be passed directly to `read`, `delete!`, `relabel!`, and `haskey`.

---

## Default file cache and global state

```julia
# Get or lazily create the module-level default DataCache
dc = default_filecache()

# Replace it with a specific store
set_default_filecache!(DataCache("/my/project/cache"))

# @filecache uses default_filecache() when no cache is given
occs = @filecache pbdb_occurrences(base_name = "Canidae")
```

---

## Macro reference

### `@filecache [cache] expr`

Cache `expr` (a function call) to disk. Persists across Julia sessions.
The cache key is the hash of the function name and all argument values.

```julia
# Uses default_filecache()
result = @filecache some_expensive_call(arg1, kwarg = val)

# Uses an explicit DataCache
result = @filecache my_cache some_expensive_call(arg1, kwarg = val)
```

### `@memcache expr`

Cache `expr` in memory for the current session only.

```julia
result = @memcache some_expensive_call(arg1, kwarg = val)
memcache_clear!()   # discard all in-memory results
```

---

## Integration API for library authors

To give your library's users the full `setautocache!` interface, call
`autocache` inside each query function you want to instrument:

```julia
import DataCaches: autocache

function my_api_query(endpoint; kwargs...)
    return autocache(
        () -> _do_actual_http_fetch(endpoint; kwargs...),
        my_api_query,
        endpoint,
        kwargs,
    )
end
```

`autocache` signature:

```julia
autocache(fetch_fn, func, endpoint, kwargs; force_refresh::Bool = false)
```

| Argument | Description |
|---|---|
| `fetch_fn` | Zero-argument callable that performs the real fetch |
| `func` | The public function whose autocache opt-in status is checked |
| `endpoint` | String identifying the resource (used as part of the cache key) |
| `kwargs` | The caller's keyword arguments (used as part of the cache key) |
| `force_refresh` | When `true`, bypasses a cache hit and overwrites the stored result |

If autocache is not active for `func`, `fetch_fn()` is called directly
with no overhead.

---

## Comparison of caching strategies

| | `dc["label"] = ...` | `@filecache` | `@memcache` | `setautocache!` |
|---|---|---|---|---|
| Persists across sessions | Yes | Yes | No | Yes |
| Works with any library | Yes | Yes | Yes | Only if integrated (or wrapped) |
| Changes call sites | Yes | Yes | Yes | No |
| Label is human-readable | Yes | Hash | Hash | Hash |
| Force re-fetch | Overwrite by label | Overwrite by label | `memcache_clear!` | `force_refresh = true` |
| Granularity | Any | Per macro site | Per macro site | Per function |

---

## Environment variable

| Variable | Default | Description |
|---|---|---|
| `DATACACHES_CACHE_DIR` | `~/.cache/DataCaches` | Root directory used by `DataCache()` (no-argument constructor) |
