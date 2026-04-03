# PaleobiologyDB


[![CI](https://github.com/jeetsukumaran/PaleobiologyDB.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/jeetsukumaran/PaleobiologyDB.jl/actions/workflows/CI.yml)
[![Documentation (stable)](https://img.shields.io/badge/docs-stable-blue.svg)](https://jeetsukumaran.github.io/PaleobiologyDB.jl/stable)
[![Documentation (dev)](https://img.shields.io/badge/docs-dev-blue.svg)](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev)



A Julia interface to the [Paleobiology Database](https://paleobiodb.org/) (PBDB) Web API.
Every PBDB API endpoint has a corresponding Julia function; keyword arguments map directly to API parameters, and results are returned as `DataFrame`s.

## Installation

```
pkg> add PaleobiologyDB
```

## Quick start

```julia
using PaleobiologyDB

# Fossil occurrences
canids = pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")

# Taxonomic data
canis = pbdb_taxon(name = "Canis", show = ["attr", "app", "size"])

# A specific collection
coll = pbdb_collection("col:1003", show = ["loc", "stratext"], extids = true)
```

## Key features

- **DataFrame results** — all queries return a `DataFrame` for immediate use with the Julia data ecosystem.

- **Caching** — persistent file cache (`@filecache`), in-memory session cache (`@memcache`), and global autocaching (`set_autocaching!`) keep repeated or expensive queries off the network. See the [Caching guide](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/caching/).

- **Rich field names and extra blocks** — `vocab = "pbdb"` (default) for full column names, `vocab = "com"` for compact codes; `show = ["coords", "classext", "stratext"]` for additional data blocks.

- **Count without downloading** — `pbdb_count(:occurrences; base_name = "Canidae")` returns the record count without fetching data.

- **Built-in API help** — `pbdb_parameters("occurrences")` lists all selection, geographic, temporal, taxonomic, and output parameters directly in the REPL. See the [Interactive Help docs](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/api/apihelp/).

## Function reference

* Occurrences: `pbdb_occurrence`, `pbdb_occurrences`, `pbdb_ref_occurrences`
* Collections: `pbdb_collection`, `pbdb_collections`, `pbdb_collections_geo`, `pbdb_ref_collections`
* Taxa: `pbdb_taxon`, `pbdb_taxa`, `pbdb_taxa_auto`, `pbdb_ref_taxa`, `pbdb_opinions_taxa`
* Intervals/scales: `pbdb_interval`, `pbdb_intervals`, `pbdb_scale`, `pbdb_scales`
* Strata: `pbdb_strata`, `pbdb_strata_auto`
* References: `pbdb_reference`, `pbdb_references`
* Specimens: `pbdb_specimen`, `pbdb_specimens`, `pbdb_ref_specimens`, `pbdb_measurements`
* Opinions: `pbdb_opinion`, `pbdb_opinions`
* Counts: `pbdb_count`

## Documentation

Full documentation: <https://jeetsukumaran.github.io/PaleobiologyDB.jl/>

- [Quick Start](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/quickstart/) — examples for all endpoint types, advanced query options
- [Caching](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/caching/) — file, memory, and auto-caching
- [API Reference](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/api/occurrences/) — per-function docstrings
- [Interactive Help](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/api/apihelp/) — REPL-based parameter and field discovery
- [Contributing](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/contributing/) — testing, development, and external resources

## Testing

```bash
julia --project -e 'using Pkg; Pkg.test()'
```

Enable live API tests:

```bash
PBDB_LIVE=1 julia --project -e 'using Pkg; Pkg.test()'
```

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

- The [Paleobiology Database](https://paleobiodb.org/) for providing the data and API.
- API endpoint naming convention based on the [paleobioDB](https://github.com/ropensci/paleobioDB) R package.
- Julia community packages: JSON3.jl, HTTP.jl, DataFrames.jl, CSV.jl, URIs.jl.
- The [Julia Community](https://julialang.org/community/).
