# Taxonomy

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
PaleobiologyDB.Taxonomy.drop_unqualified_taxa
PaleobiologyDB.Taxonomy.drop_unqualified_taxa!
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
PaleobiologyDB.Taxonomy.drop_unresolved_taxa
PaleobiologyDB.Taxonomy.drop_unresolved_taxa!
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
PaleobiologyDB.Taxonomy.istaxon
PaleobiologyDB.Taxonomy.audit_taxonomy
PaleobiologyDB.Taxonomy.drop_unrecognized_taxa
PaleobiologyDB.Taxonomy.drop_unrecognized_taxa!
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
PaleobiologyDB.Taxonomy.augment_taxonomy
```

## Taxonomic rank hierarchy

```@docs
PaleobiologyDB.Taxonomy.PBDB_RANK_HIERARCHY
```

## Taxonomy tree queries

These functions navigate the PBDB taxonomic hierarchy by name, returning
descendants or ancestors at a requested rank.  All functions are backed by the
same Scratch-managed snapshot used by the filters above and build their indices
on first use (no extra download required).

```julia
using PaleobiologyDB.Taxonomy

# Valid rank names
taxonomic_ranks()
# → ["subspecies", "species", "genus", …, "kingdom"]

# All accepted taxon names (tens of thousands)
registered_taxa()

# Names matching a pattern
registered_taxa(r"^Canis\b")
# → ["Canis", "Canis aureus", "Canis lupus", …]

# Union of patterns
registered_taxa([r"^Canis\b", r"^Vulpes\b"])

# All families within Carnivora
child_taxa("Carnivora", "family")
# → ["Ailuridae", "Amphicyonidae", "Canidae", "Felidae", …]

# All genera within Canidae
child_taxa("Canidae", "genus")
# → ["Borophagus", "Canis", "Lycaon", "Urocyon", "Vulpes", …]

# All species within a genus
child_taxa("Canis", "species")
# → ["Canis aureus", "Canis lupus", "Canis mesomelas", …]

# Every descendant at any rank (no filter)
child_taxa("Canidae")

# Full ancestor chain of a species, child → root
parent_taxa("Canis lupus")
# → ["Canis", "Canidae", "Carnivora", "Mammalia", …, "Animalia"]

# Only the family
parent_taxa("Canis lupus", "family")
# → ["Canidae"]
```

```@docs
PaleobiologyDB.Taxonomy.taxonomic_ranks
PaleobiologyDB.Taxonomy.registered_taxa
PaleobiologyDB.Taxonomy.child_taxa
PaleobiologyDB.Taxonomy.parent_taxa
```

## Taxon occurrence search: taxon_occursin

`taxon_occursin` searches for taxonomic patterns across multiple columns. It comes in two forms:

- **2-arg** `taxon_occursin(pattern, df)` → `Vector{Bool}` — searches across all
  taxonomy columns; use for `df[mask, :]` filtering.
- **1-arg** `taxon_occursin(pattern)` → `ByRow` predicate — for use directly with
  `subset(df, :col => taxon_occursin(pattern))`.

By placing the pattern first, this function works naturally with piping and functional composition.

Vector inputs (`AbstractVector{<:AbstractString}` or `AbstractVector{<:Regex}`) accept
a `combine` keyword (`all` by default): `combine=all` requires **all** elements to
match (AND); `combine=any` requires **any** to match (OR).

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy: taxon_occursin

df = pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")

# 2-arg: multi-column boolean mask
df[taxon_occursin("Canis", df), :]
df[taxon_occursin(r"^Canis\b", df), :]

# 2-arg: AND — every name must appear in some column (default combine=all)
df[taxon_occursin(["Canis", "Mammalia"], df), :]

# 2-arg: OR — any name matches any column
df[taxon_occursin(["Canis", "Vulpes"], df; combine=any), :]

# 2-arg: AND patterns — each regex must match at least one column
df[taxon_occursin([r"Canidae", r"Canis"], df), :]

# 1-arg: use directly with subset
df2 = augment_taxonomy(df)
subset(df2, :taxonomy_genus => taxon_occursin("Canis"))
subset(df2, :taxonomy_clades => taxon_occursin(r"Borophaginae"))

# 1-arg: regex AND on composite column (default combine=all)
# rows where taxonomy_clades contains BOTH patterns
subset(df2, :taxonomy_clades => taxon_occursin([r"Canidae", r"lupus"]))

# 1-arg: regex OR
subset(df2, :taxonomy_clades => taxon_occursin([r"^Canis\b", r"^Vulpes\b"]; combine=any))

# 1-arg: string OR
subset(df2, :taxonomy_genus => taxon_occursin(["Canis", "Vulpes"]; combine=any))

# Chain with subset (Chain.jl)
using Chain
@chain df begin
    augment_taxonomy
    subset(:taxonomy_family   => taxon_occursin("Canidae"))
    subset(:taxonomy_clades   => taxon_occursin([r"Canis", r"lupus"]))
end
```

```@docs
PaleobiologyDB.Taxonomy.taxon_occursin
```

## Taxon occurrence search: contains_taxon

`contains_taxon` provides an alternative syntax to [`taxon_occursin`](@ref) with the DataFrame
as the first argument. It comes in the same two forms:

- **2-arg** `contains_taxon(df, pattern)` → `Vector{Bool}` — searches across all
  taxonomy columns; use for `df[mask, :]` filtering.
- **1-arg** `contains_taxon(pattern)` → `ByRow` predicate — for use directly with
  `subset(df, :col => contains_taxon(pattern))`.

By placing the DataFrame first, this function is more natural for statement chaining and
method calls where data flows from left to right.

All matching semantics, column selection, and keywords are identical to `taxon_occursin`.

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy: contains_taxon

df = pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")

# 2-arg: multi-column boolean mask (DataFrame first)
df[contains_taxon(df, "Canis"), :]
df[contains_taxon(df, r"^Canis\b"), :]

# 2-arg: AND — every name must appear in some column (default combine=all)
df[contains_taxon(df, ["Canis", "Mammalia"]), :]

# 2-arg: OR — any name matches any column
df[contains_taxon(df, ["Canis", "Vulpes"]; combine=any), :]

# 2-arg: AND patterns — each regex must match at least one column
df[contains_taxon(df, [r"Canidae", r"Canis"]), :]

# 1-arg: use directly with subset
df2 = augment_taxonomy(df)
subset(df2, :taxonomy_genus => contains_taxon("Canis"))
subset(df2, :taxonomy_clades => contains_taxon(r"Borophaginae"))

# 1-arg: regex AND on composite column (default combine=all)
# rows where taxonomy_clades contains BOTH patterns
subset(df2, :taxonomy_clades => contains_taxon([r"Canidae", r"lupus"]))

# 1-arg: regex OR
subset(df2, :taxonomy_clades => contains_taxon([r"^Canis\b", r"^Vulpes\b"]; combine=any))

# 1-arg: string OR
subset(df2, :taxonomy_genus => contains_taxon(["Canis", "Vulpes"]; combine=any))

# Chain with subset (Chain.jl)
using Chain
@chain df begin
    augment_taxonomy
    subset(:taxonomy_family   => contains_taxon("Canidae"))
    subset(:taxonomy_clades   => contains_taxon([r"Canidae", r"lupus"]))
end
```

```@docs
PaleobiologyDB.Taxonomy.contains_taxon
```

## Choosing between taxon_occursin and contains_taxon

Both `taxon_occursin` and `contains_taxon` are functionally identical and support all the same
patterns, keywords, and use cases. The choice is purely stylistic:

| Preference | Function | Usage |
|-----------|----------|--------|
| Pattern-first (functional style) | `taxon_occursin` | `df[taxon_occursin("Canis", df), :]` |
| DataFrame-first (method chaining style) | `contains_taxon` | `df[contains_taxon(df, "Canis"), :]` |

Use whichever feels more natural for your workflow. Both are equally idiomatic and supported.

## Local data store management

The `Store` submodule manages the Scratch-backed local snapshots used by the
taxonomy validation functions. Access via the full namespace:

```julia
using PaleobiologyDB.Taxonomy

# List all registered stores and their status
PaleobiologyDB.Taxonomy.Store.list()

# Metadata for a specific store
PaleobiologyDB.Taxonomy.Store.info(:pbdb_taxa)

# Force re-download of a snapshot
PaleobiologyDB.Taxonomy.Store.refresh!(:pbdb_taxa)

# Delete the local snapshot (will be re-downloaded on next use)
PaleobiologyDB.Taxonomy.Store.delete!(:pbdb_taxa)
```

```@docs
PaleobiologyDB.Taxonomy.Store
```
