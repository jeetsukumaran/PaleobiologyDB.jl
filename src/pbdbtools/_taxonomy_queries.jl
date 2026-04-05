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
