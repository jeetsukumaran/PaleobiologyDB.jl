"""
    PaleobiologyDB

A Julia interface to the Paleobiology Database (PBDB) Web API.

This package provides functions to query the PBDB API for fossil occurrences,
taxonomic information, collections, specimens, and other paleobiological data.

# Examples

```julia
using PaleobiologyDB

# Get occurrences for Canidae
occs = pbdb_occurrences(base_name="Canidae", show=["coords", "classext"])

# Get taxonomic information
taxa = pbdb_taxa(name="Canis", vocab="pbdb")

# Get a single collection
coll = pbdb_collection(id=1003, show=["loc", "stratext"])
```

# Acknowledgements

## PBDB data service interface

The [Paleobiology Database](https://paleobiodb.org/) for curating
and providing the data and API.
This package data server endpoint API naming convention
is based on the [paleobioDB](https://github.com/ropensci/paleobioDB)
R package.

"""

module PaleobiologyDB

include("dbapi.jl")
include("userapi.jl")

end # module
