"""
    PaleobiologyDB

A Julia interface to the Paleobiology Database (PBDB) Web API.

This package provides functions to query the PBDB API for fossil occurrences,
taxonomic information, collections, specimens, and other paleobiological data.

# Examples

```julia
using PaleobiologyDB

# Get occurrences for Canidae
occs = pbdb_occurrences(base_name="Canidae", show=["coords", "classext"])

# Get taxonomic information
taxa = pbdb_taxa(name="Canis", vocab="pbdb")

# Get a single collection
coll = pbdb_collection(id=1003, show=["loc", "stratext"])
```

# Acknowledgements
This package API design is based on the
[paleobioDB](https://github.com/ropensci/paleobioDB)
R package.

"""

module PaleobiologyDB

"""
    pbdb_version() -> String

Return the target PBDB data service version.
"""
const _PBDB_VERSION = "data1.2"

"""
Default base URL used by the client.
"""
const DEFAULT_BASE_URL = "https://paleobiodb.org/$_PBDB_VERSION/"

using HTTP
using JSON3
using CSV
using DataFrames

export pbdb_occurrence, pbdb_occurrences, pbdb_ref_occurrences,
       pbdb_collection, pbdb_collections, pbdb_collections_geo, pbdb_ref_collections,
       pbdb_taxon, pbdb_taxa, pbdb_taxa_auto, pbdb_ref_taxa, pbdb_opinions_taxa,
       pbdb_interval, pbdb_intervals, pbdb_scale, pbdb_scales,
       pbdb_strata, pbdb_strata_auto,
       pbdb_reference, pbdb_references,
       pbdb_specimen, pbdb_specimens, pbdb_ref_specimens, pbdb_measurements,
       pbdb_opinion, pbdb_opinions

# --- Internal helpers -------------------------------------------------------

const _FORMAT_SUFFIX = Dict(
    :json => ".json",
    :csv  => ".csv",
    :tsv  => ".tsv",
    :txt  => ".txt",
)

const _TEXT_DELIM = Dict(
    :csv => ',',
    :tsv => '	',
    :txt => ',', # PBDB's .txt is comma-separated
)

pbdb_version() = _PBDB_VERSION

# Normalize a value for URL query: vectors -> comma-separated, Bool -> true/false
_joinvals(v) = v isa AbstractVector ? join(string.(v), ",") : v isa Bool ? (v ? "true" : "false") : string(v)

# Build full URL for an endpoint with query parameters and chosen format
function _build_url(endpoint::AbstractString; base_url::AbstractString=DEFAULT_BASE_URL,
                    format::Symbol=:csv, query::Dict{String,<:Any}=Dict{String,Any}())
    suffix = get(_FORMAT_SUFFIX, format) do
        error("Unsupported format: $format. Use one of $(collect(keys(_FORMAT_SUFFIX))).")
    end

    # Merge-in default vocabulary for text responses if user didn't provide one
    if format in (:csv, :tsv, :txt) && !haskey(query, "vocab")
        query = copy(query)
        query["vocab"] = "pbdb"
    end

    # Assemble query string
    pairs = String[]
    for (k, v) in query
        push!(pairs, string(HTTP.escapeuri(k), '=', HTTP.escapeuri(_joinvals(v))))
    end
    qs = isempty(pairs) ? "" : '?' * join(pairs, '&')

    return string(base_url, endpoint, suffix, qs)
end

# Parse PBDB JSON (records array) into a DataFrame
function _json_to_df(body::Vector{UInt8})
    obj = JSON3.read(body)
    if hasproperty(obj, :error)
        msg = try
            String(obj.error)
        catch
            "PBDB returned an error"
        end
        error(msg)
    end
    if hasproperty(obj, :records)
        recs = obj.records
        return DataFrame(recs)  # handles missing fields automatically
    else
        return DataFrame([obj])
    end
end

# GET with simple retries
function _get(url::AbstractString; headers=Dict{String,String}(), readtimeout::Integer=60, retries::Int=3)
    last_err = nothing
    for attempt in 1:retries
        try
            return HTTP.get(url; headers=headers, readtimeout=Int(readtimeout))
        catch err
            last_err = err
            if attempt == retries
                rethrow(err)
            else
                sleep(0.5 * attempt)
            end
        end
    end
    throw(last_err)
end

# Core request -> DataFrame
function _fetch_df(url::AbstractString; format::Symbol=:csv)
    if format == :json
        resp = _get(url; headers=Dict("Accept" => "application/json"))
        return _json_to_df(resp.body)
    elseif format in keys(_TEXT_DELIM)
        resp = _get(url; headers=Dict("Accept" => "text/plain, text/csv"))
        io = IOBuffer(resp.body)
        return DataFrame(CSV.File(io; normalizenames=true, ignorerepeated=true, delim=_TEXT_DELIM[format]))
    else
        error("Unsupported format: $format")
    end
end

# Public: central query function ---------------------------------------------

"""
    pbdb_query(endpoint::AbstractString; format::Symbol=:csv, base_url::AbstractString=DEFAULT_BASE_URL, kwargs...)

Low-level function that sends a request to a PBDB endpoint and returns a `DataFrame`.

- `endpoint`: path like `"occs/list"`, `"taxa/single"`, etc.
- `format`: one of `:csv` (default), `:tsv`, `:txt`, or `:json`.
- `base_url`: override host/version if needed.
- `kwargs...`: keyword arguments turned into query parameters. Values may be
  scalars or vectors (vectors become comma-separated lists). Bools become `true`/`false`.

Notes:
- For text formats, `vocab="pbdb"` is added by default if not provided.
- JSON responses use PBDB's JSON schema and are converted from the `records` array.
"""
function pbdb_query(endpoint::AbstractString; format::Symbol=:csv, base_url::AbstractString=DEFAULT_BASE_URL, kwargs...)
    q = Dict{String,Any}()
    for (k,v) in pairs(kwargs)
        q[string(k)] = v
    end
    url = _build_url(endpoint; base_url=base_url, format=format, query=q)
    return _fetch_df(url; format=format)
end

# --- Thin, idiomatic wrappers (keywords mirror PBDB) ------------------------

# Occurrences -----------------------------------------------------------------

""" Get information about a single occurrence record. """
function pbdb_occurrence(id; kwargs...)
    return pbdb_query("occs/single"; id=id, kwargs...)
end

""" Get information about fossil occurrence records. """
function pbdb_occurrences(; kwargs...)
    return pbdb_query("occs/list"; kwargs...)
end

""" Get references associated with fossil occurrences. """
function pbdb_ref_occurrences(; kwargs...)
    return pbdb_query("occs/refs"; kwargs...)
end

# Collections -----------------------------------------------------------------

""" Get information about a single collection record. """
function pbdb_collection(id; kwargs...)
    return pbdb_query("colls/single"; id=id, kwargs...)
end

""" Get information about multiple collections. """
function pbdb_collections(; kwargs...)
    return pbdb_query("colls/list"; kwargs...)
end

""" Geographic clusters (summary) of collections. `level` is required. """
function pbdb_collections_geo(level; kwargs...)
    isnothing(level) && error("Parameter `level` is required (see PBDB config clusters)")
    return pbdb_query("colls/summary"; level=level, kwargs...)
end

# Taxa ------------------------------------------------------------------------

""" Get information about a single taxonomic name (by `name` or `id`). """
function pbdb_taxon(; kwargs...)
    return pbdb_query("taxa/single"; kwargs...)
end

""" Get information about multiple taxonomic names. """
function pbdb_taxa(; kwargs...)
    return pbdb_query("taxa/list"; kwargs...)
end

""" Autocomplete: list of taxonomic names matching a prefix/partial name. """
function pbdb_taxa_auto(; kwargs...)
    return pbdb_query("taxa/auto"; kwargs...)
end

# Intervals & scales ----------------------------------------------------------

""" Get information about a single interval (by `name` or `id`). """
function pbdb_interval(; kwargs...)
    return pbdb_query("intervals/single"; kwargs...)
end

""" Get information about multiple intervals. """
function pbdb_intervals(; kwargs...)
    return pbdb_query("intervals/list"; kwargs...)
end

""" Get information about a single time scale. """
function pbdb_scale(id; kwargs...)
    return pbdb_query("scales/single"; id=id, kwargs...)
end

""" Get information about multiple time scales. """
function pbdb_scales(; kwargs...)
    return pbdb_query("scales/list"; kwargs...)
end

# Strata ----------------------------------------------------------------------

""" Get information about geological strata. """
function pbdb_strata(; kwargs...)
    return pbdb_query("strata/list"; kwargs...)
end

""" Autocomplete: list of strata matching a prefix/partial name. """
function pbdb_strata_auto(; kwargs...)
    return pbdb_query("strata/auto"; kwargs...)
end

# References ------------------------------------------------------------------

""" Get information about a single reference. """
function pbdb_reference(id; kwargs...)
    return pbdb_query("refs/single"; id=id, kwargs...)
end

""" Get information about multiple references. """
function pbdb_references(; kwargs...)
    return pbdb_query("refs/list"; kwargs...)
end

""" Get references from which collection data were entered. """
function pbdb_ref_collections(; kwargs...)
    return pbdb_query("colls/refs"; kwargs...)
end

""" Get references for taxonomic names. """
function pbdb_ref_taxa(; kwargs...)
    return pbdb_query("taxa/refs"; kwargs...)
end

# Specimens & measurements -----------------------------------------------------

""" Get information about a single fossil specimen. """
function pbdb_specimen(id; kwargs...)
    return pbdb_query("specs/single"; id=id, kwargs...)
end

""" Get information about multiple fossil specimens. """
function pbdb_specimens(; kwargs...)
    return pbdb_query("specs/list"; kwargs...)
end

""" Get references for fossil specimens. """
function pbdb_ref_specimens(; kwargs...)
    return pbdb_query("specs/refs"; kwargs...)
end

""" Get information about specimen measurements. """
function pbdb_measurements(; kwargs...)
    return pbdb_query("specs/measurements"; kwargs...)
end

# Opinions --------------------------------------------------------------------

""" Get information about a single taxonomic opinion. """
function pbdb_opinion(id; kwargs...)
    return pbdb_query("opinions/single"; id=id, kwargs...)
end

""" Get information about multiple taxonomic opinions. """
function pbdb_opinions(; kwargs...)
    return pbdb_query("opinions/list"; kwargs...)
end

""" Get taxonomic opinions about taxa. """
function pbdb_opinions_taxa(; kwargs...)
    return pbdb_query("taxa/opinions"; kwargs...)
end

# --- Examples (commented) ----------------------------------------------------

# using .PaleobiologyDB
# df = pbdb_occurrences(base_name="Canidae", interval="Quaternary", show=["coords","classext","ident"], limit="all")
# first(df, 5)

end # module
