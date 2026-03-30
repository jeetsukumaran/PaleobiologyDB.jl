# Quick Start

## Basic usage

Every PBDB API endpoint corresponds to a Julia function. Calling the function with
keyword arguments matching the API parameters returns a `DataFrame`.

```julia
using PaleobiologyDB

# Fossil occurrences — all Canidae in the Miocene
canids = pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")

# Taxonomic information
canis_info = pbdb_taxon(name = "Canis", extids = true, show = ["attr", "app", "size"])

# A specific collection (string or numeric ID)
collection = pbdb_collection("col:1003", show = ["loc", "stratext"], extids = true)
collection = pbdb_collection(1003, show = ["loc", "stratext"])
```

## Fossil occurrences

```julia
# Simple query
occs = pbdb_occurrences(base_name = "Mammalia", limit = 10)

# Single occurrence
single_occ = pbdb_occurrence("occ:1001", show = "full")
single_occ = pbdb_occurrence(1001, show = "full")

# Geographic and temporal filtering
pliocene_mammals = pbdb_occurrences(
    base_name = "Mammalia",
    interval = "Pliocene",
    lngmin = -130.0, lngmax = -60.0,
    latmin = 25.0, latmax = 70.0,
    show = ["coords", "classext", "stratext"],
)

# taxon_name matches exact rank; base_name includes all subtaxa
occs_exact = pbdb_occurrences(taxon_name = "Canis", limit = 100)
occs_subtaxa = pbdb_occurrences(base_name = "Canis", show = ["coords", "classext"], limit = 100)
```

## Taxonomic data

```julia
mammalia = pbdb_taxon(name = "Mammalia", show = ["attr", "size"])

carnivores = pbdb_taxa(name = "Carnivora", rel = "children", show = ["attr", "app"])

suggestions = pbdb_taxa_auto(name = "Cani", limit = 10)
```

## Collections and geography

```julia
european_collections = pbdb_collections(
    lngmin = -10.0, lngmax = 40.0,
    latmin = 35.0, latmax = 65.0,
    interval = "Cenozoic",
)

clusters = pbdb_collections_geo(
    level = 2,
    lngmin = 0.0, lngmax = 15.0,
    latmin = 45.0, latmax = 55.0,
)
```

## Specimens and measurements

```julia
whale_specimens = pbdb_specimens(base_name = "Cetacea", interval = "Miocene")

measurements = pbdb_measurements(
    spec_id = ["spm:1505", "spm:30050"],
    show = ["spec", "methods"],
)
```

## Common parameters

| Parameter | Description |
|---|---|
| `base_name` | Taxon name including all subtaxa and synonyms |
| `taxon_name` | Taxon name including synonyms, exact rank only |
| `interval` | Named geologic interval (e.g. `"Miocene"`) |
| `min_ma`, `max_ma` | Age range in millions of years |
| `lngmin`, `lngmax`, `latmin`, `latmax` | Geographic bounding box |
| `cc` | Country/continent codes (e.g. `"US,CA"`, `"NAM"`) |
| `show` | Extra data blocks (`"coords"`, `"classext"`, `"full"`, …) |
| `extids` | Use string identifiers (`"occ:1001"`) instead of integers |
| `vocab` | Field vocabulary: `"pbdb"` (full names) or `"com"` (short codes) |
| `limit` | Maximum records to return (integer or `"all"`) |

## Counting records without downloading

```julia
pbdb_count(:occurrences; base_name = "Canidae")
pbdb_count(:collections; interval = "Miocene", cc = "ASI")
pbdb_count(:taxa; base_name = "Mammalia")
```

Valid symbols: `:occurrences`, `:collections`, `:taxa`, `:references`, `:specimens`, `:opinions`.

## Error handling

```julia
try
    data = pbdb_occurrences(base_name = "InvalidTaxon", limit = 10)
catch e
    @warn "PBDB request failed" exception = e
end
```
