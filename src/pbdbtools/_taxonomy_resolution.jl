
using DataFrames

# ---------------------------------------------------------------------------
# Taxonomic rank hierarchy
# ---------------------------------------------------------------------------

"""
    PBDB_RANK_HIERARCHY

Vector of PBDB `accepted_rank` values ordered from most specific to most
general: `"subspecies"`, `"species"`, `"genus"`, …, `"kingdom"`.

Used internally to resolve "at least as specific as X" queries and to define
the columns added by [`augment_taxonomy`](@ref).  Use
[`ls_taxonomic_ranks`](@ref) to obtain a mutable copy.
"""
const PBDB_RANK_HIERARCHY = [
    "subspecies",
    "species",
    "genus",
    "subtribe",
    "tribe",
    "subfamily",
    "family",
    "superfamily",
    "infraorder",
    "suborder",
    "order",
    "superorder",
    "infraclass",
    "subclass",
    "class",
    "superclass",
    "subphylum",
    "phylum",
    "kingdom",
]

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

function _pbdb_rank_index(rank::AbstractString)::Int
    idx = findfirst(==(rank), PBDB_RANK_HIERARCHY)
    if isnothing(idx)
        throw(ArgumentError(
            "Unknown taxonomic rank: \"$(rank)\". " *
            "Must be one of: $(join(PBDB_RANK_HIERARCHY, ", "))"
        ))
    end
    idx
end

function _pbdb_ranks_at_or_finer_than(rank::AbstractString)::Vector{String}
    PBDB_RANK_HIERARCHY[1:_pbdb_rank_index(rank)]
end

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

"""
    drop_unresolved_taxa(df, taxonomic_rank) -> DataFrame

Return a filtered copy of `df` containing only rows that meet the minimum
taxonomic resolution specified by `taxonomic_rank`.

Two criteria are applied:
1. The `accepted_rank` column must be at `taxonomic_rank` or finer (more
   specific). For example, `"genus"` accepts `"genus"`, `"species"`, and
   `"subspecies"`; `"family"` additionally accepts `"subfamily"`, `"tribe"`,
   `"subtribe"`. Rows with a missing `accepted_rank` are dropped.
2. If `df` contains a column whose name matches `taxonomic_rank` (e.g. a
   `genus` or `family` column), that column must also be non-missing and
   non-empty.

# Examples
```julia
# Keep only rows identified to genus level or finer
df_clean = drop_unresolved_taxa(df, "genus")

# Keep only rows identified to family level or finer
df_clean = drop_unresolved_taxa(df, "family")

# Works for any rank in the Linnaean hierarchy
df_clean = drop_unresolved_taxa(df, "order")
```
"""
function drop_unresolved_taxa(df::DataFrame, taxonomic_rank::AbstractString)::DataFrame
    drop_unresolved_taxa!(copy(df), taxonomic_rank)
end

"""
    drop_unresolved_taxa(df, taxon_field::Symbol) -> DataFrame

Convenience form that accepts a DataFrame column name instead of a rank string.

The taxonomic rank is technically a data value (`:accepted_rank == "genus"`),
while `taxon_field` is the column that carries the identification result for
that rank (`:genus == "Tyrannosaurus"`). Passing `:genus` here is therefore a
shortcut for `drop_unresolved_taxa(df, "genus")`: keep rows resolved to the same 
taxonomic level as the data in the given `taxon_field`

The one special case is `:accepted_name`, which holds the full species binomial
and so maps to `"species"` resolution.

# Examples
```julia

# Same as: df_clean = drop_unresolved_taxa(df, "genus")
df_clean = drop_unresolved_taxa(df, :genus)

# Same as: df_clean = drop_unresolved_taxa(df, "family")
df_clean = drop_unresolved_taxa(df, :family)

# Same as: df_clean = drop_unresolved_taxa(df, "species")
df_clean = drop_unresolved_taxa(df, :accepted_name)

```
"""
function drop_unresolved_taxa(df::DataFrame, taxon_field::Symbol)::DataFrame
    if taxon_field == :accepted_name
        drop_unresolved_taxa(df, "species")
    else
        drop_unresolved_taxa(df, String(taxon_field))
    end
end

"""
    drop_unresolved_taxa!(df, taxonomic_rank) -> DataFrame

In-place version of [`drop_unresolved_taxa`](@ref).
Modifies `df` directly and returns it.
"""
function drop_unresolved_taxa!(df::DataFrame, taxon_field::Symbol)::DataFrame  # see drop_unresolved_taxa(df, ::Symbol) for rationale
    if taxon_field == :accepted_name
        drop_unresolved_taxa!(df, "species")
    else
        drop_unresolved_taxa!(df, String(taxon_field))
    end
end

function drop_unresolved_taxa!(df::DataFrame, taxonomic_rank::AbstractString)::DataFrame
    valid_ranks = _pbdb_ranks_at_or_finer_than(taxonomic_rank)

    # 1. Filter by accepted_rank; rows with missing accepted_rank are dropped.
    subset!(df, :accepted_rank => ByRow(r -> r in valid_ranks); skipmissing = true)

    # 2. If a dedicated column exists for this rank (e.g. genus, family),
    #    also require it to be non-missing and non-empty.
    rank_col = Symbol(taxonomic_rank)
    if hasproperty(df, rank_col)
        subset!(df, rank_col => ByRow(v -> !ismissing(v) && !isempty(v)))
    end

    df
end

