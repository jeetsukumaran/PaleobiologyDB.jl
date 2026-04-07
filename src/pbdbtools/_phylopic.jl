
# ---------------------------------------------------------------------------
# PhyloPic integration
#
# Maps PBDB taxon names to PhyloPic silhouette image metadata via the
# Paleobiology Database resolution pathway:
#
#   1. pbdb_taxon(name=X)                         → orig_no
#   2. pbdb_taxa(id="txn:N", rel="all_parents")   → lineage orig_nos
#   3. PhyloPic /resolve/paleobiodb.org/txn       → node UUID
#   4. PhyloPic /nodes/<uuid>?embed_primaryImage  → image metadata
#
# Public API:
#   pbdb_phylopic(taxon_name, fieldname_prefix)       → NamedTuple
#   pbdb_phylopic(df, taxon_field, fieldname_prefix)  → DataFrame (phylopic cols only)
#   pbdb_augment_phylopic(df, taxon_field, prefix)    → DataFrame (original + phylopic cols)
#
# Column names are formed by prepending `fieldname_prefix` to each base name.
# Default prefix is "phylopic_", giving columns like :phylopic_uuid, :phylopic_thumbnail.
# Use a custom prefix to associate images at different taxonomic levels:
#
#   genus_pics = pbdb_phylopic(df, :genus,         "genus_phylopic_")
#   sp_pics    = pbdb_phylopic(df, :accepted_name, "sp_phylopic_")
#   enriched   = hcat(df, genus_pics, sp_pics)
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

"""
Base URL for the PhyloPic API.
"""
const PHYLOPIC_BASE_URL = "https://api.phylopic.org"

"""
Base column keys for PhyloPic results (without any prefix).

The `fieldname_prefix` argument to `pbdb_phylopic` is prepended to each of these
symbols to form the actual column names. With the default prefix `"phylopic_"`,
the columns become `:phylopic_pbdb_taxon_id`, `:phylopic_uuid`, etc.
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

# Current PhyloPic build number, cached in memory with a TTL.
# Re-fetched if missing or older than _PHYLOPIC_BUILD_TTL seconds.
const _PHYLOPIC_BUILD      = Ref{Union{Nothing, Int}}(nothing)
const _PHYLOPIC_BUILD_TIME = Ref{Float64}(0.0)
const _PHYLOPIC_BUILD_TTL  = 3600.0  # 1 hour

# ---------------------------------------------------------------------------
# Internal: HTTP helper
# ---------------------------------------------------------------------------

function _phylopic_get(
    url::AbstractString;
    retries::Int = 3,
    readtimeout::Integer = 30,
)::HTTP.Response
    last_err = nothing
    for attempt in 1:retries
        try
            return HTTP.get(url; readtimeout = Int(readtimeout))
        catch err
            last_err = err
            # Don't retry client errors
            if err isa HTTP.Exceptions.StatusError && err.status in (400, 404, 410)
                rethrow(err)
            end
            attempt == retries && rethrow(err)
            sleep(0.5 * attempt)
        end
    end
    throw(last_err)
end

# ---------------------------------------------------------------------------
# Internal: Build number cache
# ---------------------------------------------------------------------------

function _ensure_phylopic_build(; force::Bool = false)::Int
    expired = (time() - _PHYLOPIC_BUILD_TIME[]) > _PHYLOPIC_BUILD_TTL
    if isnothing(_PHYLOPIC_BUILD[]) || expired || force
        resp = _phylopic_get(PHYLOPIC_BASE_URL)
        obj  = JSON3.read(resp.body)
        _PHYLOPIC_BUILD[]      = Int(obj.build)
        _PHYLOPIC_BUILD_TIME[] = time()
    end
    _PHYLOPIC_BUILD[]
end

# ---------------------------------------------------------------------------
# Internal: Null record sentinel
# ---------------------------------------------------------------------------

function _phylopic_null_record()::NamedTuple
    NamedTuple{Tuple(_PHYLOPIC_BASE_COLUMNS)}(
        ntuple(_ -> missing, length(_PHYLOPIC_BASE_COLUMNS))
    )
end

# ---------------------------------------------------------------------------
# Internal: PBDB taxon lookup helpers
# ---------------------------------------------------------------------------

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

function _pbdb_lineage_nos(orig_no::Int)::Vector{Int}
    try
        df = pbdb_taxa(; id = "txn:$orig_no", rel = "all_parents")
        isempty(df) && return [orig_no]
        # Filter to rows that have a valid orig_no
        ids = Int[]
        for row in eachrow(df)
            v = row.orig_no
            !ismissing(v) && push!(ids, Int(v))
        end
        # PBDB returns root → direct-parent order.
        # PhyloPic wants: query-taxon first, then direct-parent → root.
        # So: prepend taxon's own ID, then reverse the parent list.
        return vcat([orig_no], reverse(ids))
    catch
        return [orig_no]
    end
end

# ---------------------------------------------------------------------------
# Internal: PhyloPic API helpers
# ---------------------------------------------------------------------------

function _phylopic_resolve_node(build::Int, lineage_nos::Vector{Int})::Union{String, Nothing}
    isempty(lineage_nos) && return nothing
    ids_str = join(string.(lineage_nos), ",")
    url = "$PHYLOPIC_BASE_URL/resolve/paleobiodb.org/txn?build=$build&objectIDs=$ids_str"
    try
        resp = _phylopic_get(url)
        obj  = JSON3.read(resp.body)
        # Extract UUID from the node link href (last path segment)
        hasproperty(obj, :_links)       || return nothing
        hasproperty(obj._links, :node)  || return nothing
        href = string(obj._links.node.href)
        return last(split(href, '/'))
    catch err
        err isa HTTP.Exceptions.StatusError && err.status == 404 && return nothing
        return nothing
    end
end

function _phylopic_fetch_node_with_image(node_uuid::AbstractString, build::Int)
    url = "$PHYLOPIC_BASE_URL/nodes/$node_uuid?build=$build&embed_primaryImage=true"
    try
        resp = _phylopic_get(url)
        return JSON3.read(resp.body)
    catch
        return nothing
    end
end

# Parse "WxH" size string → width integer (returns 0 on failure)
function _parse_img_width(sizes_str)::Int
    try
        return parse(Int, split(string(sizes_str), "x")[1])
    catch
        return 0
    end
end

# Select href from the largest file in a thumbnailFiles / rasterFiles array
function _largest_file_href(files_arr)::Union{String, Missing}
    isempty(files_arr) && return missing
    best = argmax(f -> _parse_img_width(get(f, :sizes, "0x0")), files_arr)
    href = get(best, :href, missing)
    ismissing(href) ? missing : string(href)
end

# Derive a human-readable CC license identifier from a license URL.
# e.g. "https://creativecommons.org/licenses/by/4.0/" → "CC BY 4.0"
function _cc_license_label(license_url::AbstractString)::String
    m = match(r"creativecommons\.org/licenses/([^/]+)/([^/]+)", license_url)
    if !isnothing(m)
        parts = uppercase(replace(m.captures[1], "-" => " "))
        ver   = m.captures[2]
        return "CC $parts $ver"
    end
    m2 = match(r"creativecommons\.org/publicdomain/([^/]+)/([^/]+)", license_url)
    if !isnothing(m2)
        return "CC0 $(m2.captures[2])"
    end
    return license_url
end

function _phylopic_extract_record(
    node_obj,
    pbdb_id::Union{Int, Missing},
    lineage_str::Union{String, Missing},
)::NamedTuple
    node_uuid    = missing
    matched_name = missing
    img_uuid     = missing
    thumbnail    = missing
    vector_url   = missing
    raster_url   = missing
    source_file  = missing
    og_image     = missing
    license_url  = missing
    license      = missing
    contributor  = missing
    attribution  = missing

    try
        node_uuid    = string(node_obj.uuid)
        matched_name = string(node_obj._links.self.title)
    catch; end

    # Drill into the embedded primary image
    img = nothing
    try
        img = node_obj._embedded.primaryImage
    catch; end

    if !isnothing(img)
        try; img_uuid = string(img.uuid); catch; end

        img_links = nothing
        try; img_links = img._links; catch; end

        if !isnothing(img_links)
            try
                thumbnail = _largest_file_href(img_links.thumbnailFiles)
            catch; end

            try
                vector_url = string(img_links.vectorFile.href)
            catch; end

            try
                raster_url = _largest_file_href(img_links.rasterFiles)
            catch; end

            try
                source_file = string(img_links.sourceFile.href)
            catch; end

            # Special key with non-identifier characters — must use bracket notation
            try
                og_image = string(img_links["http://ogp.me/ns#image"].href)
            catch; end

            try
                contributor = string(img_links.contributor.href)
            catch; end
        end

        try
            lu = string(img.license)
            license_url = lu
            license     = _cc_license_label(lu)
        catch; end

        try
            attribution = string(img.attribution)
        catch; end
    end

    return (
        pbdb_taxon_id = pbdb_id,
        pbdb_lineage  = lineage_str,
        node_uuid     = node_uuid,
        matched_name  = matched_name,
        uuid          = img_uuid,
        thumbnail     = thumbnail,
        vector        = vector_url,
        raster        = raster_url,
        source_file   = source_file,
        og_image      = og_image,
        license       = license,
        license_url   = license_url,
        contributor   = contributor,
        attribution   = attribution,
    )
end

# ---------------------------------------------------------------------------
# Internal: Full pipeline for one taxon name
# ---------------------------------------------------------------------------

function _phylopic_lookup_taxon(taxon_name::AbstractString; build::Int)::NamedTuple
    try
        # Step 1: PBDB taxon ID
        orig_no = _pbdb_taxon_orig_no(taxon_name)
        if isnothing(orig_no)
            return _phylopic_null_record()
        end

        # Step 2: Lineage IDs
        lineage_nos  = _pbdb_lineage_nos(orig_no)
        lineage_str  = join(string.(lineage_nos), ",")

        # Step 3: Resolve PhyloPic node
        node_uuid = _phylopic_resolve_node(build, lineage_nos)
        if isnothing(node_uuid)
            return merge(
                _phylopic_null_record(),
                (pbdb_taxon_id = orig_no, pbdb_lineage = lineage_str),
            )
        end

        # Step 4: Fetch node with primary image embedded
        node_obj = _phylopic_fetch_node_with_image(node_uuid, build)
        if isnothing(node_obj)
            return merge(
                _phylopic_null_record(),
                (pbdb_taxon_id = orig_no, pbdb_lineage = lineage_str,
                 node_uuid = node_uuid),
            )
        end

        # Step 5: Extract all metadata fields
        return _phylopic_extract_record(node_obj, orig_no, lineage_str)

    catch err
        @warn "pbdb_phylopic: unexpected error looking up \"$taxon_name\"" exception = err
        return _phylopic_null_record()
    end
end

# ---------------------------------------------------------------------------
# Internal: Apply fieldname prefix to a NamedTuple
# ---------------------------------------------------------------------------

function _apply_fieldname_prefix(nt::NamedTuple, prefix::AbstractString)::NamedTuple
    isempty(prefix) && return nt
    new_keys = Tuple(Symbol(prefix * string(k)) for k in keys(nt))
    return NamedTuple{new_keys}(values(nt))
end

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

"""
    pbdb_phylopic(taxon_name, fieldname_prefix = "phylopic_"; kwargs...) -> NamedTuple

Look up PhyloPic silhouette image metadata for a single PBDB taxon name.

The taxon is resolved by:
1. Finding its numeric ID in the Paleobiology Database (`pbdb_taxon`).
2. Fetching its full taxonomic lineage (`pbdb_taxa` with `rel="all_parents"`).
3. Resolving the closest-matching PhyloPic node via the PBDB resolver endpoint.
4. Fetching image file links, license, and attribution for the node's primary image.

## Arguments

- `taxon_name`: A taxon name as it appears in the Paleobiology Database (e.g. `"Tyrannosaurus"`).
- `fieldname_prefix`: String prepended to every key in the returned NamedTuple.
  Default `"phylopic_"` gives keys like `:phylopic_uuid`, `:phylopic_thumbnail`.
  Use a custom prefix (e.g. `"genus_phylopic_"`) to distinguish results at different
  taxonomic levels when combining multiple lookups.

## Returns

A `NamedTuple` with the following base keys (each prefixed by `fieldname_prefix`):

| Base key         | Content                                   |
|------------------|-------------------------------------------|
| `pbdb_taxon_id`  | PBDB `orig_no` of the query taxon         |
| `pbdb_lineage`   | Comma-separated lineage `orig_no` values  |
| `node_uuid`      | Matched PhyloPic node UUID                |
| `matched_name`   | Name of the matched PhyloPic node         |
| `uuid`           | Image UUID                                |
| `thumbnail`      | URL to the largest thumbnail PNG          |
| `vector`         | URL to the vector SVG                     |
| `raster`         | URL to the largest raster PNG             |
| `source_file`    | URL to the original source file           |
| `og_image`       | URL to the OG preview image               |
| `license`        | License identifier (e.g. `"CC BY 4.0"`)  |
| `license_url`    | Full license URL                          |
| `contributor`    | Contributor resource href                 |
| `attribution`    | Attribution text                          |

If the taxon cannot be found in PBDB or PhyloPic, all fields are `missing`.

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy

# Default prefix: :phylopic_uuid, :phylopic_thumbnail, ...
rec = pbdb_phylopic("Tyrannosaurus")
rec.phylopic_thumbnail   # URL string

# Custom prefix for multi-level use
genus_rec = pbdb_phylopic("Tyrannosaurus", "genus_phylopic_")
genus_rec.genus_phylopic_uuid
```

See also [`pbdb_phylopic(df, ...)`](@ref) for the DataFrame variant and
[`pbdb_augment_phylopic`](@ref) to enrich a DataFrame in one call.
"""
function pbdb_phylopic(
    taxon_name::AbstractString,
    fieldname_prefix::AbstractString = "phylopic_";
    kwargs...,
)::NamedTuple
    build = _ensure_phylopic_build()
    _apply_fieldname_prefix(_phylopic_lookup_taxon(taxon_name; build), fieldname_prefix)
end

"""
    pbdb_phylopic(df, taxon_field = :accepted_name, fieldname_prefix = "phylopic_"; kwargs...) -> DataFrame

Return a DataFrame of PhyloPic columns for every row in `df`, aligned by row.

Each unique value in `df[!, taxon_field]` triggers exactly one set of PhyloPic API
calls; duplicate names reuse the cached result. `missing` or empty taxon values
produce rows of `missing` values.

## Arguments

- `df`: Any `AbstractDataFrame`.
- `taxon_field`: Column in `df` whose values are PBDB taxon names. Default `:accepted_name`.
- `fieldname_prefix`: Prepended to every output column name. Default `"phylopic_"`.

## Returns

A `DataFrame` with `nrow(df)` rows and one column per PhyloPic field (14 columns total).
The returned DataFrame contains **only** the PhyloPic columns — the original columns
of `df` are not included. Use [`pbdb_augment_phylopic`](@ref) or `hcat` to combine:

```julia
pics     = pbdb_phylopic(df)          # 14 phylopic cols
enriched = hcat(df, pics)             # original + phylopic

# Or multi-level:
g_pics = pbdb_phylopic(df, :genus,         "genus_phylopic_")
s_pics = pbdb_phylopic(df, :accepted_name, "sp_phylopic_")
hcat(df, g_pics, s_pics)
```

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy, DataFrames

df   = pbdb_occurrences(base_name = "Tyrannosaurus", limit = 10)
pics = pbdb_phylopic(df)
pics.phylopic_thumbnail   # vector of URL strings / missings
```

See also [`pbdb_augment_phylopic`](@ref) for the one-call enrichment convenience function.
"""
function pbdb_phylopic(
    df::AbstractDataFrame,
    taxon_field::Symbol = :accepted_name,
    fieldname_prefix::AbstractString = "phylopic_";
    kwargs...,
)::DataFrame
    hasproperty(df, taxon_field) ||
        throw(ArgumentError(
            "pbdb_phylopic: column `$taxon_field` not found in DataFrame. " *
            "Available columns: $(join(propertynames(df), ", "))"
        ))

    build = _ensure_phylopic_build()

    # Build lookup cache: one API call sequence per unique non-empty name
    unique_names = unique(skipmissing(df[!, taxon_field]))
    cache = Dict{String, NamedTuple}()
    for name in unique_names
        s = string(name)
        isempty(strip(s)) || (cache[s] = _phylopic_lookup_taxon(s; build = build))
    end

    null_rec  = _phylopic_null_record()
    col_names = [Symbol(fieldname_prefix * string(col)) for col in _PHYLOPIC_BASE_COLUMNS]

    # Build each column
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
    pbdb_augment_phylopic(df, taxon_field = :accepted_name, fieldname_prefix = "phylopic_"; kwargs...) -> DataFrame

Enrich `df` with PhyloPic image columns and return the combined result.

This is a convenience wrapper: it calls [`pbdb_phylopic(df, ...)`](@ref) and concatenates
the result with a copy of `df` using `hcat`.

## Arguments

Same as [`pbdb_phylopic(df, ...)`](@ref).

## Returns

A `DataFrame` containing all original columns of `df` followed by the 14 PhyloPic columns.

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy, DataFrames

df       = pbdb_occurrences(base_name = "Ceratopsia", limit = 20)
enriched = pbdb_augment_phylopic(df)   # all original cols + :phylopic_uuid etc.

# Custom taxon field and prefix
enriched_genus = pbdb_augment_phylopic(df, :genus, "genus_phylopic_")
```

See also [`pbdb_phylopic`](@ref).
"""
function pbdb_augment_phylopic(
    df::AbstractDataFrame,
    taxon_field::Symbol = :accepted_name,
    fieldname_prefix::AbstractString = "phylopic_";
    kwargs...,
)::DataFrame
    hcat(copy(df), pbdb_phylopic(df, taxon_field, fieldname_prefix; kwargs...))
end
