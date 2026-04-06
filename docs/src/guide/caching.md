# Caching

PBDB queries make HTTP requests that can be slow or rate-limited.
PaleobiologyDB.jl provides three complementary caching mechanisms via
the re-exported [DataCaches.jl](https://github.com/jeetsukumaran/DataCaches.jl) package.

## `set_autocaching!` — global automatic caching

`set_autocaching!` enables transparent caching on every API call without requiring
`@filecache` wrappers.

```julia
using PaleobiologyDB

# Enable for ALL pbdb_* functions
PaleobiologyDB.set_autocaching!(true)

occs = pbdb_occurrences(base_name = "Canidae", interval = "Miocene")  # live fetch + cached
occs = pbdb_occurrences(base_name = "Canidae", interval = "Miocene")  # instant cache hit

# Disable
PaleobiologyDB.set_autocaching!(false)
```

**Per-function control:**

```julia
# Cache only occurrence queries
PaleobiologyDB.set_autocaching!(true, pbdb_occurrences)

# Cache occurrences and taxa
PaleobiologyDB.set_autocaching!(true, [pbdb_occurrences, pbdb_taxa])

# Remove a function from the autocache list
PaleobiologyDB.set_autocaching!(false, pbdb_occurrences)
```

**Custom cache store:**

```julia
using DataCaches  
my_cache = DataCache(joinpath(homedir(), "Downloads", "dat"))
set_autocaching!(true; cache = my_cache)
# ...
# ...
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
