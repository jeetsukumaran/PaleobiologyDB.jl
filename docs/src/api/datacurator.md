# Data Curator

The `DataCurator` submodule provides tools for validating and cleaning
paleobiological data against the PBDB taxonomic authority.

```julia
using PaleobiologyDB.DataCurator
```

## Combined taxonomic quality filter

`drop_unqualified_taxa` is the top-level function for cleaning occurrence
DataFrames.  It applies two independent filters in sequence: a *resolution*
check (is the identification specific enough?) and a *name-validity* check (is
the name actually in the PBDB taxonomy?).

```julia
using PaleobiologyDB, PaleobiologyDB.DataCurator

df = pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")

# Keep rows resolved and recognized at genus level
df_genus = drop_unqualified_taxa(df, :genus)

# Keep rows resolved and recognized at species level
# (:species maps to the accepted_name column for the name check)
df_species = drop_unqualified_taxa(df, :species)

# In-place variant (modifies df directly)
drop_unqualified_taxa!(df, :family)

# Use live API validation instead of the local snapshot
df_clean = drop_unqualified_taxa(df, :genus; validation_authority = :query)
```

```@docs
PaleobiologyDB.DataCurator.drop_unqualified_taxa
PaleobiologyDB.DataCurator.drop_unqualified_taxa!
```

## Taxonomy resolution filter

These functions check that each row is identified to at least a given
taxonomic rank, based on the `accepted_rank` column.

```julia
using PaleobiologyDB.DataCurator

# Keep rows where accepted_rank is "genus", "species", or "subspecies"
df_resolved = drop_unresolved_taxa(df, "genus")

# Equivalent shorthand using a column symbol
df_resolved = drop_unresolved_taxa(df, :genus)

# :accepted_name maps to "species" resolution
df_resolved = drop_unresolved_taxa(df, :accepted_name)

# In-place variant
drop_unresolved_taxa!(df, "family")
```

```@docs
PaleobiologyDB.DataCurator.drop_unresolved_taxa
PaleobiologyDB.DataCurator.drop_unresolved_taxa!
```

## Taxonomy name-validity filter

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
