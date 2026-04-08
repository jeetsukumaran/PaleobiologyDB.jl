
# ---------------------------------------------------------------------------
# Taxonomy augmentation
#
# Enriches an occurrences DataFrame with the full taxonomic hierarchy for
# each row, resolved from the Scratch-cached PBDB taxa list snapshot (the
# same file used by drop_unrecognized_taxa).
#
# The snapshot (taxa/list.csv?all_records&vocab=pbdb) includes orig_no,
# taxon_name, taxon_rank, accepted_no, and parent_no for every taxon,
# which is sufficient to walk up any parent chain.
#
# Two lazy in-memory indices are built on first use:
#   _TAXA_HIERARCHY_NAME_INDEX  taxon_name → orig_no  (accepted entries only)
#   _TAXA_HIERARCHY_NO_INDEX    orig_no    → (name, rank, parent_no)
#
# Public API:
#   augment_taxonomy   — non-mutating; returns an enriched copy of df
# ---------------------------------------------------------------------------

using DataFrames, CSV
using ..Depot

export augment_taxonomy

# ---------------------------------------------------------------------------
# Lazy in-memory hierarchy indices
# ---------------------------------------------------------------------------

const _TaxonInfo = @NamedTuple{name::String, rank::String, parent_no::Union{Int,Missing}}

const _TAXA_HIERARCHY_NAME_INDEX = Ref{Union{Nothing, Dict{String, Int}}}(nothing)
const _TAXA_HIERARCHY_NO_INDEX   = Ref{Union{Nothing, Dict{Int, _TaxonInfo}}}(nothing)

const _PBDB_RANK_SET = Set{String}(PBDB_RANK_HIERARCHY)

function _ensure_hierarchy_index(; force::Bool = false)
    if isnothing(_TAXA_HIERARCHY_NAME_INDEX[]) || force
        Depot._ensure_populated!(_TAXA_LIST_STORE; force = force)
        path = Depot._store_path(_TAXA_LIST_STORE)
        @debug "PBDB hierarchy index: loading snapshot …" path = path

        df = CSV.read(
            path, DataFrame;
            missingstring   = ["", "missing"],
            types           = Dict(
                "orig_no"     => Union{Int, Missing},
                "accepted_no" => Union{Int, Missing},
                "parent_no"   => Union{Int, Missing},
                "taxon_name"  => String,
                "taxon_rank"  => String,
            ),
            silencewarnings = true,
        )

        # Drop rows we cannot use
        dropmissing!(df, [:orig_no, :taxon_name, :taxon_rank])

        name_to_no = Dict{String, Int}()
        no_to_info = Dict{Int, _TaxonInfo}()

        for row in eachrow(df)
            no   = row.orig_no
            name = row.taxon_name
            rank = row.taxon_rank
            acc  = row.accepted_no       # may be missing
            par  = row.parent_no         # may be missing

            # Full traversal index — every row
            no_to_info[no] = (name = name, rank = rank, parent_no = par)

            # Name-lookup index — accepted (non-synonym) rows only
            if !ismissing(acc) && acc == no
                name_to_no[name] = no
            end
        end

        _TAXA_HIERARCHY_NAME_INDEX[] = name_to_no
        _TAXA_HIERARCHY_NO_INDEX[]   = no_to_info
        @debug "PBDB hierarchy index: ready" n_accepted = length(name_to_no) n_total = length(no_to_info)
    end
end

# ---------------------------------------------------------------------------
# Internal: walk parent chain for a single taxon name
# ---------------------------------------------------------------------------

function _get_taxon_hierarchy(name::AbstractString)::Dict{String, String}
    name_to_no = _TAXA_HIERARCHY_NAME_INDEX[]
    no_to_info = _TAXA_HIERARCHY_NO_INDEX[]

    result  = Dict{String, String}()
    orig_no = get(name_to_no, name, nothing)
    isnothing(orig_no) && return result

    visited = Set{Int}()
    cur_no  = orig_no

    while !isnothing(cur_no)
        cur_no in visited && break          # cycle guard
        push!(visited, cur_no)

        info = get(no_to_info, cur_no, nothing)
        isnothing(info) && break

        if info.rank in _PBDB_RANK_SET
            result[info.rank] = info.name
        end

        cur_no = ismissing(info.parent_no) ? nothing : info.parent_no
    end

    result
end

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

"""
    augment_taxonomy(df; nodata=missing, fieldname_prefix="taxonomy_", taxonomy_separator=" > ") -> DataFrame

Return a copy of `df` with one column per taxonomic rank in [`PBDB_RANK_HIERARCHY`](@ref) and a
combined taxonomy string column, all resolved from the Scratch-cached PBDB taxa list snapshot.

## New columns (using default prefix `"taxonomy_"`)

One column per rank, from most specific to most general:

    taxonomy_subspecies  taxonomy_species  taxonomy_genus  taxonomy_subtribe  taxonomy_tribe
    taxonomy_subfamily   taxonomy_family   taxonomy_superfamily  taxonomy_infraorder
    taxonomy_suborder    taxonomy_order    taxonomy_superorder  taxonomy_infraclass
    taxonomy_subclass    taxonomy_class    taxonomy_superclass  taxonomy_subphylum
    taxonomy_phylum      taxonomy_kingdom

Plus a summary column:

    taxonomy_clades — non-missing/non-empty rank values joined by `taxonomy_separator`,
                      ordered from most general (kingdom) to most specific (subspecies).

## Data source

Each row is resolved by looking up its `accepted_name` value in the hierarchy index built
from the Scratch-managed PBDB taxa list snapshot (same file used by
[`drop_unrecognized_taxa`](@ref)).  The snapshot is downloaded on first use and refreshed
automatically when older than 30 days.  If `accepted_name` is missing or unrecognised,
all new columns for that row are set to `nodata`.

## Keyword arguments

- `nodata`              — value written for unknown/unresolvable ranks (default: `missing`)
- `fieldname_prefix`    — prefix applied to every new column name (default: `"taxonomy_"`)
- `taxonomy_separator`  — string used to join rank values in the taxonomy column (default: `" > "`)

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy

df = pbdb_occurrences(base_name = "Carnivora", interval = "Miocene", limit = 500)

df2 = augment_taxonomy(df)

# Filter for a specific subfamily
borophaginae = df2[
    .!ismissing.(df2.taxonomy_subfamily) .&& df2.taxonomy_subfamily .== "Borophaginae",
    :,
]

# Inspect a taxonomy string
df2.taxonomy_clades[1]
# → "Animalia > Chordata > Mammalia > Carnivora > Canidae > Borophaginae > Epicyon"

# Use a different fill value
df3 = augment_taxonomy(df; nodata = "")
```

See also [`PBDB_RANK_HIERARCHY`](@ref).
"""
function augment_taxonomy(
    df::AbstractDataFrame;
    nodata::Any          = missing,
    fieldname_prefix::String = "taxonomy_",
    taxonomy_separator::String = " > ",
)::DataFrame
    hasproperty(df, :accepted_name) ||
        throw(ArgumentError(
            "augment_taxonomy requires an `accepted_name` column. " *
            "Make sure you are passing an occurrences DataFrame from pbdb_occurrences."
        ))

    _ensure_hierarchy_index()

    # Resolve each unique accepted_name once
    unique_names = unique(
        string(v) for v in df.accepted_name if !ismissing(v) && !isempty(strip(string(v)))
    )
    hierarchy_cache = Dict{String, Dict{String,String}}(
        n => _get_taxon_hierarchy(n) for n in unique_names
    )

    result = copy(df)

    # Helper: value for a single (name, rank) pair
    function _rank_value(accepted_name, rank)
        ismissing(accepted_name) && return nodata
        h = get(hierarchy_cache, string(accepted_name), nothing)
        isnothing(h) && return nodata
        v = get(h, rank, nothing)
        isnothing(v) ? nodata : v
    end

    # Add one column per rank
    for rank in PBDB_RANK_HIERARCHY
        col_name = Symbol(fieldname_prefix * rank)
        result[!, col_name] = [_rank_value(v, rank) for v in df.accepted_name]
    end

    # Add taxonomy string column (most general → most specific)
    tax_col = Symbol(fieldname_prefix * "clades")
    result[!, tax_col] = map(df.accepted_name) do accepted_name
        ismissing(accepted_name) && return ""
        h = get(hierarchy_cache, string(accepted_name), nothing)
        isnothing(h) && return ""
        parts = String[]
        for rank in Iterators.reverse(PBDB_RANK_HIERARCHY)
            v = get(h, rank, nothing)
            isnothing(v) || isempty(v) || push!(parts, v)
        end
        join(parts, taxonomy_separator)
    end

    result
end
