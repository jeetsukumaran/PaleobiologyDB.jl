module DataCurator

using CSV, DataFrames, Downloads, Scratch

import ..pbdb_taxon

include("_localstore.jl")
include("_taxonomy.jl")
include("_taxonomy_namevalidation.jl")

"""
    PaleobiologyDB.DataCurator.Store

Management interface for DataCurator's Scratch-backed local data stores (snapshots).

These functions are intentionally **not exported** from `DataCurator`; access them via
the full namespace `PaleobiologyDB.DataCurator.Store.*`.

## Functions

- `Store.list()`            — list metadata for all registered stores
- `Store.info(:pbdb_taxa)`  — metadata for a specific store
- `Store.refresh!(:pbdb_taxa)` — force re-download
- `Store.delete!(:pbdb_taxa)` — remove the local snapshot

## Example

```julia
PaleobiologyDB.DataCurator.Store.list()
PaleobiologyDB.DataCurator.Store.info(:pbdb_taxa)
PaleobiologyDB.DataCurator.Store.refresh!(:pbdb_taxa)
PaleobiologyDB.DataCurator.Store.delete!(:pbdb_taxa)
```
"""
module Store
    # parentmodule(@__MODULE__) resolves to DataCurator at call time, avoiding the
    # need for an explicit import from the enclosing module.
    _curator() = parentmodule(@__MODULE__)

    """Force re-download of the named store (e.g. `:pbdb_taxa`)."""
    refresh!(name::Symbol; force::Bool = true) = _curator()._refresh_store!(name; force = force)

    """Delete the local snapshot for the named store."""
    delete!(name::Symbol) = _curator()._delete_store!(name)

    """
    Return a NamedTuple of metadata for the named store.

    Fields: `name`, `description`, `path`, `exists`, `size_mb`, `age_days`,
    `max_age_days`, `is_fresh`.
    """
    info(name::Symbol) = _curator()._store_info(name)

    """Return a vector of info NamedTuples for all registered stores."""
    list() = _curator()._list_stores()
end

end
