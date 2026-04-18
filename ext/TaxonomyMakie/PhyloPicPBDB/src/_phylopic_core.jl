# ---------------------------------------------------------------------------
# PhyloPicPBDB — PBDB-PhyloPic data bridge (no Makie dependency)
#
# Maps PBDB taxon names to PhyloPic silhouette images via a two-stage pipeline:
#
#   Stage 1 — PBDB resolution (this file, cached):
#     pbdb_taxon(name=X)                          → orig_no
#     pbdb_taxa(id="txn:N", rel="all_parents")    → lineage_nos
#     PhyloPicDB.resolve_pbdb_node(lineage_nos)   → node UUID
#     PhyloPicDB.fetch_node(uuid)                 → PhyloPicNode
#
#   Stage 2 — image retrieval (PhyloPicDB, with its own caching):
#     PhyloPicDB.primary_image / clade_images / select_image
#
# Public API:
#   phylopic_node(taxon_name; build)                                → Union{PhyloPicNode, Nothing}
#   phylopic_images(taxon_name; build, filter, max_pages)           → Vector{PhyloPicImage}
#   acquire_phylopic(taxon_name, prefix; image_selector)            → NamedTuple
#   acquire_phylopic(df, taxon_field, prefix; image_selector)       → DataFrame
#   augment_phylopic(df, taxon_field, prefix)                       → DataFrame
#   phylopic_images_dataframe(taxon_name, prefix; filter, max_pages)     → DataFrame
# ---------------------------------------------------------------------------

# pbdb_taxon and pbdb_taxa are defined in the parent Taxonomy module and
# imported into this module via the module-level `import ..pbdb_taxon` in
# the enclosing taxonomy.jl.  Access them here via the module parent chain.
import ..pbdb_taxon
import ..pbdb_taxa

export acquire_phylopic, augment_phylopic, phylopic_images_dataframe
export phylopic_node, phylopic_images

# ---------------------------------------------------------------------------
# Column layouts
# ---------------------------------------------------------------------------

"""
Base column keys for `acquire_phylopic` results (without any prefix).

With the default prefix `"phylopic_"` these become `:phylopic_pbdb_taxon_id`,
`:phylopic_uuid`, `:phylopic_thumbnail`, etc.
"""
const _PHYLOPIC_BASE_COLUMNS = [
    :pbdb_taxon_id,
    :pbdb_lineage,
    :node_uuid,
    :matched_name,
    :uuid,
    :thumbnail,
    :vector,
    :raster,
    :source_file,
    :og_image,
    :license,
    :license_url,
    :contributor,
    :attribution,
]

"""
Base column keys for `phylopic_images_dataframe` results (without any prefix).

Each row represents one image, not one taxon.
"""
const _PHYLOPIC_IMAGE_LIST_COLUMNS = [
    :query_taxon_name,
    :query_node_uuid,
    :uuid,
    :thumbnail,
    :vector,
    :raster,
    :source_file,
    :og_image,
    :license,
    :license_url,
    :contributor,
    :attribution,
]

# ---------------------------------------------------------------------------
# PBDB helpers
# ---------------------------------------------------------------------------

"""
    _pbdb_taxon_orig_no(taxon_name) -> Union{Int, Nothing}

Look up the PBDB `orig_no` for `taxon_name`.  Returns `nothing` on any failure.
"""
function _pbdb_taxon_orig_no(taxon_name::AbstractString)::Union{Int, Nothing}
    try
        df = pbdb_taxon(; name = taxon_name)
        isempty(df) && return nothing
        v = first(df).orig_no
        ismissing(v) && return nothing
        return Int(v)
    catch
        return nothing
    end
end

"""
    _pbdb_lineage_nos(orig_no) -> Vector{Int}

Return the PBDB lineage ID list for `orig_no`, ordered as PhyloPic expects:
the query taxon first, then its parents from direct parent to root.
Falls back to `[orig_no]` on any error.
"""
function _pbdb_lineage_nos(orig_no::Int)::Vector{Int}
    try
        df = pbdb_taxa(; id = "txn:$orig_no", rel = "all_parents")
        isempty(df) && return [orig_no]
        ids = Int[]
        for row in eachrow(df)
            v = row.orig_no
            !ismissing(v) && push!(ids, Int(v))
        end
        # PBDB returns root → direct-parent order; prepend query taxon and reverse.
        return vcat([orig_no], reverse(ids))
    catch
        return [orig_no]
    end
end

# ---------------------------------------------------------------------------
# Resolution layer (Stage 1 of the pipeline)
# ---------------------------------------------------------------------------

# Resolve a PBDB taxon name to (pbdb_id, lineage_str, PhyloPicNode).
# Cached per (taxon_name, build) so that separate image-selection calls for
# the same taxon reuse the PBDB and PhyloPic node lookups.
function _resolve_pbdb_to_node(
        taxon_name::AbstractString,
        build::Int,
    )::Tuple{Union{Int, Nothing}, Union{String, Missing}, Union{PhyloPicDB.PhyloPicNode, Nothing}}
    return autocache(
        () -> begin
            orig_no = _pbdb_taxon_orig_no(taxon_name)
            isnothing(orig_no) && return (nothing, missing, nothing)
            lineage_nos = _pbdb_lineage_nos(orig_no)
            lineage_str = join(string.(lineage_nos), ",")
            node_uuid = PhyloPicDB.resolve_pbdb_node(lineage_nos; build = build)
            isnothing(node_uuid) && return (orig_no, lineage_str, nothing)
            node = PhyloPicDB.fetch_node(node_uuid; build = build)
            return (orig_no, lineage_str, node)
        end,
        _resolve_pbdb_to_node,
        "phylopic/pbdb_to_node",
        (; taxon_name = taxon_name, build = build),
    )
end

"""
    phylopic_node(taxon_name; build = nothing) -> Union{PhyloPicNode, Nothing}

Resolve a PBDB taxon name to its matching PhyloPic phylogenetic node.

This is the first stage of the two-stage pipeline for acquiring silhouette
images: resolve the node here, then retrieve images via `PhyloPicDB` functions.

# Arguments

- `taxon_name`: A taxon name as it appears in the Paleobiology Database.
- `build`: PhyloPic build index.  `nothing` (default) fetches the current build.

# Returns

A `PhyloPicDB.PhyloPicNode`, or `nothing` if the taxon cannot be found
in PBDB or PhyloPic.  The result is cached per `(taxon_name, build)`.

# Examples

```julia
node = phylopic_node("Tyrannosaurus")
isnothing(node) || println(node.preferred_name)

# Two-stage pipeline — resolve once, then choose images:
node = phylopic_node("Carnivora")
imgs = PhyloPicDB.clade_images(node.uuid; max_pages = 2)
```

See also [`phylopic_images`](@ref), [`acquire_phylopic`](@ref).
"""
function phylopic_node(
        taxon_name::AbstractString;
        build::Union{Int, Nothing} = nothing,
    )::Union{PhyloPicDB.PhyloPicNode, Nothing}
    b = PhyloPicDB.ensure_build(build)
    _, _, node = _resolve_pbdb_to_node(taxon_name, b)
    return node
end

"""
    phylopic_images(taxon_name; build = nothing, filter = :clade, max_pages = nothing)
        -> Vector{PhyloPicDB.PhyloPicImage}

Return all PhyloPic images for a PBDB taxon as a typed vector.

Typed companion to [`phylopic_images_dataframe`](@ref): returns the same images as a
`Vector{PhyloPicDB.PhyloPicImage}` rather than a `DataFrame`, making it easy to
pass the result directly to `PhyloPicDB.select_image`.

# Arguments

- `taxon_name`: A taxon name as it appears in the Paleobiology Database.
- `build`: PhyloPic build index.  `nothing` fetches the current build.
- `filter`: `:clade` (default) returns images for the node and all descendants;
  `:node` restricts to images tagged directly to the resolved node.
- `max_pages`: Maximum pages to fetch.  `nothing` fetches all pages.

# Returns

A `Vector{PhyloPicDB.PhyloPicImage}`.  Empty if the taxon cannot be resolved or
has no images.

# Examples

```julia
imgs = phylopic_images("Carnivora"; max_pages = 2)
chosen = PhyloPicDB.select_image(imgs, 3)
```

See also [`phylopic_images_dataframe`](@ref), [`phylopic_node`](@ref).
"""
function phylopic_images(
        taxon_name::AbstractString;
        build::Union{Int, Nothing} = nothing,
        filter::Symbol = :clade,
        max_pages::Union{Int, Nothing} = nothing,
    )::Vector{PhyloPicDB.PhyloPicImage}
    b = PhyloPicDB.ensure_build(build)
    node = phylopic_node(taxon_name; build = b)
    isnothing(node) && return PhyloPicDB.PhyloPicImage[]
    return PhyloPicDB.fetch_images(node.uuid; build = b, filter = filter, max_pages = max_pages)
end

# ---------------------------------------------------------------------------
# Record builders (pure, no I/O)
# ---------------------------------------------------------------------------

function _phylopic_null_record()::NamedTuple
    return NamedTuple{Tuple(_PHYLOPIC_BASE_COLUMNS)}(
        ntuple(_ -> missing, length(_PHYLOPIC_BASE_COLUMNS)),
    )
end

# Convert a (PhyloPicImage or nothing, PhyloPicNode or nothing, PBDB metadata)
# to the 14-column NamedTuple expected by acquire_phylopic.
function _image_to_record(
        img::Union{PhyloPicDB.PhyloPicImage, Nothing},
        node::Union{PhyloPicDB.PhyloPicNode, Nothing},
        pbdb_id::Union{Int, Nothing},
        lineage_str::Union{String, Missing},
    )::NamedTuple
    return (
        pbdb_taxon_id = something(pbdb_id, missing),
        pbdb_lineage = lineage_str,
        node_uuid = isnothing(node) ? missing : node.uuid,
        matched_name = isnothing(node) ? missing : node.preferred_name,
        uuid = isnothing(img) ? missing : img.uuid,
        thumbnail = isnothing(img) ? missing : img.thumbnail_url,
        vector = isnothing(img) ? missing : img.vector_url,
        raster = isnothing(img) ? missing : img.raster_url,
        source_file = isnothing(img) ? missing : img.source_file_url,
        og_image = isnothing(img) ? missing : img.og_image_url,
        license = isnothing(img) ? missing : img.license,
        license_url = isnothing(img) ? missing : img.license_url,
        contributor = isnothing(img) ? missing : img.contributor_href,
        attribution = isnothing(img) ? missing : img.attribution,
    )
end

# Convert a PhyloPicImage to the 12-column NamedTuple used by phylopic_images_dataframe.
function _image_list_row(
        img::PhyloPicDB.PhyloPicImage,
        query_taxon_name::AbstractString,
        query_node_uuid::AbstractString,
    )::NamedTuple
    return (
        query_taxon_name = query_taxon_name,
        query_node_uuid = query_node_uuid,
        uuid = img.uuid,
        thumbnail = img.thumbnail_url,
        vector = img.vector_url,
        raster = img.raster_url,
        source_file = img.source_file_url,
        og_image = img.og_image_url,
        license = img.license,
        license_url = img.license_url,
        contributor = img.contributor_href,
        attribution = img.attribution,
    )
end

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

function _apply_fieldname_prefix(nt::NamedTuple, prefix::AbstractString)::NamedTuple
    isempty(prefix) && return nt
    new_keys = Tuple(Symbol(prefix * string(k)) for k in keys(nt))
    return NamedTuple{new_keys}(values(nt))
end

function _make_empty_phylopic_df(col_names::Vector{Symbol})::DataFrame
    return DataFrame(col_names .=> [Vector{Any}() for _ in col_names])
end

# ---------------------------------------------------------------------------
# Image retrieval with selector dispatch
# ---------------------------------------------------------------------------

# Return an image for `node` according to `image_selector`.
# :primary uses batch_primary_images (one round-trip, autocached).
# Any other selector fetches clade images then dispatches to select_image.
function _get_image_for_node(
        node::PhyloPicDB.PhyloPicNode,
        build::Int,
        image_selector,
    )::Union{PhyloPicDB.PhyloPicImage, Nothing}
    if image_selector === :primary
        result = PhyloPicDB.batch_primary_images([node.uuid]; build = build)
        return get(result, node.uuid, nothing)
    else
        imgs = PhyloPicDB.clade_images(node.uuid; build = build)
        return PhyloPicDB.select_image(imgs, image_selector)
    end
end

# Full pipeline for one taxon name: PBDB → node → image → NamedTuple.
function _phylopic_lookup_taxon(
        taxon_name::AbstractString,
        build::Int,
        image_selector,
    )::NamedTuple
    pbdb_id, lineage_str, node = _resolve_pbdb_to_node(taxon_name, build)
    img = isnothing(node) ? nothing : _get_image_for_node(node, build, image_selector)
    return _image_to_record(img, node, pbdb_id, lineage_str)
end

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

"""
    acquire_phylopic(taxon_name, fieldname_prefix = "phylopic_"; image_selector = :primary) -> NamedTuple

Look up PhyloPic silhouette image metadata for a single PBDB taxon name.

## Arguments

- `taxon_name`: A taxon name as it appears in the Paleobiology Database.
- `fieldname_prefix`: String prepended to every key in the returned NamedTuple.
  Default `"phylopic_"`.  Use a custom prefix (e.g. `"genus_phylopic_"`) when
  combining lookups at different taxonomic levels.
- `image_selector`: Controls which image is selected for the resolved node:
  - `:primary` (default) — the node's designated primary image; one round-trip.
  - `Int n` — the *n*-th image in the clade-ordered list.  Out-of-bounds returns
    all-`missing` fields (no fallback to primary).
  - Callable `f` — called with `Vector{PhyloPicImage}` and must return a
    `PhyloPicImage` or `nothing`.

## Returns

A `NamedTuple` with 14 base keys (each prefixed by `fieldname_prefix`):

| Base key         | Content                                   |
|------------------|-------------------------------------------|
| `pbdb_taxon_id`  | PBDB `orig_no` of the query taxon         |
| `pbdb_lineage`   | Comma-separated lineage `orig_no` values  |
| `node_uuid`      | Matched PhyloPic node UUID                |
| `matched_name`   | Name of the matched PhyloPic node         |
| `uuid`           | Image UUID                                |
| `thumbnail`      | URL of the largest thumbnail PNG          |
| `vector`         | URL of the vector SVG                     |
| `raster`         | URL of the largest raster PNG             |
| `source_file`    | URL of the original source file           |
| `og_image`       | URL of the OG preview image               |
| `license`        | License identifier (e.g. `"CC BY 4.0"`)  |
| `license_url`    | Full license URL                          |
| `contributor`    | Contributor resource href                 |
| `attribution`    | Attribution text                          |

All fields are `missing` when the taxon cannot be found.

## Examples

```julia
rec = acquire_phylopic("Tyrannosaurus")
rec.phylopic_thumbnail

# Second clade image, or all-missing if fewer than 2:
rec2 = acquire_phylopic("Tyrannosaurus"; image_selector = 2)

# Custom prefix:
genus_rec = acquire_phylopic("Tyrannosaurus", "genus_phylopic_")
genus_rec.genus_phylopic_uuid
```

See also [`acquire_phylopic`](@ref) (DataFrame variant), [`augment_phylopic`](@ref).
"""
function acquire_phylopic(
        taxon_name::AbstractString,
        fieldname_prefix::AbstractString = "phylopic_";
        image_selector = :primary,
        kwargs...,
    )::NamedTuple
    build = PhyloPicDB.ensure_build(nothing)
    rec = _phylopic_lookup_taxon(taxon_name, build, image_selector)
    return _apply_fieldname_prefix(rec, fieldname_prefix)
end

"""
    acquire_phylopic(df, taxon_field = :accepted_name, fieldname_prefix = "phylopic_";
                     image_selector = :primary) -> DataFrame

Return a DataFrame of PhyloPic columns for every row in `df`, aligned by row.

Each unique value in `df[!, taxon_field]` triggers exactly one set of API calls;
duplicate names reuse the cached result.

## Arguments

- `df`: Any `AbstractDataFrame`.
- `taxon_field`: Column of PBDB taxon names.  Default `:accepted_name`.
- `fieldname_prefix`: Prepended to every output column name.  Default `"phylopic_"`.
- `image_selector`: As for the single-taxon variant.  Default `:primary`.

## Returns

A `DataFrame` with `nrow(df)` rows and 14 PhyloPic columns.  Use
[`augment_phylopic`](@ref) or `hcat` to combine with the original DataFrame.

## Examples

```julia
pics     = acquire_phylopic(df)
enriched = hcat(df, pics)

# Multi-level:
g_pics = acquire_phylopic(df, :genus,         "genus_phylopic_")
s_pics = acquire_phylopic(df, :accepted_name, "sp_phylopic_")
hcat(df, g_pics, s_pics)
```
"""
function acquire_phylopic(
        df::AbstractDataFrame,
        taxon_field::Symbol = :accepted_name,
        fieldname_prefix::AbstractString = "phylopic_";
        image_selector = :primary,
        kwargs...,
    )::DataFrame
    hasproperty(df, taxon_field) ||
        throw(
        ArgumentError(
            "acquire_phylopic: column `$taxon_field` not found in DataFrame. " *
                "Available columns: $(join(propertynames(df), ", "))",
        )
    )

    # Collect unique non-empty names before fetching the build number so that an
    # all-missing / all-empty input never triggers a network call.
    unique_names = String[]
    for name in unique(skipmissing(df[!, taxon_field]))
        s = string(name)
        isempty(strip(s)) || push!(unique_names, s)
    end

    cache = Dict{String, NamedTuple}()
    if !isempty(unique_names)
        build = PhyloPicDB.ensure_build(nothing)
        for name in unique_names
            cache[name] = _phylopic_lookup_taxon(name, build, image_selector)
        end
    end

    null_rec = _phylopic_null_record()
    col_names = [Symbol(fieldname_prefix * string(col)) for col in _PHYLOPIC_BASE_COLUMNS]

    n = nrow(df)
    col_vecs = Vector{Vector{Any}}(undef, length(_PHYLOPIC_BASE_COLUMNS))
    for (i, base_col) in enumerate(_PHYLOPIC_BASE_COLUMNS)
        col_vecs[i] = Vector{Any}(undef, n)
        for r in 1:n
            v = df[r, taxon_field]
            if ismissing(v) || isempty(strip(string(v)))
                col_vecs[i][r] = missing
            else
                rec = get(cache, string(v), null_rec)
                col_vecs[i][r] = rec[base_col]
            end
        end
    end

    return DataFrame(col_names .=> col_vecs)
end

"""
    augment_phylopic(df, taxon_field = :accepted_name, fieldname_prefix = "phylopic_"; kwargs...) -> DataFrame

Enrich `df` with PhyloPic image columns and return the combined DataFrame.

Thin wrapper: calls [`acquire_phylopic`](@ref) (DataFrame variant) and concatenates the
result with a copy of `df` using `hcat`.

## Examples

```julia
enriched = augment_phylopic(df)
enriched_genus = augment_phylopic(df, :genus, "genus_phylopic_")
```
"""
function augment_phylopic(
        df::AbstractDataFrame,
        taxon_field::Symbol = :accepted_name,
        fieldname_prefix::AbstractString = "phylopic_";
        kwargs...,
    )::DataFrame
    return hcat(
        copy(df),
        acquire_phylopic(df, taxon_field, fieldname_prefix; kwargs...),
    )
end

"""
    phylopic_images_dataframe(taxon_name, fieldname_prefix = "phylopic_";
                         filter = :clade, max_pages = nothing) -> DataFrame

Return a DataFrame of all PhyloPic images for a taxon, one row per image.

Unlike [`acquire_phylopic`](@ref) which returns one representative image,
this function pages through the `/images` list and collects every image whose
subject falls within the taxon's clade (or exactly that node when `filter = :node`).

## Arguments

- `taxon_name`: A taxon name as it appears in the Paleobiology Database.
- `fieldname_prefix`: Prepended to every column name.  Default `"phylopic_"`.
- `filter`: `:clade` (default) or `:node`.
- `max_pages`: Maximum pages to fetch (~30 images each).  `nothing` fetches all.

## Returns

A `DataFrame` with one row per image and 12 base columns (each prefixed).
Returns an empty DataFrame (with all columns present) when the taxon cannot
be resolved or has no images.

## Examples

```julia
imgs = phylopic_images_dataframe("Carnivora")
imgs.phylopic_thumbnail[1:5]

imgs_node = phylopic_images_dataframe("Carnivora"; filter = :node)
imgs_quick = phylopic_images_dataframe("Carnivora"; max_pages = 2)

# Custom prefix
imgs = phylopic_images_dataframe("Canis", "dog_")
imgs.dog_uuid
```

See also [`acquire_phylopic`](@ref), [`phylopic_images`](@ref).
"""
function phylopic_images_dataframe(
        taxon_name::AbstractString,
        fieldname_prefix::AbstractString = "phylopic_";
        filter::Symbol = :clade,
        max_pages::Union{Int, Nothing} = nothing,
    )::DataFrame
    filter in (:clade, :node) ||
        throw(
        ArgumentError(
            "phylopic_images_dataframe: `filter` must be :clade or :node, got :$filter",
        )
    )

    col_names = [Symbol(fieldname_prefix * string(col)) for col in _PHYLOPIC_IMAGE_LIST_COLUMNS]
    _empty() = _make_empty_phylopic_df(col_names)

    b = PhyloPicDB.ensure_build(nothing)
    node = phylopic_node(taxon_name; build = b)
    isnothing(node) && return _empty()

    imgs = PhyloPicDB.fetch_images(node.uuid; build = b, filter = filter, max_pages = max_pages)
    isempty(imgs) && return _empty()

    records = [_image_list_row(img, taxon_name, node.uuid) for img in imgs]

    col_vecs = Vector{Vector{Any}}(undef, length(_PHYLOPIC_IMAGE_LIST_COLUMNS))
    for (i, base_col) in enumerate(_PHYLOPIC_IMAGE_LIST_COLUMNS)
        col_vecs[i] = [rec[base_col] for rec in records]
    end
    return DataFrame(col_names .=> col_vecs)
end
