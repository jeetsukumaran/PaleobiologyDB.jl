
include("_taxonomy_resolution.jl")
include("_taxonomy_namevalidation.jl")
include("_taxonomy_augment.jl")


# Applies both `drop_unresolved_taxa` and `drop_unrecognized_taxa` to `df`, after first mapping taxonomic_resolution to the correct String value and PBDB database field value (:genus => ("genus", :genus), but :species => ("species", :accepted_name)
function _resolve_taxonomic_resolution(taxonomic_resolution::Symbol)
    if taxonomic_resolution == :species
        ("species", :accepted_name)
    else
        (String(taxonomic_resolution), taxonomic_resolution)
    end
end

"""
    drop_unqualified_taxa(df, taxonomic_resolution) -> DataFrame

Return a filtered copy of `df` keeping only rows that are both *resolved* and
*recognized* at the requested taxonomic level.

This is a convenience wrapper that combines two independent filters in sequence:

1. **Resolution filter** ([`drop_unresolved_taxa`](@ref)) — keeps rows where
   `accepted_rank` is at least as specific as `taxonomic_resolution`.  For
   example, `:genus` accepts rows whose `accepted_rank` is `"genus"`,
   `"species"`, or `"subspecies"`.  Rows with a missing `accepted_rank` are
   always dropped.  If `df` has a column named after the rank (e.g. `genus`)
   that column must also be non-missing and non-empty.

2. **Name-validity filter** ([`drop_unrecognized_taxa`](@ref)) — keeps rows
   where the taxon name in the relevant column is found in the PBDB taxonomic
   authority.  Names are checked against a locally cached snapshot of the full
   PBDB taxa list (downloaded on first use, refreshed every 30 days); pass
   `validation_authority = :query` to use live API calls instead.

## Column mapping

Most ranks map `taxonomic_resolution` directly to both the rank string and the
DataFrame column of the same name:

| `taxonomic_resolution` | rank string | taxon column |
|------------------------|-------------|--------------|
| `:genus`               | `"genus"`   | `:genus`     |
| `:family`              | `"family"`  | `:family`    |
| `:order`               | `"order"`   | `:order`     |
| …                      | …           | …            |

The one exception is `:species`, where the PBDB stores the full binomial in the
`accepted_name` column rather than a column called `species`:

| `taxonomic_resolution` | rank string   | taxon column    |
|------------------------|---------------|-----------------|
| `:species`             | `"species"`   | `:accepted_name`|

## Keyword arguments

- `validation_authority` — passed through to [`drop_unrecognized_taxa`](@ref).
  `:snapshot` (default) uses the local cache; `:query` calls the live API.

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.DataCurator

df = pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")

# Keep only rows resolved and recognized at genus level
df_genus = drop_unqualified_taxa(df, :genus)

# Keep only rows resolved and recognized at species level
# (checks accepted_rank ∈ {"species","subspecies"} AND accepted_name ∈ PBDB)
df_species = drop_unqualified_taxa(df, :species)

# Keep only rows resolved to family level, using live API validation
df_family = drop_unqualified_taxa(df, :family; validation_authority = :query)
```

See also [`drop_unqualified_taxa!`](@ref) for the in-place variant,
[`drop_unresolved_taxa`](@ref), [`drop_unrecognized_taxa`](@ref).
"""
function drop_unqualified_taxa(
    df::DataFrame,
    taxonomic_resolution::Symbol;
    validation_authority::Symbol = :snapshot,
)::DataFrame
    rank_str, taxon_field = _resolve_taxonomic_resolution(taxonomic_resolution)
    result = drop_unresolved_taxa(df, rank_str)
    drop_unrecognized_taxa(result, taxon_field; validation_authority)
end

"""
    drop_unqualified_taxa!(df, taxonomic_resolution) -> DataFrame

In-place variant of [`drop_unqualified_taxa`](@ref).

Applies both the resolution filter and the name-validity filter directly to
`df` (no copy is made) and returns `df`.

The two filters applied in order are:

1. **Resolution filter** — rows whose `accepted_rank` is coarser than
   `taxonomic_resolution`, or that have a missing `accepted_rank`, are removed.
   If a column named after the rank exists (e.g. `genus`), rows where that
   column is missing or empty are also removed.

2. **Name-validity filter** — rows where the taxon name in the relevant column
   is not found in the PBDB taxonomic authority are removed.  By default this
   uses a locally cached snapshot; pass `validation_authority = :query` to use
   live API calls.

## Column mapping

`:species` maps to the `accepted_name` column; all other symbols map to the
column of the same name (e.g. `:genus` → `:genus`).

## Keyword arguments

- `validation_authority` — `:snapshot` (default) or `:query`.

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.DataCurator

df = pbdb_occurrences(base_name = "Felidae", interval = "Pleistocene", show = "full")

# Filter in-place to genus-level resolved and recognized rows
drop_unqualified_taxa!(df, :genus)

# Filter in-place to species-level (uses accepted_name column for name check)
drop_unqualified_taxa!(df, :species)
```

See also [`drop_unqualified_taxa`](@ref) for the non-mutating variant.
"""
function drop_unqualified_taxa!(
    df::DataFrame,
    taxonomic_resolution::Symbol;
    validation_authority::Symbol = :snapshot,
)::DataFrame
    rank_str, taxon_field = _resolve_taxonomic_resolution(taxonomic_resolution)
    drop_unresolved_taxa!(df, rank_str)
    drop_unrecognized_taxa!(df, taxon_field; validation_authority)
end