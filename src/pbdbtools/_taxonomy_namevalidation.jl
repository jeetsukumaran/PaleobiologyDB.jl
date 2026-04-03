
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
# Public API (all live in PaleobiologyDB.DataCurator namespace):
#   istaxon                  — single-name predicate
#   audit_taxonomy           — Bool mask for a DataFrame column
#   drop_unrecognized_taxa  — filtered DataFrame copy (non-mutating)
#   drop_unrecognized_taxa! — filtered DataFrame (in-place)
# ---------------------------------------------------------------------------

using DataFrames, CSV
using .Store

# ---------------------------------------------------------------------------
# Taxa-list store registration
# ---------------------------------------------------------------------------

const _TAXA_LIST_STORE = Store.LocalStore(
    :pbdb_taxa,
    "https://paleobiodb.org/data1.2/taxa/list.csv?all_records&vocab=pbdb",
    "pbdb_taxa.csv",
    30,
    "PBDB taxa list",
)
Store._register_store!(_TAXA_LIST_STORE)

# ---------------------------------------------------------------------------
# Lazy in-memory indices (built from the snapshot on first use)
# ---------------------------------------------------------------------------

# Set of all taxon_name strings — for fast existence checks.
const _TAXA_NAME_SET = Ref{Union{Nothing, Set{String}}}(nothing)

function _ensure_taxa_index(; force::Bool = false)
    if isnothing(_TAXA_NAME_SET[]) || force
        _ensure_populated!(_TAXA_LIST_STORE; force = force)
        path = _store_path(_TAXA_LIST_STORE)
        @debug "PBDB taxonomic authority: loading snapshot into memory …" path=path
        df = CSV.read(
            path, DataFrame;
            missingstring = ["", "missing"],
            types = Dict("taxon_name" => String),
            silencewarnings = true,
        )
        df_valid = dropmissing(df, ["taxon_name"])
        _TAXA_NAME_SET[] = Set{String}(df_valid.taxon_name)
        @debug "PBDB taxonomic authority: index ready" unique_names=length(_TAXA_NAME_SET[])
    end
end

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

"""
    istaxon(taxon_name; validation_authority=:snapshot)

Return `true` if `taxon_name` is a non-empty string recognised by the PBDB taxonomy.

## Keyword arguments

- `validation_authority` — `:snapshot` (default) or `:query`.

  - `:snapshot`: looks up the name in a locally cached copy of the full PBDB taxa
    list (~200 MB, Scratch-managed).  The snapshot is downloaded on first use and
    refreshed automatically when older than 30 days.  After the initial load,
    lookups are O(1).
  - `:query`: calls `pbdb_taxon(; name = taxon_name)` directly.  Results for valid
    names are cached by DataCaches.  Slower for bulk use but always current.

## Examples

```julia
istaxon("Pliosauridae")                                  # → true
istaxon("NO_FAMILY_SPECIFIED")                           # → false
istaxon("Pliosauridae"; validation_authority = :query)  # live API call
```
"""
function istaxon(
    taxon_name::AbstractString;
    validation_authority::Symbol = :snapshot,
)::Bool
    isempty(strip(taxon_name)) && return false

    if validation_authority == :query
        try
            result = pbdb_taxon(; name = taxon_name)
            return !isempty(result)
        catch
            return false
        end
    end

    # :snapshot path
    _ensure_taxa_index()
    taxon_name in _TAXA_NAME_SET[]
end

"""
    audit_taxonomy(df, taxon_field; validation_authority=:snapshot)

Return a `Vector{Bool}` of length `nrow(df)` where `true` means the value in
`taxon_field` for that row is a valid PBDB taxon name (non-missing, non-empty,
and found in the database).

The result can be used directly with `df[mask, :]` or passed to
[`drop_unrecognized_taxa`](@ref).

## Keyword arguments

- `validation_authority` — passed to [`istaxon`](@ref).

## Example

```julia
mask = audit_taxonomy(df, :family)
df[mask, :]
```
"""
function audit_taxonomy(
    df::DataFrame,
    taxon_field::Symbol;
    validation_authority::Symbol = :snapshot,
)::Vector{Bool}
    col = df[:, taxon_field]

    # Deduplicate: validate each unique non-missing, non-empty name once.
    unique_names = unique(
        string(v) for v in col
        if !ismissing(v) && !isempty(strip(string(v)))
    )
    validity = Dict(
        n => istaxon(n; validation_authority)
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
    drop_unrecognized_taxa(df, taxon_field; validation_authority=:snapshot)

Return a filtered copy of `df` keeping only rows where `taxon_field` contains a
PBDB-recognised taxon name (non-missing, non-empty, found in the database).

See [`audit_taxonomy`](@ref) for keyword argument semantics.
See also [`drop_unrecognized_taxa!`](@ref) for the in-place variant.

## Example

```julia
df_clean = drop_unrecognized_taxa(df, :family)
```
"""
function drop_unrecognized_taxa(
    df::DataFrame,
    taxon_field::Symbol;
    validation_authority::Symbol = :snapshot,
)::DataFrame
    mask = audit_taxonomy(df, taxon_field; validation_authority)
    df[mask, :]
end

"""
    drop_unrecognized_taxa!(df, taxon_field; validation_authority=:snapshot)

In-place variant of [`drop_unrecognized_taxa`](@ref).  Removes rows from `df`
where `taxon_field` is missing, empty, or not found in the PBDB taxonomy.
Returns `df`.

## Example

```julia
drop_unrecognized_taxa!(df, :family)
```
"""
function drop_unrecognized_taxa!(
    df::DataFrame,
    taxon_field::Symbol;
    validation_authority::Symbol = :snapshot,
)::DataFrame
    mask = audit_taxonomy(df, taxon_field; validation_authority)
    deleteat!(df, findall(!, mask))
    df
end
