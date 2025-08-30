# PaleobiologyDB

A Julia interface to the [Paleobiology Database](https://paleobiodb.org/) (PBDB) Web API.

## Overview

PaleobiologyDB.jl provides a Julia interface to query the Paleobiology Database.
Results are returned as `DataFrame`s.

## Installation

Until the package is registered, install directly from the repository:

```julia
using Pkg
Pkg.add(url="https://github.com/jeetsukumaran/PaleobiologyDB.jl")
````

## Quick start

```julia
using PaleobiologyDB

# Get fossil occurrences
canids = pbdb_occurrences(
    base_name="Canidae",
    interval="Miocene",
    show=["coords", "class"],
    vocab="pbdb",
    limit=100
)

# Get taxonomic information
canis_info = pbdb_taxon(
    name="Canis",
    vocab="pbdb",
    show=["attr", "app", "size"]
)

# Get a specific collection
collection = pbdb_collection(
    1003,
    show=["loc", "stratext"],
    vocab="pbdb"
)
```

## Basic usage

### Fossil occurrences

```julia
# Simple occurrence query
occs = pbdb_occurrences(base_name="Mammalia", limit=10)

# Specific occurrence
single_occ = pbdb_occurrence(1001, vocab="pbdb", show=["coords", "class"])

# Geographic and temporal filtering
pliocene_mammals = pbdb_occurrences(
    base_name="Mammalia",
    interval="Pliocene",
    lngmin=-130.0, lngmax=-60.0,
    latmin=25.0, latmax=70.0,
    show=["coords", "classext", "stratext"],
    vocab="pbdb"
)
```

### Taxonomic data

```julia
mammalia = pbdb_taxon(name="Mammalia", vocab="pbdb", show=["attr", "size"])

carnivores = pbdb_taxa(
    name="Carnivora",
    rel="children",
    vocab="pbdb",
    show=["attr", "app"]
)

suggestions = pbdb_taxa_auto(name="Cani", limit=10)
```

### Collections and geography

```julia
european_collections = pbdb_collections(
    lngmin=-10.0, lngmax=40.0,
    latmin=35.0, latmax=65.0,
    interval="Cenozoic"
)

clusters = pbdb_collections_geo(
    level=2,
    lngmin=0.0, lngmax=15.0,
    latmin=45.0, latmax=55.0
)
```

### Specimens and measurements

```julia
whale_specimens = pbdb_specimens(
    base_name="Cetacea",
    interval="Miocene",
    vocab="pbdb"
)

measurements = pbdb_measurements(
    spec_id=[1505, 30050],
    show=["spec", "methods"],
    vocab="pbdb"
)
```

## Advanced features

### Rich field names

Use `vocab="pbdb"` for descriptive field names:

```julia
df_short = pbdb_occurrences(base_name="Canis", limit=5)            # compact codes
df_full  = pbdb_occurrences(base_name="Canis", limit=5, vocab="pbdb") # full names
```

### Additional information blocks

```julia
detailed_occs = pbdb_occurrences(
    base_name="Dinosauria",
    interval="Cretaceous",
    show=["coords","classext","stratext","ident","loc"],
    vocab="pbdb"
)
```

### Time and stratigraphy

```julia
old_mammals = pbdb_occurrences(base_name="Mammalia", min_ma=50.0, max_ma=65.0)

miocene_data = pbdb_occurrences(interval="Miocene", cc="NAM")

formations = pbdb_strata(rank="formation",
                         lngmin=-120, lngmax=-100,
                         latmin=30, latmax=50)
```

### References and bibliography

```julia
refs = pbdb_ref_taxa(name="Canidae", show=["both","comments"], vocab="pbdb")

occ_refs = pbdb_ref_occurrences(base_name="Canis", ref_pubyr=2000, vocab="pbdb")

ref_detail = pbdb_reference(1003, vocab="pbdb", show="both")
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
    data = pbdb_occurrences(base_name="InvalidTaxon", limit=10)
catch e
    @warn "PBDB request failed" exception=e
end
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

## Contributing

Contributions are welcome. Please fork the repository, add tests for new functionality, and submit a pull request.

## Citation

If you use PaleobiologyDB.jl in your research, please cite both this package and the Paleobiology Database:

```bibtex
@misc{PaleobiologyDB.jl,
  author = {Jeet Sukumaran},
  title = {PaleobiologyDB.jl: A Julia interface to the Paleobiology Database},
  url = {https://github.com/jeetsukumaran/PaleobiologyDB.jl},
  year = {2025}
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