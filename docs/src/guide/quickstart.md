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

## The interface and REPL help

All functions are richly documented and discoverable from the Julia help system:

```
help?> pbdb_occurrences
search: pbdb_occurrences pbdb_occurrence pbdb_ref_occurrences ...

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
       • show: Extra information blocks ("coords", "classext", "ident", etc.).
       • extids: Set extids = true to show the newer string identifiers.
       • vocab: Vocabulary for field names ("pbdb" for full names, "com" for short codes).

  Examples
  ≡≡≡≡≡≡≡≡

  # `taxon_name` retrieves *only* units of this exact rank
  occs = pbdb_occurrences(taxon_name = "Canis", limit = 100)

  # `base_name` retrieves units of this and all nested ranks
  occs = pbdb_occurrences(base_name = "Canis", show = ["coords", "classext"], limit = 100)
```

Note the distinction: `taxon_name` matches only occurrences at that exact rank,
while `base_name` includes all descendant taxa.

See the [Interactive Help](../api/apihelp.md) page for the `ApiHelp` submodule,
which lets you browse parameters, fields, and endpoints interactively.

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

## Advanced query options

### Field name vocabulary

Full descriptive column names are returned by default. Use `vocab = "com"` for
compact 3-letter codes:

```julia
df_full  = pbdb_occurrences(base_name = "Canis", limit = 5)
df_short = pbdb_occurrences(base_name = "Canis", limit = 5, vocab = "com")
```

### Additional information blocks

Use `show` to request extra data blocks alongside the default fields:

```julia
detailed_occs = pbdb_occurrences(
    base_name = "Dinosauria",
    interval = "Cretaceous",
    show = ["coords", "classext", "stratext", "ident", "loc"],
)
```

`show = "full"` returns all available blocks at once.

### Time and stratigraphy

Filter by geological age in millions of years or by named interval:

```julia
old_mammals  = pbdb_occurrences(base_name = "Mammalia", min_ma = 50.0, max_ma = 65.0)
miocene_data = pbdb_occurrences(interval = "Miocene", cc = "NAM")
```

Query stratigraphic formations directly:

```julia
formations = pbdb_strata(
    rank   = "formation",
    lngmin = -120, lngmax = -100,
    latmin = 30,   latmax = 50,
)
```

### References and bibliography

```julia
# References for a taxon group
refs = pbdb_ref_taxa(name = "Canidae", show = ["both", "comments"])

# References cited in occurrence records
occ_refs = pbdb_ref_occurrences(base_name = "Canis", ref_pubyr = 2000)

# A specific reference record
ref_detail = pbdb_reference(1003, show = "both")
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

# Dict splatting works too
params = Dict(:base_name => "Cetacea", :interval => "Miocene")
pbdb_count(:specimens; params...)
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
