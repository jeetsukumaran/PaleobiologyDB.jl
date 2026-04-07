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

## Self-Documenting Interface

The entire package is richly documented, from the module level:

```
help?> PaleobiologyDB
search: PaleobiologyDB

  PaleobiologyDB

  A Julia interface to the Paleobiology Database (PBDB) Web API.

  This package provides functions to query the PBDB API for fossil occurrences, taxonomic information,
  collections, specimens, and other paleobiological data.

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

down to individual functions:

```
help?> pbdb_occurrences

  pbdb_occurrences(; kwargs...)

  Get information about fossil occurrence records stored in the Paleobiology Database.

  Arguments
  ≡≡≡≡≡≡≡≡≡

    •  kwargs...: Filtering and output parameters. Common options include:
       • limit: Maximum number of records to return (Int or "all").
       • base_name: Return records for the specified name(s) and all descendant taxa.
       • interval: Named geologic interval (e.g. "Miocene").
       • show: Extra information blocks. show = "full" for everything.
       • extids: Set extids = true for string identifiers.
       • vocab: Vocabulary for field names ("pbdb" or "com").
```

The `ApiHelp` submodule provides interactive discovery at the REPL without leaving Julia —
browse endpoints, list parameters, inspect response fields, and search documentation.
See [Interactive Help](api/apihelp.md).

## Module Reference

```@docs
PaleobiologyDB
```

## Function Categories

| Category | Functions |
|---|---|
| Occurrences | `pbdb_occurrence`, `pbdb_occurrences`, `pbdb_ref_occurrences` |
| Collections | `pbdb_collection`, `pbdb_collections`, `pbdb_collections_geo`, `pbdb_ref_collections` |
| Taxa | `pbdb_taxon`, `pbdb_taxa`, `pbdb_taxa_auto`, `pbdb_ref_taxa`, `pbdb_opinions_taxa` |
| Intervals/scales | `pbdb_interval`, `pbdb_intervals`, `pbdb_scale`, `pbdb_scales` |
| Strata | `pbdb_strata`, `pbdb_strata_auto` |
| References | `pbdb_reference`, `pbdb_references` |
| Specimens | `pbdb_specimen`, `pbdb_specimens`, `pbdb_ref_specimens`, `pbdb_measurements` |
| Opinions | `pbdb_opinion`, `pbdb_opinions` |
| Counts | `pbdb_count` |
| Taxonomy (submodule) | `drop_unqualified_taxa`, `drop_unresolved_taxa`, `drop_unrecognized_taxa`, `augment_taxonomy`, `child_taxa`, `parent_taxa`, `registered_taxa`, `taxon_occursin`, `contains_taxon` |
| PhyloPic (submodule) | `acquire_phylopic`, `augment_phylopic` |

All wrappers delegate to `pbdb_query(endpoint; kwargs...)`.

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

## Acknowledgements

- The [Paleobiology Database](https://paleobiodb.org/) for curating and providing the data and API.
- API endpoint naming convention based on the [paleobioDB](https://github.com/ropensci/paleobioDB) R package.
- Julia community packages: [JSON3.jl](https://github.com/quinnj/JSON3.jl), [HTTP.jl](https://github.com/JuliaWeb/HTTP.jl), [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl), [CSV.jl](https://github.com/JuliaData/CSV.jl), [URIs.jl](https://github.com/JuliaWeb/URIs.jl).
- The [Julia Community](https://julialang.org/community/).
