
using DataFrames

export pbdb_audit_occurrence_taxonomy,
       pbdb_audit_occurrence_taxonomy!

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
    pbdb_audit_occurrence_taxonomy(df, taxonomic_rank) -> DataFrame

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
df_clean = pbdb_audit_occurrence_taxonomy(df, :genus)

# Keep only rows identified to family level or finer
df_clean = pbdb_audit_occurrence_taxonomy(df, :family)

# Works for any rank in the Linnaean hierarchy
df_clean = pbdb_audit_occurrence_taxonomy(df, :order)
```
"""
function pbdb_audit_occurrence_taxonomy(df::DataFrame, taxonomic_rank::Symbol)::DataFrame
    pbdb_audit_occurrence_taxonomy!(copy(df), taxonomic_rank)
end

"""
    pbdb_audit_occurrence_taxonomy!(df, taxonomic_rank) -> DataFrame

In-place version of [`pbdb_audit_occurrence_taxonomy`](@ref).
Modifies `df` directly and returns it.
"""
function pbdb_audit_occurrence_taxonomy!(df::DataFrame, taxonomic_rank::Symbol)::DataFrame
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

