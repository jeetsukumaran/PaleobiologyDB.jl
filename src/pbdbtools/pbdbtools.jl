module Curator

using CSV, DataFrames, Downloads, Scratch

include("_localstore.jl")
include("_taxonomy.jl")
include("_taxonomy_namevalidation.jl")

"""
    PaleobiologyDB.Curator.Store

Management interface for Curator's Scratch-backed local data stores (snapshots).

These functions are intentionally **not exported** from `Curator`; access them via
the full namespace `PaleobiologyDB.Curator.Store.*`.

## Functions

- `Store.list()`            — list metadata for all registered stores
- `Store.info(:taxa_list)`  — metadata for a specific store
- `Store.refresh!(:taxa_list)` — force re-download
- `Store.delete!(:taxa_list)` — remove the local snapshot

## Example

```julia
PaleobiologyDB.Curator.Store.list()
PaleobiologyDB.Curator.Store.info(:taxa_list)
PaleobiologyDB.Curator.Store.refresh!(:taxa_list)
PaleobiologyDB.Curator.Store.delete!(:taxa_list)
```
"""
module Store
    """Force re-download of the named store (e.g. `:taxa_list`)."""
    refresh!(name::Symbol; force::Bool = true) = Curator._refresh_store!(name; force = force)

    """Delete the local snapshot for the named store."""
    delete!(name::Symbol) = Curator._delete_store!(name)

    """
    Return a NamedTuple of metadata for the named store.

    Fields: `name`, `description`, `path`, `exists`, `size_mb`, `age_days`,
    `max_age_days`, `is_fresh`.
    """
    info(name::Symbol) = Curator._store_info(name)

    """Return a vector of info NamedTuples for all registered stores."""
    list() = Curator._list_stores()
end

end
