# ---------------------------------------------------------------------------
# PhyloPicDB — core types and pure parsing utilities
#
# This file contains:
#   • PhyloPicNode  — immutable struct for a phylogenetic node
#   • PhyloPicImage — immutable struct for a silhouette image
#   • Pure utility functions: _cc_license_label, _parse_img_width,
#     _largest_file_href
#   • Pure JSON parsers: _parse_node_json, _parse_image_json
#   • Sentinel constructors: _null_image
#
# Nothing in this file performs I/O; all functions are pure and testable
# without network access.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

"""
    PhyloPicNode

Immutable representation of a phylogenetic node from the PhyloPic API.

Fields map to the canonical parsed form of a `/nodes/{uuid}` response.
Navigation UUIDs (`parent_node_uuid`, `primary_image_uuid`) are `nothing`
for root nodes or nodes without a primary image respectively.

See also [`PhyloPicImage`](@ref).
"""
struct PhyloPicNode
    "The universally unique identifier for this node."
    uuid::String
    "The preferred (first) name for this taxonomic unit."
    preferred_name::String
    "All names associated with this node, preferred name first."
    all_names::Vector{String}
    "PhyloPic build index at the time this record was fetched."
    build::Int
    "UUID of the immediate ancestor node, or `nothing` for the root."
    parent_node_uuid::Union{String, Nothing}
    "UUID of the designated primary image, or `nothing` if none."
    primary_image_uuid::Union{String, Nothing}
    "Href of the clade-images list endpoint."
    clade_images_href::String
    "Href of the node-images list endpoint."
    images_href::String
end

"""
    PhyloPicImage

Immutable representation of a silhouette image from the PhyloPic API.

Fields map to the canonical parsed form of an image record, whether
obtained from `/images/{uuid}` or embedded inside a node response.

File URL fields are `missing` when absent in the API response.  The
`license` field is the human-readable form (e.g. `"CC BY 4.0"`); use
`license_url` for the authoritative URI.

`node_name` holds the `preferred_name` of the [`PhyloPicNode`](@ref) at
`specific_node_uuid`.  It is `nothing` until the record is enriched by
[`with_node_names`](@ref) or by passing `add_node_name = true` to a fetch
function.

See also [`PhyloPicNode`](@ref).
"""
struct PhyloPicImage
    "The universally unique identifier for this image."
    uuid::String
    "PhyloPic build index at the time this record was fetched."
    build::Int
    "URL of the largest available thumbnail PNG, or `missing`."
    thumbnail_url::Union{String, Missing}
    "URL of the vector SVG file, or `missing`."
    vector_url::Union{String, Missing}
    "URL of the largest available raster PNG, or `missing`."
    raster_url::Union{String, Missing}
    "URL of the original source file as uploaded, or `missing`."
    source_file_url::Union{String, Missing}
    "URL of the Open Graph preview image (PNG), or `missing`."
    og_image_url::Union{String, Missing}
    "Full license URI, or `missing`."
    license_url::Union{String, Missing}
    "Human-readable license identifier (e.g. `\"CC BY 4.0\"`), or `missing`."
    license::Union{String, Missing}
    "Href of the contributor resource, or `missing`."
    contributor_href::Union{String, Missing}
    "Attribution text, or `missing`."
    attribution::Union{String, Missing}
    """
    Preferred name of the node at `specific_node_uuid`, or `nothing` when not
    yet enriched.  Populated by [`with_node_names`](@ref) or by passing
    `add_node_name = true` to a fetch function.
    """
    node_name::Union{String, Nothing}
    "UUID of the specific (most precise) taxonomic node, or `nothing`."
    specific_node_uuid::Union{String, Nothing}
    "UUID of the general (most inclusive applicable) node, or `nothing`."
    general_node_uuid::Union{String, Nothing}
end

# ---------------------------------------------------------------------------
# Utility functions (pure)
# ---------------------------------------------------------------------------

"""
    _cc_license_label(license_url) -> String

Convert a Creative Commons license URL to a human-readable short label.

# Examples

```julia
_cc_license_label("https://creativecommons.org/licenses/by/4.0/")
# → "CC BY 4.0"

_cc_license_label("https://creativecommons.org/licenses/by-nc-sa/4.0/")
# → "CC BY NC SA 4.0"

_cc_license_label("https://creativecommons.org/publicdomain/zero/1.0/")
# → "CC0 1.0"

_cc_license_label("https://example.com/other-license")
# → "https://example.com/other-license"  (unknown URL returned unchanged)
```
"""
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
    return String(license_url)
end

"""
    _parse_img_width(sizes_str) -> Int

Parse the width from a PhyloPic `sizes` string of the form `"WxH"`.
Returns `0` on any parse failure.

# Examples

```julia
_parse_img_width("256x192")  # → 256
_parse_img_width("64x64")    # → 64
_parse_img_width("bad")      # → 0
```
"""
function _parse_img_width(sizes_str)::Int
    try
        return parse(Int, split(string(sizes_str), "x")[1])
    catch
        return 0
    end
end

"""
    _largest_file_href(files_arr) -> Union{String, Missing}

Select the `href` from the file entry with the largest width in a PhyloPic
`thumbnailFiles` or `rasterFiles` array.  Returns `missing` if the array is
empty or all entries lack a parseable `sizes` field.

# Examples

```julia
# Accepts any iterable of objects with :href and :sizes fields
files = [(href="/img/128x128.png", sizes="128x128"),
         (href="/img/64x64.png",   sizes="64x64")]
_largest_file_href(files)  # → "/img/128x128.png"
```
"""
function _largest_file_href(files_arr)::Union{String, Missing}
    isempty(files_arr) && return missing
    best = argmax(f -> _parse_img_width(get(f, :sizes, "0x0")), files_arr)
    href = get(best, :href, missing)
    return ismissing(href) ? missing : string(href)
end

# ---------------------------------------------------------------------------
# JSON parsers (pure)
# ---------------------------------------------------------------------------

"""
    _parse_node_json(obj, build) -> PhyloPicNode

Parse a JSON3 node object (from the PhyloPic `/nodes/{uuid}` endpoint or an
embedded node in another response) into a [`PhyloPicNode`](@ref).

This function is pure: it only reads from `obj` and `build`, performs no I/O,
and is safe to call in tests with synthetic objects.

# Arguments

- `obj`: a JSON3 object or any `NamedTuple`-like with the fields defined by
  the PhyloPic Node schema.
- `build`: the PhyloPic build index to associate with the returned record.
"""
function _parse_node_json(obj, build::Int)::PhyloPicNode
    uuid = try string(obj.uuid) catch; "" end

    # Preferred name: first entry in names array, scientific class preferred.
    all_names = String[]
    preferred = ""
    try
        for name_tokens in obj.names
            for token in name_tokens
                if get(token, :class, "") == "scientific"
                    text = string(get(token, :text, ""))
                    isempty(text) && continue
                    push!(all_names, text)
                    isempty(preferred) && (preferred = text)
                    break
                end
            end
        end
    catch
    end
    isempty(preferred) && try
        preferred = string(obj._links.self.title)
    catch
    end

    parent_uuid = nothing
    try
        lnk = obj._links.parentNode
        if !isnothing(lnk)
            href = string(lnk.href)
            # href is of the form "/nodes/<uuid>?build=..."
            path = first(split(href, '?'))
            pu   = last(split(path, '/'))
            isempty(pu) || (parent_uuid = pu)
        end
    catch
    end

    primary_image_uuid = nothing
    try
        pi_link = obj._links.primaryImage
        if !isnothing(pi_link)
            href = string(pi_link.href)
            path = first(split(href, '?'))
            piu  = last(split(path, '/'))
            isempty(piu) || (primary_image_uuid = piu)
        end
    catch
    end

    clade_href = ""
    try clade_href = string(obj._links.cladeImages.href) catch end

    images_href = ""
    try images_href = string(obj._links.images.href) catch end

    return PhyloPicNode(
        uuid,
        preferred,
        all_names,
        build,
        parent_uuid,
        primary_image_uuid,
        clade_href,
        images_href,
    )
end

"""
    _parse_image_json(obj, build) -> PhyloPicImage

Parse a JSON3 image object (from `/images/{uuid}` or embedded in a node or
list response) into a [`PhyloPicImage`](@ref).

This function is pure: it only reads from `obj` and `build`, performs no I/O.

# Arguments

- `obj`: a JSON3 object or any struct-like with the fields defined by the
  PhyloPic Image schema.
- `build`: the PhyloPic build index to associate with the returned record.
"""
function _parse_image_json(obj, build::Int)::PhyloPicImage
    uuid = try string(obj.uuid) catch; "" end

    links = nothing
    try links = obj._links catch end

    thumbnail_url   = missing
    vector_url      = missing
    raster_url      = missing
    source_file_url = missing
    og_image_url    = missing
    license_url     = missing
    license         = missing
    contributor_href = missing
    specific_node_uuid = nothing
    general_node_uuid  = nothing

    if !isnothing(links)
        try thumbnail_url   = _largest_file_href(links.thumbnailFiles) catch end
        try vector_url      = string(links.vectorFile.href)             catch end
        try raster_url      = _largest_file_href(links.rasterFiles)    catch end
        try source_file_url = string(links.sourceFile.href)            catch end
        try og_image_url    = string(links["http://ogp.me/ns#image"].href) catch end
        try contributor_href = string(links.contributor.href)           catch end
        try
            lu          = string(links.license.href)
            license_url = lu
            license     = _cc_license_label(lu)
        catch end
        try
            sn = links.specificNode
            if !isnothing(sn)
                href = string(sn.href)
                path = first(split(href, '?'))
                uuid_part = last(split(path, '/'))
                isempty(uuid_part) || (specific_node_uuid = uuid_part)
            end
        catch end
        try
            gn = links.generalNode
            if !isnothing(gn)
                href = string(gn.href)
                path = first(split(href, '?'))
                uuid_part = last(split(path, '/'))
                isempty(uuid_part) || (general_node_uuid = uuid_part)
            end
        catch end
    end

    # attribution may also be at the top level
    attribution = missing
    try attribution = string(obj.attribution) catch end

    return PhyloPicImage(
        uuid,
        build,
        thumbnail_url,
        vector_url,
        raster_url,
        source_file_url,
        og_image_url,
        license_url,
        license,
        contributor_href,
        attribution,
        nothing,            # node_name: populated later by with_node_names
        specific_node_uuid,
        general_node_uuid,
    )
end

"""
    _null_image(build) -> PhyloPicImage

Return a [`PhyloPicImage`](@ref) sentinel with all optional fields set to
`missing` or `nothing`.  Used to represent a failed or absent image lookup.

# Examples

```julia
img = _null_image(537)
ismissing(img.thumbnail_url)  # true
img.uuid                      # ""
```
"""
function _null_image(build::Int)::PhyloPicImage
    return PhyloPicImage(
        "",          # uuid
        build,
        missing,     # thumbnail_url
        missing,     # vector_url
        missing,     # raster_url
        missing,     # source_file_url
        missing,     # og_image_url
        missing,     # license_url
        missing,     # license
        missing,     # contributor_href
        missing,     # attribution
        nothing,     # node_name
        nothing,     # specific_node_uuid
        nothing,     # general_node_uuid
    )
end

# ---------------------------------------------------------------------------
# Struct copy helper (pure)
# ---------------------------------------------------------------------------

"""
    _with_node_name(img::PhyloPicImage, name::Union{String, Nothing}) -> PhyloPicImage

Return a copy of `img` with `node_name` replaced by `name`.
All other fields are preserved unchanged.

This is a pure function; it performs no I/O.

# Examples

```julia
img2 = _with_node_name(img, "Tyrannosaurus rex")
img2.node_name   # → "Tyrannosaurus rex"
img2.uuid == img.uuid   # → true
```
"""
function _with_node_name(
    img::PhyloPicImage,
    name::Union{String, Nothing},
)::PhyloPicImage
    return PhyloPicImage(
        img.uuid,
        img.build,
        img.thumbnail_url,
        img.vector_url,
        img.raster_url,
        img.source_file_url,
        img.og_image_url,
        img.license_url,
        img.license,
        img.contributor_href,
        img.attribution,
        name,
        img.specific_node_uuid,
        img.general_node_uuid,
    )
end

# ---------------------------------------------------------------------------
# Image label field constants
# ---------------------------------------------------------------------------

"""
    PHYLOPIC_IMAGE_RENDERINGS

Valid `image_rendering` symbols understood by the PhyloPicMakie and
TaxonTreeMakie visualization layers.  Each symbol selects a different URL
field from a [`PhyloPicImage`](@ref) (or the corresponding field in the
NamedTuple returned by `acquire_phylopic`).

| Symbol | `PhyloPicImage` field | `acquire_phylopic` field | Format |
|---|---|---|---|
| `:thumbnail`   | `thumbnail_url`   | `:phylopic_thumbnail`   | PNG; square thumbnail, largest available (default) |
| `:raster`      | `raster_url`      | `:phylopic_raster`      | PNG; full-resolution, largest available |
| `:og_image`    | `og_image_url`    | `:phylopic_og_image`    | PNG; Open Graph social-media preview |
| `:vector`      | `vector_url`      | `:phylopic_vector`      | SVG; auto-generated black silhouette on transparent background — requires an SVG-capable `FileIO` plugin |
| `:source_file` | `source_file_url` | `:phylopic_source_file` | SVG or raster — format matches the original upload; may require an SVG-capable `FileIO` plugin |

See also [`PhyloPicImage`](@ref).
"""
const PHYLOPIC_IMAGE_RENDERINGS = (:thumbnail, :raster, :og_image, :vector, :source_file)

"""
    PHYLOPIC_IMAGE_ALL_LABEL_FIELDS

All image label field symbols recognised by the PhyloPicMakie display layer.

Includes virtual fields computed from the call context:
- `:taxon_name` — the taxon name string supplied by the caller.
- `:index`      — the position of the image within a taxon's group.

And every labelable field of [`PhyloPicImage`](@ref):
- `:node_name`          — preferred name of the node at `specific_node_uuid`.
- `:uuid`               — image UUID.
- `:thumbnail_url`      — largest thumbnail PNG URL.
- `:vector_url`         — vector SVG URL.
- `:raster_url`         — largest raster PNG URL.
- `:source_file_url`    — original uploaded source URL.
- `:license`            — human-readable license label (e.g. `"CC BY 4.0"`).
- `:license_url`        — full license URI.
- `:attribution`        — attribution text.
- `:contributor`        — contributor href (maps to `contributor_href`).
- `:specific_node_uuid` — UUID of the most-precise taxonomic node.
- `:general_node_uuid`  — UUID of the most-inclusive applicable node.

See also [`PHYLOPIC_IMAGE_BASIC_LABEL_FIELDS`](@ref).
"""
const PHYLOPIC_IMAGE_ALL_LABEL_FIELDS = Symbol[
    :taxon_name,
    :node_name,
    :index,
    :uuid,
    :thumbnail_url,
    :vector_url,
    :raster_url,
    :source_file_url,
    :license,
    :license_url,
    :attribution,
    :contributor,
    :specific_node_uuid,
    :general_node_uuid,
]

"""
    PHYLOPIC_IMAGE_BASIC_LABEL_FIELDS

Basic image label field symbols for compact display: image index, node name
(preferred name of the specific node), and taxon name (caller-supplied string).

See also [`PHYLOPIC_IMAGE_ALL_LABEL_FIELDS`](@ref).
"""
const PHYLOPIC_IMAGE_BASIC_LABEL_FIELDS = Symbol[:index, :node_name, :taxon_name]
