"""
    PaleobiologyDB

A Julia interface to the Paleobiology Database (PBDB) Web API.

This package provides functions to query the PBDB API for fossil occurrences,
taxonomic information, collections, specimens, and other paleobiological data.

# Examples

```julia
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

# Get taxonomic information
taxa = pbdb_taxa(name = "Canis")

# Get a single collection
coll = pbdb_collection(
    "col:1003",
    show = ["coords", "loc", "stratext"],
    extids = true,
)
coll = pbdb_collection(
    1003,
    show = ["loc", "stratext"],
)
```

See "`names(PaleobiologyDB)`" for full list of functions, and
the help for each function (e.g., "`?pbdb_collections`",
"`?pbdb_occurrence`" for more examples and details.

# Acknowledgements
The [Paleobiology Database](https://paleobiodb.org/) for curating
and providing the data and API.
This package data server endpoint API naming convention
is based on the [paleobioDB](https://github.com/ropensci/paleobioDB)
R package.

"""
module PaleobiologyDB

using DataCaches
export DataCaches

# include("../deps/PhyloPicMakie.jl/src/PhyloPicMakie.jl")
# import .PhyloPicMakie
import PhyloPicMakie

include("dbapi.jl")
include("pbdbdocs.jl")

include("PhyloPic/PhyloPic.jl")
include("pbdbtools/pbdbtools.jl")
include("TaxonTreeMakie/TaxonTreeMakie.jl")

end # module
