# PaleobiologyDB


[![CI](https://github.com/jeetsukumaran/PaleobiologyDB.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/jeetsukumaran/PaleobiologyDB.jl/actions/workflows/CI.yml)
[![Documentation (stable)](https://img.shields.io/badge/docs-stable-blue.svg)](https://jeetsukumaran.github.io/PaleobiologyDB.jl/stable)
[![Documentation (dev)](https://img.shields.io/badge/docs-dev-blue.svg)](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev)



A Julia interface to the [Paleobiology Database](https://paleobiodb.org/) (PBDB) Web API.

## Overview

PaleobiologyDB.jl provides a Julia interface to query the Paleobiology Database.
Results are returned as `DataFrame`s.

## Installation

At the Julia REPL, type "`]`" to drop into Package manager mode and then type:

```
pkg> add PaleobiologyDB
```

Or, either in the Julia REPL or a script:

```julia
using Pkg
Pkg.add("PaleobiologyDB")
```

Or, if you want the latest development version from the source repository:

```julia
using Pkg
Pkg.add(url = "https://github.com/JuliaData/DataCaches.jl")
Pkg.add(url = "https://github.com/jeetsukumaran/PaleobiologyDB.jl")
```

## Quick start

```julia
using PaleobiologyDB

canids = pbdb_occurrences(
    base_name = "Canidae",
    interval = "Miocene",
    show = "full",
    extids = true,
    limit = 100
)



# Get fossil occurrences
canids = pbdb_occurrences(
    base_name = "Canidae",
    interval = "Miocene",
    show = ["coords", "class"],
    extids = true,
)

# Get taxonomic information
canis_info = pbdb_taxon(
    name = "Canis",
    extids = true,
    show = ["attr", "app", "size"]
)

# Get a specific collection
collection = pbdb_collection(
    "col:1003",
    show = ["loc", "stratext"],
    extids = true,
)
# old-style numeric-only id
collection = pbdb_collection(
    1003,
    show = ["loc", "stratext"],
    # extids = false,
)
```

## Documentation

[This README](https://github.com/jeetsukumaran/PaleobiologyDB.jl/blob/main/README.md) provides a concise summary of installation and usage, while the more thorough [package API documentation](https://jeetsukumaran.github.io/PaleobiologyDB.jl/) can be found here: <https://jeetsukumaran.github.io/PaleobiologyDB.jl/>.

## The PBDB/PaleobiologyDB.jl interface

Every "endpoint" of the PBDB data service API corresponds to a function in the PaleobiologyDB.jl package: calling this function with the API endpoint parameters returns a `DataFrame` with the response.

As with the interface, the entire package is richly documented, from the module:

```
help?> PaleobiologyDB
search: PaleobiologyDB

  PaleobiologyDB

  A Julia interface to the Paleobiology Database (PBDB) Web API.

  This package provides functions to query the PBDB API for fossil occurrences, taxonomic information, collections, specimens, and other paleobiological data.

  Examples
  ≡≡≡≡≡≡≡≡

  using PaleobiologyDB

  # Get occurrences for Canidae
  occs = pbdb_occurrences(
      base_name = "Canidae",
      extids = true,
      show = "full",
  )
  occs = pbdb_occurrences(
      base_name = "Canidae",
      show = ["coords", "classext"],
  )
```

down to the functions:

```
help?> pbdb_occurrences
search: pbdb_occurrences pbdb_occurrence pbdb_ref_occurrences pbdb_references pbdb_reference fetch_occurrences_pbdb collection_occurrences pbdb_measurements pbdb_specimens pbdb_scales occurrences_df pbdb_opinions

  pbdb_occurrences(; kwargs...)

  Get information about fossil occurrence records stored in the Paleobiology Database.

  Arguments
  ≡≡≡≡≡≡≡≡≡

    •  kwargs...: Filtering and output parameters. Common options include:
       • limit: Maximum number of records to return (Int or "all").
       • taxon_name: Return only records with the specified taxonomic name(s).
       • base_name: Return records for the specified name(s) and all descendant taxa.
       • lngmin, lngmax, latmin, latmax: Geographic bounding box.
       • min_ma, max_ma: Minimum and maximum age in millions of years.
       • interval: Named geologic interval (e.g. "Miocene").
       • cc: Country/continent codes (ISO two-letter or three-letter).
       • show: Extra information blocks ("coords", "classext", "ident", etc.). show = "full" for everything.
       • extids: Set extids = true to show the newer string identifiers.
       • vocab: Vocabulary for field names ("pbdb" for full names, "com" for short codes).

  Returns
  ≡≡≡≡≡≡≡

  A DataFrame with fossil occurrence records matching the query.

  Examples
  ≡≡≡≡≡≡≡≡


  # `taxon_name` retrieves *only* units of this rank
  occs = pbdb_occurrences(
      taxon_name = "Canis",
      show = ["full", "ident"], # all columns
      limit = 100,
  )

  # `base_name` retrieves units of this and nested rank
  occs = pbdb_occurrences(
      base_name = "Canis",
      show = ["coords", "classext"],
      limit = 100,
  )
```

## Basic endpoint querying examples

### Fossil occurrences

```julia
# Simple occurrence query
occs = pbdb_occurrences(base_name = "Mammalia", limit = 10)

# Specific occurrence
single_occ = pbdb_occurrence("occ:1001", show = "full")
# old-style numeric-only id
single_occ = pbdb_occurrence(1001, show = "full")

# Geographic and temporal filtering
pliocene_mammals = pbdb_occurrences(
    base_name = "Mammalia",
    interval = "Pliocene",
    lngmin = -130.0, lngmax = -60.0,
    latmin = 25.0, latmax = 70.0,
    show = ["coords", "classext", "stratext"],
)
```

### Taxonomic data

```julia
mammalia = pbdb_taxon(name = "Mammalia", show = ["attr", "size"])

carnivores = pbdb_taxa(
    name = "Carnivora",
    rel = "children",
    show = ["attr", "app"]
)

suggestions = pbdb_taxa_auto(name = "Cani", limit = 10)
```

### Collections and geography

```julia
european_collections = pbdb_collections(
    lngmin = -10.0, lngmax = 40.0,
    latmin = 35.0, latmax = 65.0,
    interval = "Cenozoic"
)

clusters = pbdb_collections_geo(
    level = 2,
    lngmin = 0.0, lngmax = 15.0,
    latmin = 45.0, latmax = 55.0
)
```

### Specimens and measurements

```julia
whale_specimens = pbdb_specimens(
    base_name = "Cetacea",
    interval = "Miocene",
)

measurements = pbdb_measurements(
    spec_id = ["spm:1505", "spm:30050"],
    show = ["spec", "methods"],
)
measurements = pbdb_measurements(
    spec_id = [1505, 30050],
    show = ["spec", "methods"],
)
```

## Caching query results

PBDB queries make HTTP requests that can be slow or rate-limited.
PaleobiologyDB.jl provides two complementary caching mechanisms.

### `DataCache` — labeled file store

A `DataCache` is a named key-value store backed by files on disk.
Results survive Julia restarts and can be retrieved by a human-readable
label or by the `CacheKey` returned when writing.

```julia
using PaleobiologyDB
using PaleobiologyDB.DataCaches

cache = default_filecache()     # default $PBDB_CACHE_DIR or '~/.cache/PaleobiologyDB/'
cache = DataCache()             # default $PBDB_CACHE_DIR or '~/.cache/PaleobiologyDB/'
cache = DataCache("/my/project/pbdb_cache")  # custom path (or set PBDB_CACHE_DIR env var)

# --- store ---
occs  = pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")
key   = write!(cache, occs; label = "Canidae Miocene occurrences")
cache["Carnivora families"] = pbdb_taxa(name = "Carnivora", rel = "children")

# --- retrieve ---
occs  = read(cache, "Canidae Miocene occurrences")
occs  = cache["Canidae Miocene occurrences"]
occs  = cache[key]                           # by CacheKey

# --- inspect ---
keys(cache)        # → Vector{CacheKey}
keylabels(cache)   # → Vector{String}
keypaths(cache)    # → Vector{String}
describe(cache)  # pretty-printed table

# --- manage ---
delete!(cache, "Canidae Miocene occurrences")
clear!(cache)
```

`DataFrame` values are stored as CSV; any other Julia value uses
`Serialization`. An index file (`cache_index.toml`) in the cache directory
tracks all entries and is reloaded automatically on the next `DataCache(root)`.

### `@filecache` — transparent file-based memoization

`@filecache` wraps any function call: the first call fetches and stores the
result; every subsequent call with the same arguments loads it from disk
without touching the network.

```julia
# Uses the module-level default cache (~/.cache/PaleobiologyDB/)
occs = @filecache pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")

# Use a specific DataCache
my_cache = DataCache("/data/pbdb_cache")
taxa = @filecache my_cache pbdb_taxa(name = "Carnivora", rel = "children")

# Inspect / manage the default cache
describe(PaleobiologyDB.default_filecache())
clear!(PaleobiologyDB.default_filecache())

# Point the default at a different cache
PaleobiologyDB.set_default_filecache!(DataCache("/project/cache"))
```

### `setautocache!` — global automatic caching

`setautocache!` enables transparent caching on every API call without
requiring `@filecache` wrappers. When active, all `pbdb_*` functions
automatically check the cache before making an HTTP request and store
the result after a live fetch.

```julia
using PaleobiologyDB
using PaleobiologyDB.DataCaches

# Enable autocache for ALL pbdb_* functions (uses default cache)
DataCaches.setautocache!(true)

occs = pbdb_occurrences(base_name = "Canidae", interval = "Miocene")  # live fetch + cached
occs = pbdb_occurrences(base_name = "Canidae", interval = "Miocene")  # instant cache hit

# Disable
DataCaches.setautocache!(false)
occs = pbdb_occurrences(base_name = "Canidae", interval = "Miocene")  # live fetch again
```

**Per-function control** — enable autocache for specific functions only:

```julia
# Cache only occurrence queries
DataCaches.setautocache!(true, pbdb_occurrences)

# Cache occurrences and taxa (additive)
DataCaches.setautocache!(true, [pbdb_occurrences, pbdb_taxa])

# Remove a function from the autocache allowlist
DataCaches.setautocache!(false, pbdb_occurrences)
```

**Custom cache store:**

```julia
my_cache = DataCache("/data/project_cache")

# All functions → custom cache
c = DataCaches.setautocache!(true; cache = my_cache)

# Specific function → custom cache
DataCaches.setautocache!(true, pbdb_occurrences; cache = my_cache)
```

`setautocache!` returns the active `DataCache` (or `nothing` when disabling),
so you can immediately inspect it:

```julia
cache = DataCaches.setautocache!(true)
describe(cache)
```

**Compatibility with `@filecache`:** Using `@filecache` explicitly while
autocache is on is fully safe — autocache is automatically suppressed for
that call so the result is written exactly once:

```julia
DataCaches.setautocache!(true)
occs = @filecache pbdb_occurrences(base_name = "Felidae")  # one cache write, no duplication
```

### `@memcache` — in-memory session memoization

`@memcache` caches results in RAM for the duration of the current Julia
session. No files are written; the cache is lost when Julia exits.
Useful for repeated calls within a script or interactive session.

```julia
occs = @memcache pbdb_occurrences(base_name = "Canidae", show = "full")
taxa = @memcache pbdb_taxa(name = "Dinosauria")

PaleobiologyDB.memcache_clear!()   # discard all in-memory cached results
```

## Advanced features

### Rich field names

Full descriptive field names are returned by default. Pass `vocab = "com"` for compact 3-letter codes:

```julia
df_full  = pbdb_occurrences(base_name = "Canis", limit = 5)              # full names
df_short = pbdb_occurrences(base_name = "Canis", limit = 5, vocab = "com") # compact codes
```

### Additional information blocks

```julia
detailed_occs = pbdb_occurrences(
    base_name = "Dinosauria",
    interval = "Cretaceous",
    show = ["coords", "classext", "stratext", "ident", "loc"],
)
```

### Time and stratigraphy

```julia
old_mammals = pbdb_occurrences(base_name = "Mammalia", min_ma = 50.0, max_ma = 65.0)

miocene_data = pbdb_occurrences(interval = "Miocene", cc = "NAM")

formations = pbdb_strata(rank = "formation",
                         lngmin = -120, lngmax = -100,
                         latmin = 30, latmax = 50)
```

### Counting records

Use `pbdb_count` to get the number of matching records without downloading
the data. Pass a `Symbol` for the resource type:

```julia
pbdb_count(:occurrences; base_name = "Canidae")
pbdb_count(:collections; interval = "Miocene", cc = "ASI")
pbdb_count(:taxa; base_name = "Mammalia")

# Dynamic and splatting work too:
params = Dict(:base_name => "Cetacea", :interval => "Miocene")
pbdb_count(:specimens; params...)
```

Valid resource symbols: `:occurrences`, `:collections`, `:taxa`,
`:references`, `:specimens`, `:opinions`.

### References and bibliography

```julia
refs = pbdb_ref_taxa(name = "Canidae", show = ["both", "comments"])

occ_refs = pbdb_ref_occurrences(base_name = "Canis", ref_pubyr = 2000)

ref_detail = pbdb_reference(1003, show = "both")
```

## Function reference

* Occurrences: `pbdb_occurrence`, `pbdb_occurrences`, `pbdb_ref_occurrences`
* Collections: `pbdb_collection`, `pbdb_collections`, `pbdb_collections_geo`, `pbdb_ref_collections`
* Taxa: `pbdb_taxon`, `pbdb_taxa`, `pbdb_taxa_auto`, `pbdb_ref_taxa`, `pbdb_opinions_taxa`
* Intervals/scales: `pbdb_interval`, `pbdb_intervals`, `pbdb_scale`, `pbdb_scales`
* Strata: `pbdb_strata`, `pbdb_strata_auto`
* References: `pbdb_reference`, `pbdb_references`
* Specimens: `pbdb_specimen`, `pbdb_specimens`, `pbdb_ref_specimens`, `pbdb_measurements`
* Opinions: `pbdb_opinion`, `pbdb_opinions`
* Counts: `pbdb_count` (pass a `Symbol` resource or a raw endpoint string)

All wrappers delegate to `pbdb_query(endpoint; kwargs...)`.

## Common parameters

* `base_name`, `taxon_name`
* `interval`, `min_ma`, `max_ma`
* `lngmin`, `lngmax`, `latmin`, `latmax`
* `cc` (country/continent codes)
* `vocab` (field vocabulary)
* `show` (extra data blocks)
* `limit` (record limit)

## Error handling

Errors are thrown as ordinary Julia exceptions (e.g. `HTTP.ExceptionRequest.StatusError` on bad status codes). Wrap queries in `try`/`catch`:

```julia
try
    data = pbdb_occurrences(base_name = "InvalidTaxon", limit = 10)
catch e
    @warn "PBDB request failed" exception = e
end
```

## Built-in data service API reference

This package includes and makes available for searching, grepping, and displaying, the API documentation of the PBDB data service in an `ApiHelp` submodule.
This module itself, like the rest of the `PaleobiologyDB` package, is richly documented with help docstrings to facilitate learning and self-discovery:

```
julia> using PaleobiologyDB.ApiHelp
help?> ApiHelp
search: ApiHelp

  ApiHelp

  Provides interactive help and documentation for the Paleobiology Database (PBDB) API.

  Available Functions
  ===================
    •  pbdb_help() - Show available API endpoints or detailed help for a specific endpoint
    •  pbdb_endpoints() - List all available PBDB API endpoints
    •  pbdb_parameters(endpoint) - Show parameters for an endpoint
    •  pbdb_fields(endpoint) - Show response fields for an endpoint
    •  pbdb_api_search(pattern) - Search documentation for patterns
.
.
.
julia> PaleobiologyDB.ApiHelp.pbdb_parameters("occurrences")
SELECTION PARAMETERS:
  all_records
    Select all occurrences entered in the database
  occ_id
    Comma-separated list of occurrence identifiers
  coll_id
    Comma-separated list of collection identifiers
  base_name
    Taxonomic name(s), including all subtaxa and synonyms
  taxon_name
    Taxonomic name(s), including synonyms
  taxon_id
    Taxa identifiers, not including subtaxa or synonyms

GEOGRAPHIC PARAMETERS:
  lngmin
    Minimum longitude bound
  lngmax
    Maximum longitude bound
  latmin
    Minimum latitude bound
  latmax
    Maximum latitude bound
  cc
    Country codes (e.g., 'US,CA') or continent codes
  country_name
    Full country names, may include wildcards
  state
    State or province names

TEMPORAL PARAMETERS:
  interval
    Named geologic time intervals (e.g., 'Miocene')
  min_ma
    Minimum age in millions of years
  max_ma
    Maximum age in millions of years
  timerule [contain|major|overlap]
    Temporal locality rule

TAXONOMIC PARAMETERS:
  idreso [species|genus|family]
    Taxonomic resolution
  taxon_status [valid|accepted|invalid]
    Taxonomic status
  extant [yes|no]
    Extant status

OUTPUT PARAMETERS:
  show [class|coords|loc|time|strat|env]
    Additional info blocks
  order [id|max_ma|identification]
    Result ordering
  limit
    Maximum number of records to return
```

## Testing

Run tests with:

```bash
julia --project -e 'using Pkg; Pkg.test()'
```

By default, only offline tests run. Enable live API tests by setting:

```bash
PBDB_LIVE=1 julia --project -e 'using Pkg; Pkg.test()'
```

## Useful guides, references, and documentation

### The PBDB data service

-	[PBDB Data Service: Documentation](https://paleobiodb.org/data1.2/)
-	[PBDB Data Service: Usage documentation](https://paleobiodb.org/data1.2/general_doc.html)
	-	[PBDB Data Service: Record identifiers and record numbers](https://paleobiodb.org/data1.2/general/identifiers_doc.html)
	-	[PBDB Data Service: Specifying taxonomic names](https://paleobiodb.org/data1.2/general/taxon_names_doc.html)
	-	[PBDB Data Service: Ecological and taphonomic vocabulary](https://paleobiodb.org/data1.2/general/ecotaph_doc.html)
	-	[PBDB Data Service: Specifying dates and times](https://paleobiodb.org/data1.2/general/datetime_doc.html)
	-	[PBDB Data Service: Bibliographic references](https://paleobiodb.org/data1.2/general/references_doc.html)
	-	[PBDB Data Service: Output formats and Vocabularies](https://paleobiodb.org/data1.2/formats_doc.html)
	-	[PBDB Data Service: Special parameters](https://paleobiodb.org/data1.2/special_doc.html)

### Processing Paleobiology Database data

- [1 Managing and Processing Data From the Paleobiology Database | Analytical Paleobiology](https://psmits.github.io/paleo_book/managing-and-processing-data-from-the-paleobiology-database.html)

## Contributing

Contributions are welcome. Please fork the repository, add tests for new functionality, and submit a pull request.

## Citation

[![](https://zenodo.org/badge/1046851014.svg)](https://doi.org/10.5281/zenodo.16994488)

If you use PaleobiologyDB.jl in your research, please cite both this package and the Paleobiology Database:

```bibtex
@misc{PaleobiologyDB.jl,
  author = {Jeet Sukumaran},
  title = {PaleobiologyDB.jl: A Julia interface to the Paleobiology Database},
  url = {https://github.com/jeetsukumaran/PaleobiologyDB.jl},
  year = {2025},
  doi = {10.5281/zenodo.17043157}
}

@article{Peters2016,
  author = {Shanan E. Peters and Michael McClennen},
  title = {The Paleobiology Database application programming interface},
  journal = {Paleobiology},
  volume = {42},
  number = {1},
  pages = {1--7},
  year = {2016},
  doi = {10.1017/pab.2015.39}
}
```

## Acknowledgments

- The [Paleobiology Database](https://paleobiodb.org/) for providing the data and API
- API endpoint names following the [paleobioDB R package](https://cran.r-project.org/web/packages/paleobioDB/index.html) convention.
- Julia community packages: JSON3.jl, HTTP.jl, DataFrames.jl, CSV.jl, URIs.jl
- The [Julia Community](https://julialang.org/community/)!
