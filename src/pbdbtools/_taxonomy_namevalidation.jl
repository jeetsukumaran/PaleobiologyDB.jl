
# ---------------------------------------------------------------------------
# Taxonomy name validation
#
# Validates taxon names against the PBDB database using one of two strategies:
#
#   :snapshot  (default) — uses a Scratch-managed local copy of the full PBDB
#              taxa list (~200 MB, ~50 K rows).  Lazily downloaded on first
#              use and refreshed when older than 30 days.  After the initial
#              load, lookups are O(1) in-memory Set checks.
#
#   :query     — calls pbdb_taxon() for each unique name.  Results for valid
#              names are cached by DataCaches; no explicit caching is added
#              here.  Use when you need the most current data or want to avoid
#              the large one-time download.
#
# Public API (all live in PaleobiologyDB.Curator namespace):
#   istaxon                  — single-name predicate
#   audit_taxonomy           — Bool mask for a DataFrame column
#   drop_unrecognized_names  — filtered DataFrame copy (non-mutating)
#   drop_unrecognized_names! — filtered DataFrame (in-place)
# ---------------------------------------------------------------------------

using DataFrames, CSV

# ---------------------------------------------------------------------------
# Taxa-list store registration
# ---------------------------------------------------------------------------

const _TAXA_LIST_STORE = LocalStore(
    :pbdb_taxa,
    "https://paleobiodb.org/data1.2/taxa/list.csv?all_records&vocab=pbdb",
    "pbdb_taxa.csv",
    30,
    "PBDB taxa list",
)
_register_store!(_TAXA_LIST_STORE)

# ---------------------------------------------------------------------------
# Lazy in-memory indices (built from the snapshot on first use)
# ---------------------------------------------------------------------------

# Set of all taxon_name strings — for fast existence checks.
const _TAXA_NAME_SET = Ref{Union{Nothing, Set{String}}}(nothing)

# name → set of ranks — for validate_correct_rank checks.
const _TAXA_RANK_INDEX = Ref{Union{Nothing, Dict{String, Set{String}}}}(nothing)

function _ensure_taxa_index(; force::Bool = false)
    if isnothing(_TAXA_NAME_SET[]) || force
        _ensure_populated!(_TAXA_LIST_STORE; force = force)
        path = _store_path(_TAXA_LIST_STORE)
        @info "PBDB taxa list: loading snapshot into memory …" path=path
        df = CSV.read(
            path, DataFrame;
            missingstring = ["", "missing"],
            types = Dict("taxon_name" => String, "taxon_rank" => String),
            silencewarnings = true,
        )
        df_valid = dropmissing(df, ["taxon_name", "taxon_rank"])
        names_set = Set{String}(df_valid.taxon_name)
        rank_idx  = Dict{String, Set{String}}()
        for row in eachrow(df_valid)
            push!(get!(Set{String}, rank_idx, row.taxon_name), row.taxon_rank)
        end
        _TAXA_NAME_SET[]   = names_set
        _TAXA_RANK_INDEX[] = rank_idx
        @info "PBDB taxa list: index ready" unique_names=length(names_set)
    end
end

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

"""
    istaxon(taxon_name; validation_authority=:snapshot, validate_correct_rank=nothing)

Return `true` if `taxon_name` is a non-empty string recognised by the PBDB taxonomy.

## Keyword arguments

- `validation_authority` — `:snapshot` (default) or `:query`.

  - `:snapshot`: looks up the name in a locally cached copy of the full PBDB taxa
    list (~200 MB, Scratch-managed).  The snapshot is downloaded on first use and
    refreshed automatically when older than 30 days.  After the initial load,
    lookups are O(1).
  - `:query`: calls `pbdb_taxon(; name = taxon_name)` directly.  Results for valid
    names are cached by DataCaches.  Slower for bulk use but always current.

- `validate_correct_rank` — `nothing` (default, rank not checked) or a `Symbol`
  such as `:family`, `:genus`.  When given, the name must also be listed at that
  rank in PBDB.

## Examples

```julia
istaxon("Pliosauridae")                                      # → true
istaxon("NO_FAMILY_SPECIFIED")                               # → false
istaxon("Pliosauridae"; validate_correct_rank = :family)    # → true
istaxon("Pliosauridae"; validate_correct_rank = :genus)     # → false
istaxon("Pliosauridae"; validation_authority = :query)      # live API call
```
"""
function istaxon(
    taxon_name::AbstractString;
    validation_authority::Symbol = :snapshot,
    validate_correct_rank::Union{Nothing, Symbol} = nothing,
)::Bool
    isempty(strip(taxon_name)) && return false

    if validation_authority == :query
        try
            result = pbdb_taxon(; name = taxon_name)
            isnothing(validate_correct_rank) && return true
            return !isempty(result) &&
                   hasproperty(result, :taxon_rank) &&
                   result[1, :taxon_rank] == String(validate_correct_rank)
        catch
            return false
        end
    end

    # :snapshot path
    _ensure_taxa_index()
    taxon_name in _TAXA_NAME_SET[] || return false
    isnothing(validate_correct_rank) && return true
    rank_str = String(validate_correct_rank)
    rank_str in get(_TAXA_RANK_INDEX[], taxon_name, Set{String}())
end

"""
    audit_taxonomy(df, taxon_field; validation_authority=:snapshot, validate_correct_rank=false)

Return a `Vector{Bool}` of length `nrow(df)` where `true` means the value in
`taxon_field` for that row is a valid PBDB taxon name (non-missing, non-empty,
and found in the database).

The result can be used directly with `df[mask, :]` or passed to
[`drop_unrecognized_names`](@ref).

## Keyword arguments

- `validation_authority` — passed to [`istaxon`](@ref).
- `validate_correct_rank` — when `true`, the expected rank is inferred from
  `taxon_field` (e.g. `:family` → checks `taxon_rank == "family"`).

## Example

```julia
mask = audit_taxonomy(df, :family)
mask = audit_taxonomy(df, :family; validate_correct_rank = true)
df[mask, :]
```
"""
function audit_taxonomy(
    df::DataFrame,
    taxon_field::Symbol;
    validation_authority::Symbol = :snapshot,
    validate_correct_rank::Bool = false,
)::Vector{Bool}
    rank_check = validate_correct_rank ? taxon_field : nothing
    col = df[:, taxon_field]

    # Deduplicate: validate each unique non-missing, non-empty name once.
    unique_names = unique(
        string(v) for v in col
        if !ismissing(v) && !isempty(strip(string(v)))
    )
    validity = Dict(
        n => istaxon(n; validation_authority, validate_correct_rank = rank_check)
        for n in unique_names
    )

    [
        !ismissing(v) &&
        !isempty(strip(string(v))) &&
        get(validity, string(v), false)
        for v in col
    ]
end

"""
    drop_unrecognized_names(df, taxon_field; validation_authority=:snapshot, validate_correct_rank=false)

Return a filtered copy of `df` keeping only rows where `taxon_field` contains a
PBDB-recognised taxon name (non-missing, non-empty, found in the database).

See [`audit_taxonomy`](@ref) for keyword argument semantics.
See also [`drop_unrecognized_names!`](@ref) for the in-place variant.

## Example

```julia
df_clean = drop_unrecognized_names(df, :family)
df_clean = drop_unrecognized_names(df, :family; validate_correct_rank = true)
```
"""
function drop_unrecognized_names(
    df::DataFrame,
    taxon_field::Symbol;
    validation_authority::Symbol = :snapshot,
    validate_correct_rank::Bool = false,
)::DataFrame
    mask = audit_taxonomy(df, taxon_field; validation_authority, validate_correct_rank)
    df[mask, :]
end

"""
    drop_unrecognized_names!(df, taxon_field; validation_authority=:snapshot, validate_correct_rank=false)

In-place variant of [`drop_unrecognized_names`](@ref).  Removes rows from `df`
where `taxon_field` is missing, empty, or not found in the PBDB taxonomy.
Returns `df`.

## Example

```julia
drop_unrecognized_names!(df, :family)
```
"""
function drop_unrecognized_names!(
    df::DataFrame,
    taxon_field::Symbol;
    validation_authority::Symbol = :snapshot,
    validate_correct_rank::Bool = false,
)::DataFrame
    mask = audit_taxonomy(df, taxon_field; validation_authority, validate_correct_rank)
    deleteat!(df, findall(!, mask))
    df
end
