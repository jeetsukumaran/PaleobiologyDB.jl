# Caching

PBDB queries make HTTP requests that can be slow or rate-limited.
PaleobiologyDB.jl provides three complementary caching mechanisms via
the re-exported [DataCaches.jl](https://github.com/jeetsukumaran/DataCaches.jl) package.

## `DataCache` — labeled file store

A `DataCache` is a named key-value store backed by files on disk.
Results survive Julia restarts and can be retrieved by a human-readable label.

```julia
using PaleobiologyDB
using PaleobiologyDB.DataCaches

cache = DataCache()                          # lifecycle-managed default store (~/.julia/scratchspaces/…)
cache = DataCache(:myproject)               # named lifecycle-managed store
cache = DataCache("/my/project/pbdb_cache")  # explicit path, portable/shareable

# Store
occs = pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")
key  = write!(cache, occs; label = "Canidae Miocene occurrences")
cache["Carnivora families"] = pbdb_taxa(name = "Carnivora", rel = "children")

# Retrieve
occs = read(cache, "Canidae Miocene occurrences")
occs = cache["Canidae Miocene occurrences"]
occs = cache[key]
occs = cache[1]                             # by sequence number (shown in showcache output)

# Inspect
keys(cache)        # → Vector{CacheKey}
keylabels(cache)   # → Vector{String}
showcache(cache)   # pretty-printed table

# Manage
relabel!(cache, "Canidae Miocene occurrences", "canidae-miocene")
relabel!(cache, 1, "canidae-miocene")       # by sequence number
delete!(cache, "Canidae Miocene occurrences")
delete!(cache, 1)                           # by sequence number
reindexcache!(cache)                        # compact gaps left by deletions
clear!(cache)
```

`DataFrame` values are stored as CSV; any other Julia value uses `Serialization`.

## `@filecache` — transparent file-based memoization

`@filecache` wraps any function call: the first call fetches and stores the result;
every subsequent call with the same arguments loads it from disk without touching the network.

```julia
# Uses the lifecycle-managed default cache (~/.julia/scratchspaces/…)
occs = @filecache pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")

# Use a specific DataCache
my_cache = DataCache("/data/pbdb_cache")
taxa = @filecache my_cache pbdb_taxa(name = "Carnivora", rel = "children")

# Inspect/manage the default cache
showcache(PaleobiologyDB.default_filecache())
clear!(PaleobiologyDB.default_filecache())

# Point the default at a different cache
PaleobiologyDB.set_default_filecache!(DataCache("/project/cache"))
```

## `set_autocaching!` — global automatic caching

`set_autocaching!` enables transparent caching on every API call without requiring
`@filecache` wrappers.

```julia
using PaleobiologyDB
using PaleobiologyDB.DataCaches

# Enable for ALL pbdb_* functions
DataCaches.set_autocaching!(true)

occs = pbdb_occurrences(base_name = "Canidae", interval = "Miocene")  # live fetch + cached
occs = pbdb_occurrences(base_name = "Canidae", interval = "Miocene")  # instant cache hit

# Disable
DataCaches.set_autocaching!(false)
```

**Per-function control:**

```julia
# Cache only occurrence queries
DataCaches.set_autocaching!(true, pbdb_occurrences)

# Cache occurrences and taxa
DataCaches.set_autocaching!(true, [pbdb_occurrences, pbdb_taxa])

# Remove a function from the autocache list
DataCaches.set_autocaching!(false, pbdb_occurrences)
```

**Custom cache store:**

```julia
my_cache = DataCache("/data/project_cache")
DataCaches.set_autocaching!(true; cache = my_cache)
DataCaches.set_autocaching!(true, pbdb_occurrences; cache = my_cache)
```

Using `@filecache` explicitly while autocache is on is safe — autocache is suppressed
for that call so the result is written exactly once.

## `@memcache` — in-memory session memoization

`@memcache` caches results in RAM for the duration of the current Julia session.
No files are written; the cache is lost when Julia exits.

```julia
occs = @memcache pbdb_occurrences(base_name = "Canidae", show = "full")
taxa = @memcache pbdb_taxa(name = "Dinosauria")

PaleobiologyDB.memcache_clear!()   # discard all in-memory cached results
```
