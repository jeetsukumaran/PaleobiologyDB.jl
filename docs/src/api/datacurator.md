# Data Curator

The `DataCurator` submodule provides tools for validating and cleaning
paleobiological data against the PBDB taxonomic authority.

```julia
using PaleobiologyDB.DataCurator
```

## Taxonomy validation

These functions check taxon names against the PBDB taxonomy using either a
local Scratch-managed snapshot (default, O(1) lookups after the initial
download) or live API queries.

```julia
using PaleobiologyDB.DataCurator

# Single-name check
istaxon("Pliosauridae")            # → true
istaxon("NO_FAMILY_SPECIFIED")     # → false

# Audit a DataFrame column
mask = audit_taxonomy(df, :family)
df[mask, :]

# Filter to recognized taxa only (non-mutating)
df_clean = drop_unrecognized_taxa(df, :family)

# In-place variant
drop_unrecognized_taxa!(df, :family)
```

```@docs
PaleobiologyDB.DataCurator.istaxon
PaleobiologyDB.DataCurator.audit_taxonomy
PaleobiologyDB.DataCurator.drop_unrecognized_taxa
PaleobiologyDB.DataCurator.drop_unrecognized_taxa!
```

## Local data store management

The `Store` submodule manages the Scratch-backed local snapshots used by the
taxonomy validation functions. Access via the full namespace:

```julia
using PaleobiologyDB.DataCurator

# List all registered stores and their status
PaleobiologyDB.DataCurator.Store.list()

# Metadata for a specific store
PaleobiologyDB.DataCurator.Store.info(:pbdb_taxa)

# Force re-download of a snapshot
PaleobiologyDB.DataCurator.Store.refresh!(:pbdb_taxa)

# Delete the local snapshot (will be re-downloaded on next use)
PaleobiologyDB.DataCurator.Store.delete!(:pbdb_taxa)
```

```@docs
PaleobiologyDB.DataCurator.Store
```
