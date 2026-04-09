# Caching

PBDB queries make HTTP requests that can be slow or rate-limited.
PaleobiologyDB.jl provides three complementary caching mechanisms via
the re-exported [DataCaches.jl](https://github.com/jeetsukumaran/DataCaches.jl) package.

## `set_autocaching!` — global automatic caching

`set_autocaching!` enables transparent caching on every API call without requiring
`@filecache` wrappers.

```julia
using PaleobiologyDB

# Enable for ALL autocache-enabled functions
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

## Autocache-enabled functions

All 29 PBDB API functions and the two PhyloPic enrichment functions support
`set_autocaching!`.  Pass the function itself as the second argument to target
a specific function, or omit it to affect all of them at once.

### PBDB API functions

Each function caches by its endpoint path plus the full set of keyword arguments.

| Category | Functions |
|----------|-----------|
| Occurrences | `pbdb_occurrence`, `pbdb_occurrences`, `pbdb_ref_occurrences` |
| Collections | `pbdb_collection`, `pbdb_collections`, `pbdb_collections_geo`, `pbdb_ref_collections` |
| Taxa | `pbdb_taxon`, `pbdb_taxa`, `pbdb_taxa_auto`, `pbdb_ref_taxa`, `pbdb_opinions_taxa` |
| Intervals | `pbdb_interval`, `pbdb_intervals` |
| Scales | `pbdb_scale`, `pbdb_scales` |
| Strata | `pbdb_strata`, `pbdb_strata_auto` |
| References | `pbdb_reference`, `pbdb_references` |
| Specimens | `pbdb_specimen`, `pbdb_specimens`, `pbdb_ref_specimens`, `pbdb_measurements` |
| Opinions | `pbdb_opinion`, `pbdb_opinions` |
| Config | `pbdb_config` |

### PhyloPic enrichment functions

`acquire_phylopic` and `augment_phylopic` (from `PaleobiologyDB.Taxonomy`) are also
autocache-enabled.  The cache operates at the **per-taxon-name** level rather than
the whole-DataFrame level: each unique taxon name is cached independently, keyed on
`(taxon_name, phylopic_build)`.

This means two DataFrames that share taxa produce zero redundant network requests on
the second call, regardless of how many rows they have or how the rows are ordered.

**Important:** both `acquire_phylopic` and `augment_phylopic` are controlled through
the same `acquire_phylopic` function reference, because the per-taxon cache is wired
inside the shared internal pipeline.  To enable caching for either or both, pass
`acquire_phylopic`:

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy

# Enable per-taxon caching for all PhyloPic lookups
PaleobiologyDB.set_autocaching!(true, acquire_phylopic)

# String variant — fetches once, cached by (taxon_name, build)
rec1 = acquire_phylopic("Tyrannosaurus")
rec2 = acquire_phylopic("Tyrannosaurus")   # instant cache hit
@assert rec1 == rec2

# DataFrame variant — unique taxa shared across DataFrames
df1 = pbdb_occurrences(base_name = "Tyrannosauridae", limit = 50)
df2 = pbdb_occurrences(base_name = "Tyrannosauridae", limit = 100)

pics1 = acquire_phylopic(df1)   # fetches each unique taxon, caches results
pics2 = acquire_phylopic(df2)   # all taxa already cached — no new requests

# augment_phylopic benefits automatically (calls acquire_phylopic internally)
enriched = augment_phylopic(df1)   # all lookups are cache hits

PaleobiologyDB.set_autocaching!(false, acquire_phylopic)
```

Note: `set_autocaching!(true, augment_phylopic)` alone has **no effect** on the
per-taxon cache, because the cache is keyed on `acquire_phylopic`.  Always use
`acquire_phylopic` as the function reference when targeting PhyloPic caching.
