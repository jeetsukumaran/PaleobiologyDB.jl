
using DataFrames

export filter_minimum_taxonomic_resolution,
       filter_minimum_taxonomic_resolution!

# ---------------------------------------------------------------------------
# Taxonomic rank hierarchy
# ---------------------------------------------------------------------------

# PBDB `accepted_rank` values ordered from most specific to most general.
# Used to resolve "at least as specific as X" queries.
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

function _pbdb_rank_index(rank::Symbol)::Int
    rank_str = String(rank)
    idx = findfirst(==(rank_str), PBDB_RANK_HIERARCHY)
    if isnothing(idx)
        throw(ArgumentError(
            "Unknown taxonomic rank: :$(rank). " *
            "Must be one of: $(join(PBDB_RANK_HIERARCHY, ", "))"
        ))
    end
    idx
end

function _pbdb_ranks_at_or_finer_than(rank::Symbol)::Vector{String}
    PBDB_RANK_HIERARCHY[1:_pbdb_rank_index(rank)]
end

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

"""
    filter_minimum_taxonomic_resolution(df, taxonomic_rank) -> DataFrame

Return a filtered copy of `df` containing only rows that meet the minimum
taxonomic resolution specified by `taxonomic_rank`.

Two criteria are applied:
1. The `accepted_rank` column must be at `taxonomic_rank` or finer (more
   specific). For example, `:genus` accepts `"genus"`, `"species"`, and
   `"subspecies"`; `:family` additionally accepts `"subfamily"`, `"tribe"`,
   `"subtribe"`. Rows with a missing `accepted_rank` are dropped.
2. If `df` contains a column whose name matches `taxonomic_rank` (e.g. a
   `:genus` or `:family` column), that column must also be non-missing and
   non-empty.

# Examples
```julia
# Keep only rows identified to genus level or finer
df_clean = filter_minimum_taxonomic_resolution(df, :genus)

# Keep only rows identified to family level or finer
df_clean = filter_minimum_taxonomic_resolution(df, :family)

# Works for any rank in the Linnaean hierarchy
df_clean = filter_minimum_taxonomic_resolution(df, :order)
```
"""
function filter_minimum_taxonomic_resolution(df::DataFrame, taxonomic_rank::Symbol)::DataFrame
    filter_minimum_taxonomic_resolution!(copy(df), taxonomic_rank)
end

"""
    filter_minimum_taxonomic_resolution!(df, taxonomic_rank) -> DataFrame

In-place version of [`filter_minimum_taxonomic_resolution`](@ref).
Modifies `df` directly and returns it.
"""
function filter_minimum_taxonomic_resolution!(df::DataFrame, taxonomic_rank::Symbol)::DataFrame
    valid_ranks = _pbdb_ranks_at_or_finer_than(taxonomic_rank)

    # 1. Filter by accepted_rank; rows with missing accepted_rank are dropped.
    subset!(df, :accepted_rank => ByRow(r -> r in valid_ranks); skipmissing = true)

    # 2. If a dedicated column exists for this rank (e.g. :genus, :family),
    #    also require it to be non-missing and non-empty.
    if hasproperty(df, taxonomic_rank)
        subset!(df, taxonomic_rank => ByRow(v -> !isempty(v)); skipmissing = true)
    end

    df
end

