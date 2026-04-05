# ---------------------------------------------------------------------------
# Taxonomy tree queries
#
# Provides functions to navigate the PBDB taxonomic hierarchy by name,
# walking either downward (ls_child_taxa) or upward (ls_parent_taxa).
#
# Both functions are backed by the same Scratch-cached PBDB taxa list
# snapshot used by augment_taxonomy and drop_unrecognized_taxa.
#
# Indices reused from _taxonomy_augment.jl (included before this file):
#   _TAXA_HIERARCHY_NAME_INDEX  taxon_name → orig_no  (accepted entries)
#   _TAXA_HIERARCHY_NO_INDEX    orig_no    → (name, rank, parent_no)
#
# New lazy index built here:
#   _TAXA_CHILDREN_INDEX        orig_no    → Vector{Int} of child orig_nos
#
# Public API:
#   ls_child_taxa  — names of descendants at a given rank (or all descendants)
#   ls_parent_taxa — names of ancestors at a given rank (or all ancestors)
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Lazy children index (reverse of parent_no)
# ---------------------------------------------------------------------------

const _TAXA_CHILDREN_INDEX = Ref{Union{Nothing, Dict{Int, Vector{Int}}}}(nothing)

function _ensure_children_index(; force::Bool = false)
    if isnothing(_TAXA_CHILDREN_INDEX[]) || force
        _ensure_hierarchy_index(; force = force)
        no_to_info = _TAXA_HIERARCHY_NO_INDEX[]
        children = Dict{Int, Vector{Int}}()
        for (orig_no, info) in no_to_info
            ismissing(info.parent_no) && continue
            push!(get!(children, info.parent_no, Int[]), orig_no)
        end
        _TAXA_CHILDREN_INDEX[] = children
        @debug "PBDB children index: ready" n_parents = length(children)
    end
end

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

"""
    ls_child_taxa(taxon_name, taxonomic_rank=nothing) -> Vector{String}

Return the names of all descendants of `taxon_name` at the given
`taxonomic_rank`, resolved from the Scratch-cached PBDB taxa list snapshot.

If `taxonomic_rank` is `nothing`, all descendants at every rank are returned.

## Arguments

- `taxon_name` — accepted taxon name exactly as it appears in PBDB
  (e.g. `"Carnivora"`, `"Canidae"`, `"Canis"`).
- `taxonomic_rank` — rank string, or `nothing` (default).  Must be one of:

      "subspecies" "species" "genus" "subtribe" "tribe" "subfamily"
      "family" "superfamily" "infraorder" "suborder" "order"
      "superorder" "infraclass" "subclass" "class" "superclass"
      "subphylum" "phylum" "kingdom"

## Returns

A sorted `Vector{String}` of matching taxon names.  Returns an empty vector
when `taxon_name` is not found in the PBDB snapshot.

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.DataCurator

ls_child_taxa("Carnivora", "family")   # → ["Ailuridae", "Canidae", "Felidae", …]
ls_child_taxa("Canidae", "genus")      # → ["Canis", "Lycaon", "Vulpes", …]
ls_child_taxa("Canis", "species")      # → ["Canis aureus", "Canis lupus", …]
ls_child_taxa("Carnivora")             # → all descendants at every rank
ls_child_taxa("INVALID", "genus")      # → String[]
```

See also [`ls_parent_taxa`](@ref), [`augment_taxonomy`](@ref).
"""
function ls_child_taxa(
    taxon_name::AbstractString,
    taxonomic_rank::Union{AbstractString, Nothing} = nothing,
)::Vector{String}
    _ensure_children_index()

    name_to_no    = _TAXA_HIERARCHY_NAME_INDEX[]
    no_to_info    = _TAXA_HIERARCHY_NO_INDEX[]
    children_idx  = _TAXA_CHILDREN_INDEX[]

    start_no = get(name_to_no, taxon_name, nothing)
    isnothing(start_no) && return String[]

    target_idx = isnothing(taxonomic_rank) ? nothing : _pbdb_rank_index(taxonomic_rank)

    results = String[]
    visited = Set{Int}()
    queue   = [start_no]

    while !isempty(queue)
        current = popfirst!(queue)
        current in visited && continue
        push!(visited, current)

        for child_no in get(children_idx, current, Int[])
            child_no in visited && continue
            info = get(no_to_info, child_no, nothing)
            isnothing(info) && continue

            child_rank_idx = findfirst(==(info.rank), PBDB_RANK_HIERARCHY)

            if isnothing(target_idx)
                # No rank filter — collect everything, recurse everywhere
                push!(results, info.name)
                push!(queue, child_no)
            elseif isnothing(child_rank_idx)
                # Unknown rank — recurse in case useful descendants lie below
                push!(queue, child_no)
            elseif child_rank_idx == target_idx
                # Exact match — collect, do not recurse further
                push!(results, info.name)
            elseif child_rank_idx > target_idx
                # Child is coarser than target (e.g. child=family, target=genus)
                # — an intermediate node; recurse to find finer descendants
                push!(queue, child_no)
            end
            # child_rank_idx < target_idx: child is finer than target — skip
        end
    end

    sort!(unique!(results))
end

"""
    ls_parent_taxa(taxon_name, taxonomic_rank=nothing) -> Vector{String}

Return the names of all ancestors of `taxon_name` at the given
`taxonomic_rank`, resolved from the Scratch-cached PBDB taxa list snapshot.

If `taxonomic_rank` is `nothing`, all ancestors at every rank are returned,
ordered from immediate parent up to the root.

## Arguments

- `taxon_name` — accepted taxon name exactly as it appears in PBDB
  (e.g. `"Canis lupus"`, `"Canis"`, `"Canidae"`).
- `taxonomic_rank` — rank string, or `nothing` (default).  Must be one of:

      "subspecies" "species" "genus" "subtribe" "tribe" "subfamily"
      "family" "superfamily" "infraorder" "suborder" "order"
      "superorder" "infraclass" "subclass" "class" "superclass"
      "subphylum" "phylum" "kingdom"

## Returns

A `Vector{String}` of matching ancestor names, ordered child → root.
Returns an empty vector when `taxon_name` is not found in the PBDB snapshot.

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.DataCurator

ls_parent_taxa("Canis lupus")            # → ["Canis", "Canidae", …, "Animalia"]
ls_parent_taxa("Canis", "family")        # → ["Canidae"]
ls_parent_taxa("Canis", "order")         # → ["Carnivora"]
ls_parent_taxa("Canis", nothing)         # → all ancestors, child → root
ls_parent_taxa("INVALID", "family")      # → String[]
```

See also [`ls_child_taxa`](@ref), [`augment_taxonomy`](@ref).
"""
function ls_parent_taxa(
    taxon_name::AbstractString,
    taxonomic_rank::Union{AbstractString, Nothing} = nothing,
)::Vector{String}
    _ensure_hierarchy_index()

    name_to_no = _TAXA_HIERARCHY_NAME_INDEX[]
    no_to_info = _TAXA_HIERARCHY_NO_INDEX[]

    start_no = get(name_to_no, taxon_name, nothing)
    isnothing(start_no) && return String[]

    # Validate rank early so a bad argument fails before any traversal
    if !isnothing(taxonomic_rank)
        _pbdb_rank_index(taxonomic_rank)   # throws ArgumentError if unknown
    end

    results = String[]
    visited = Set{Int}()
    cur_no  = start_no

    while true
        cur_no in visited && break
        push!(visited, cur_no)

        info = get(no_to_info, cur_no, nothing)
        isnothing(info) && break
        ismissing(info.parent_no) && break

        parent_no = info.parent_no
        parent_info = get(no_to_info, parent_no, nothing)
        isnothing(parent_info) && break

        if isnothing(taxonomic_rank) || parent_info.rank == taxonomic_rank
            push!(results, parent_info.name)
        end

        cur_no = parent_no
    end

    results
end

# ---------------------------------------------------------------------------
# Rank enumeration
# ---------------------------------------------------------------------------

"""
    ls_taxonomic_ranks() -> Vector{String}

Return all taxonomic rank names recognised by the PBDB, ordered from most
specific (subspecies) to most general (kingdom).

The returned vector is a copy of [`PBDB_RANK_HIERARCHY`](@ref); mutating it
has no effect on the package's internal state.

## Returns

A `Vector{String}` of 19 ranks:

    "subspecies" "species" "genus" "subtribe" "tribe" "subfamily"
    "family" "superfamily" "infraorder" "suborder" "order"
    "superorder" "infraclass" "subclass" "class" "superclass"
    "subphylum" "phylum" "kingdom"

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.DataCurator

ls_taxonomic_ranks()
# → ["subspecies", "species", "genus", …, "kingdom"]

# Enumerate from coarsest to finest
reverse(ls_taxonomic_ranks())
```

See also [`PBDB_RANK_HIERARCHY`](@ref), [`ls_registered_taxa`](@ref),
[`ls_child_taxa`](@ref), [`ls_parent_taxa`](@ref).
"""
function ls_taxonomic_ranks()::Vector{String}
    copy(PBDB_RANK_HIERARCHY)
end

# ---------------------------------------------------------------------------
# Registered taxa listing
# ---------------------------------------------------------------------------

"""
    ls_registered_taxa(taxon_name=nothing) -> Vector{String}

Return accepted taxon names from the Scratch-cached PBDB taxa list snapshot
that match the given filter.

## Arguments

- `taxon_name` — filter criterion; one of:
  - `nothing` (default) — return **all** accepted names.
  - `Regex` — return names where `occursin(taxon_name, name)` is true.
  - `AbstractVector{<:Regex}` — return names matching **any** pattern
    (union semantics).

Only accepted (non-synonym) names are included, consistent with
[`ls_child_taxa`](@ref) and [`ls_parent_taxa`](@ref).

## Returns

A sorted `Vector{String}`.  Returns an empty vector when no names match.

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.DataCurator

# All accepted names (tens of thousands of entries)
all_taxa = ls_registered_taxa()

# Names containing "Canis" (case-sensitive)
ls_registered_taxa(r"Canis")
# → ["Canis", "Canis aureus", "Canis lupus", …]

# Case-insensitive search
ls_registered_taxa(r"canid"i)

# Union of two patterns
ls_registered_taxa([r"^Canis\b", r"^Vulpes\b"])
# → ["Canis", "Canis aureus", …, "Vulpes", "Vulpes vulpes", …]
```

See also [`ls_taxonomic_ranks`](@ref), [`ls_child_taxa`](@ref),
[`ls_parent_taxa`](@ref), [`istaxon`](@ref).
"""
function ls_registered_taxa(
    taxon_name::Union{Nothing, Regex, AbstractVector{<:Regex}} = nothing,
)::Vector{String}
    _ensure_hierarchy_index()
    name_to_no = _TAXA_HIERARCHY_NAME_INDEX[]

    if isnothing(taxon_name)
        return sort!(collect(keys(name_to_no)))
    elseif taxon_name isa Regex
        pattern = taxon_name
        return sort!([name for name in keys(name_to_no) if occursin(pattern, name)])
    else
        # AbstractVector{<:Regex} — union match
        patterns = taxon_name
        return sort!([name for name in keys(name_to_no) if any(r -> occursin(r, name), patterns)])
    end
end

# ---------------------------------------------------------------------------
# taxon_occursin — internals
# ---------------------------------------------------------------------------

# Column symbols produced by augment_taxonomy (default prefix "taxon_")
const _AUGMENTED_TAXON_COLS = let
    cols = [Symbol("taxon_" * r) for r in PBDB_RANK_HIERARCHY]
    push!(cols, :taxon_taxonomy)
    cols
end

# Original taxon columns from the PBDB API response (rank names + accepted_name)
const _ORIGINAL_TAXON_COLS = let
    cols = [Symbol(r) for r in PBDB_RANK_HIERARCHY]
    push!(cols, :accepted_name)
    cols
end

# Return (working_df, search_cols) for taxon_occursin.
#
# Priority:
#   1. Any augmented column (taxon_<rank>, taxon_taxonomy) already present → use df as-is.
#   2. autoaugment=true and :accepted_name present → call augment_taxonomy, use augmented cols.
#   3. Fallback → use original taxon columns present in df.
function _taxonomy_search_setup(df::DataFrame; autoaugment::Bool = true)
    present_augmented = filter(col -> hasproperty(df, col), _AUGMENTED_TAXON_COLS)
    if !isempty(present_augmented)
        return df, present_augmented
    end

    if autoaugment && hasproperty(df, :accepted_name)
        df_work = augment_taxonomy(df)
        search_cols = filter(col -> hasproperty(df_work, col), _AUGMENTED_TAXON_COLS)
        return df_work, search_cols
    end

    present_original = filter(col -> hasproperty(df, col), _ORIGINAL_TAXON_COLS)
    return df, present_original
end

# Return true if any non-missing, non-empty value in `row` for `cols` satisfies
# `criterion(val::String)`.  Short-circuits on first match.
function _row_matches_any(row, cols::Vector{Symbol}, criterion)::Bool
    for col in cols
        val = row[col]
        ismissing(val) && continue
        s = string(val)
        isempty(s) && continue
        criterion(s) && return true
    end
    return false
end

# ---------------------------------------------------------------------------
# taxon_occursin — public API
# ---------------------------------------------------------------------------

"""
    taxon_occursin(name, df; autoaugment=true) -> Vector{Bool}

Return a `Vector{Bool}` of length `nrow(df)` indicating which rows contain
`name` in any relevant taxonomic column.

## Method signatures

```julia
taxon_occursin(name::Regex,                          df; autoaugment=true)
taxon_occursin(name::AbstractString,                 df; autoaugment=true)
taxon_occursin(names::AbstractVector{<:AbstractString}, df; autoaugment=true)
taxon_occursin(names::AbstractVector{<:Regex},       df; autoaugment=true)
```

## Matching semantics

- **`Regex`** — `occursin(name, value)` for each column value.
- **`AbstractString`** — exact equality (`==`), case-sensitive.
- **`AbstractVector{<:AbstractString}`** — Set membership; a row matches if any
  column value is an element of `names`.
- **`AbstractVector{<:Regex}`** — union match; a row matches if any column
  value satisfies any pattern in `names`.

## Column selection

Columns to search are chosen by the following priority:

1. **Augmented columns already present** — if `df` has any column of the form
   `taxon_<rank>` or `taxon_taxonomy` (as added by [`augment_taxonomy`](@ref)),
   those columns are searched regardless of `autoaugment`.
2. **Auto-augmentation** — if no augmented columns are present and
   `autoaugment=true` (default) and `df` has an `:accepted_name` column,
   [`augment_taxonomy`](@ref) is called on a copy of `df` and its augmented
   columns are searched.
3. **Fallback** — columns whose name matches a rank in [`PBDB_RANK_HIERARCHY`](@ref)
   plus `:accepted_name`, restricted to those actually present in `df`.

Note: `:taxon_taxonomy` contains a full hierarchy string such as
`"Animalia > Chordata > … > Canis"`.  Regex patterns will match it; exact
strings (e.g. `"Canis"`) will not — use the per-rank column (`taxon_genus`)
for exact matching.

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.DataCurator

df = pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")

# Exact string match
mask = taxon_occursin("Canis", df)
df[mask, :]

# Regex match
mask = taxon_occursin(r"^Canis\b", df)

# Multiple exact names
mask = taxon_occursin(["Canis", "Vulpes"], df)

# Multiple patterns (union)
mask = taxon_occursin([r"^Canis\b", r"^Vulpes\b"], df)

# Suppress auto-augmentation for a pre-augmented DataFrame
df2 = augment_taxonomy(df)
mask = taxon_occursin("Canidae", df2; autoaugment=false)
```

See also [`augment_taxonomy`](@ref), [`ls_child_taxa`](@ref),
[`ls_parent_taxa`](@ref), [`ls_registered_taxa`](@ref).
"""
function taxon_occursin(
    name::Regex,
    df::DataFrame;
    autoaugment::Bool = true,
)::Vector{Bool}
    df_work, cols = _taxonomy_search_setup(df; autoaugment)
    criterion = (s::String) -> occursin(name, s)
    [_row_matches_any(row, cols, criterion) for row in eachrow(df_work)]
end

"""
    taxon_occursin(name::AbstractString, df; autoaugment=true) -> Vector{Bool}

Exact-string variant of [`taxon_occursin`](@ref).  Returns `true` for rows
where any relevant taxonomic column equals `name` (case-sensitive).
"""
function taxon_occursin(
    name::AbstractString,
    df::DataFrame;
    autoaugment::Bool = true,
)::Vector{Bool}
    df_work, cols = _taxonomy_search_setup(df; autoaugment)
    criterion = (s::String) -> s == name
    [_row_matches_any(row, cols, criterion) for row in eachrow(df_work)]
end

"""
    taxon_occursin(names::AbstractVector{<:AbstractString}, df; autoaugment=true) -> Vector{Bool}

Set-membership variant of [`taxon_occursin`](@ref).  Returns `true` for rows
where any relevant taxonomic column value is contained in `names`.
"""
function taxon_occursin(
    names::AbstractVector{<:AbstractString},
    df::DataFrame;
    autoaugment::Bool = true,
)::Vector{Bool}
    df_work, cols = _taxonomy_search_setup(df; autoaugment)
    name_set = Set{String}(names)
    criterion = (s::String) -> s in name_set
    [_row_matches_any(row, cols, criterion) for row in eachrow(df_work)]
end

"""
    taxon_occursin(names::AbstractVector{<:Regex}, df; autoaugment=true) -> Vector{Bool}

Multi-pattern variant of [`taxon_occursin`](@ref).  Returns `true` for rows
where any relevant taxonomic column value matches at least one pattern in `names`.
"""
function taxon_occursin(
    names::AbstractVector{<:Regex},
    df::DataFrame;
    autoaugment::Bool = true,
)::Vector{Bool}
    df_work, cols = _taxonomy_search_setup(df; autoaugment)
    criterion = (s::String) -> any(r -> occursin(r, s), names)
    [_row_matches_any(row, cols, criterion) for row in eachrow(df_work)]
end
