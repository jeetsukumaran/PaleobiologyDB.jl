```@meta
CurrentModule = PaleobiologyDB.Taxonomy
```

# Taxonomy — Filtering

The `Taxonomy` submodule provides tools for validating and cleaning
palaeobiological data against the PBDB taxonomic authority.

```julia
using PaleobiologyDB.Taxonomy
```

## Combined taxonomic quality filter

`drop_unqualified_taxa` is the top-level function for cleaning occurrence
DataFrames.  It applies two independent filters in sequence: a *resolution*
check (is the identification specific enough?) and a *name-validity* check (is
the name actually in the PBDB taxonomy?).

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy

df = pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")

# Keep rows resolved and recognized at genus level
df_genus = drop_unqualified_taxa(df, "genus")

# Keep rows resolved and recognized at species level
# ("species" maps to the accepted_name column for the name check)
df_species = drop_unqualified_taxa(df, "species")

# In-place variant (modifies df directly)
drop_unqualified_taxa!(df, "family")

# Use live API validation instead of the local snapshot
df_clean = drop_unqualified_taxa(df, "genus"; validation_authority = :query)
```

```@docs
drop_unqualified_taxa
drop_unqualified_taxa!
```

## Taxonomy resolution filter

These functions check that each row is identified to at least a given
taxonomic rank, based on the `accepted_rank` column.

```julia
using PaleobiologyDB.Taxonomy

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
drop_unresolved_taxa
drop_unresolved_taxa!
```

## Taxonomy name-validity filter

These functions check taxon names against the PBDB taxonomy using either a
local Scratch-managed snapshot (default, O(1) lookups after the initial
download) or live API queries.

```julia
using PaleobiologyDB.Taxonomy

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
istaxon
audit_taxonomy
drop_unrecognized_taxa
drop_unrecognized_taxa!
```

## Taxonomy augmentation

`augment_taxonomy` enriches an occurrences DataFrame with the full taxonomic
hierarchy for each row, resolved from the Scratch-cached PBDB taxa list.

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy

df = pbdb_occurrences(base_name = "Carnivora", interval = "Miocene", limit = 500)

# Add taxonomy_genus, taxonomy_family, …, taxonomy_kingdom, taxonomy_clades columns
df2 = augment_taxonomy(df)

# Filter for a specific subfamily
df2[.!ismissing.(df2.taxonomy_subfamily) .&& df2.taxonomy_subfamily .== "Borophaginae", :]

# Inspect a taxonomy string
df2.taxonomy_clades[1]
# → "Animalia > Chordata > Mammalia > Carnivora > Canidae > Borophaginae > Epicyon"
```

```@docs
augment_taxonomy
```

## Taxonomic rank hierarchy

```@docs
PBDB_RANK_HIERARCHY
```
