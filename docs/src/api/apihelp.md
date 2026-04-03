# Interactive API Help

The `ApiHelp` submodule provides interactive discovery and browsing of the
PBDB data service API documentation directly from the Julia REPL.

```julia
using PaleobiologyDB.ApiHelp
```

## REPL Demo

The module itself is documented and discoverable from the Julia help system:

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
```

Use `pbdb_parameters` to explore what filters are available for any endpoint:

```
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

## Module reference

```@docs
PaleobiologyDB.ApiHelp
```

## Functions

```@docs
pbdb_help
pbdb_endpoints
pbdb_parameters
pbdb_fields
pbdb_api_search
```
