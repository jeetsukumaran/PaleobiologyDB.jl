# PaleobiologyDB.jl

A Julia interface to the [Paleobiology Database](https://paleobiodb.org/) (PBDB) Web API.
Results are returned as `DataFrame`s.

## Installation

```julia
using Pkg
Pkg.add("PaleobiologyDB")
```

Or for the latest development version:

```julia
using Pkg
Pkg.add(url = "https://github.com/jeetsukumaran/PaleobiologyDB.jl")
```

## Quick Example

```julia
using PaleobiologyDB

# Fossil occurrences for Canidae in the Miocene
canids = pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")

# Taxonomic data
canis = pbdb_taxon(name = "Canis", show = ["attr", "app", "size"])

# A specific collection
coll = pbdb_collection("col:1003", show = ["loc", "stratext"], extids = true)
```

See the [Quick Start](guide/quickstart.md) guide for more examples, the [Caching](guide/caching.md)
guide for offline/repeated queries, and the [API Reference](api/occurrences.md) for full function documentation.

## Module Reference

```@docs
PaleobiologyDB
```

## Acknowledgements

- The [Paleobiology Database](https://paleobiodb.org/) for curating and providing the data and API.
- API endpoint naming convention based on the [paleobioDB](https://github.com/ropensci/paleobioDB) R package.
