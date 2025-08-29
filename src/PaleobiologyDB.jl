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
    :tsv => '\t',
    :txt => ',', # PBDB's .txt is comma-separated
)

pbdb_version() = _PBDB_VERSION

# Normalize a value for URL query
_joinvals(v) = v isa AbstractVector ? join(string.(v), ",") : v isa Bool ? (v ? "true" : "false") : string(v)

# Build full URL
function _build_url(endpoint::AbstractString; base_url::AbstractString=DEFAULT_BASE_URL,
                    format::Symbol=:csv, query::Dict{String,<:Any}=Dict{String,Any}())
    suffix = get(_FORMAT_SUFFIX, format) do
        error("Unsupported format: $format")
    end

    if format in (:csv, :tsv, :txt) && !haskey(query, "vocab")
        query = copy(query)
        query["vocab"] = "pbdb"
    end

    pairs = String[]
    for (k, v) in query
        push!(pairs, string(HTTP.escapeuri(k), '=', HTTP.escapeuri(_joinvals(v))))
    end
    qs = isempty(pairs) ? "" : '?' * join(pairs, '&')

    return string(base_url, endpoint, suffix, qs)
end

# Parse PBDB JSON into DataFrame
function _json_to_df(body::Vector{UInt8})
    obj = JSON3.read(body)
    if hasproperty(obj, :error)
        error(String(obj.error))
    end
    if hasproperty(obj, :records)
        return DataFrame(obj.records)
    else
        return DataFrame([obj])
    end
end

# GET with retries
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
function _fetch_df(url::AbstractString; format::Symbol=:csv, readtimeout::Integer=60, retries::Int=3)
    if format == :json
        resp = _get(url; headers=Dict("Accept" => "application/json"), readtimeout=readtimeout, retries=retries)
        return _json_to_df(resp.body)
    elseif format in keys(_TEXT_DELIM)
        resp = _get(url; headers=Dict("Accept" => "text/plain, text/csv"), readtimeout=readtimeout, retries=retries)
        io = IOBuffer(resp.body)
        return DataFrame(CSV.File(io; normalizenames=true, ignorerepeated=true, delim=_TEXT_DELIM[format]))
    else
        error("Unsupported format: $format")
    end
end

# Public: central query function
function pbdb_query(endpoint::AbstractString;
                    format::Symbol=:csv,
                    base_url::AbstractString=DEFAULT_BASE_URL,
                    readtimeout::Integer=60,
                    retries::Int=3,
                    kwargs...)
    q = Dict{String,Any}()
    for (k,v) in pairs(kwargs)
        q[string(k)] = v
    end
    url = _build_url(endpoint; base_url=base_url, format=format, query=q)
    return _fetch_df(url; format=format, readtimeout=readtimeout, retries=retries)
end

# --- Wrappers ---------------------------------------------------------------

pbdb_occurrence(id::Union{Integer,AbstractString}; kwargs...) =
    pbdb_query("occs/single"; id=id, kwargs...)

pbdb_occurrences(; kwargs...) = pbdb_query("occs/list"; kwargs...)
pbdb_ref_occurrences(; kwargs...) = pbdb_query("occs/refs"; kwargs...)

pbdb_collection(id::Union{Integer,AbstractString}; kwargs...) =
    pbdb_query("colls/single"; id=id, kwargs...)

pbdb_collections(; kwargs...) = pbdb_query("colls/list"; kwargs...)
pbdb_collections_geo(level::Union{Integer,AbstractString}; kwargs...) =
    pbdb_query("colls/summary"; level=level, kwargs...)

pbdb_taxon(; kwargs...) = pbdb_query("taxa/single"; kwargs...)
pbdb_taxa(; kwargs...) = pbdb_query("taxa/list"; kwargs...)
pbdb_taxa_auto(; kwargs...) = pbdb_query("taxa/auto"; format=:json, kwargs...)

pbdb_interval(; kwargs...) = pbdb_query("intervals/single"; kwargs...)
pbdb_intervals(; kwargs...) = pbdb_query("intervals/list"; kwargs...)
pbdb_scale(id::Union{Integer,AbstractString}; kwargs...) =
    pbdb_query("scales/single"; id=id, kwargs...)
pbdb_scales(; kwargs...) = pbdb_query("scales/list"; kwargs...)

pbdb_strata(; kwargs...) = pbdb_query("strata/list"; kwargs...)
pbdb_strata_auto(; kwargs...) = pbdb_query("strata/auto"; format=:json, kwargs...)

pbdb_reference(id::Union{Integer,AbstractString}; kwargs...) =
    pbdb_query("refs/single"; id=id, kwargs...)
pbdb_references(; kwargs...) = pbdb_query("refs/list"; kwargs...)
pbdb_ref_collections(; kwargs...) = pbdb_query("colls/refs"; kwargs...)
pbdb_ref_taxa(; kwargs...) = pbdb_query("taxa/refs"; kwargs...)

pbdb_specimen(id::Union{Integer,AbstractString}; kwargs...) =
    pbdb_query("specs/single"; id=id, kwargs...)
pbdb_specimens(; kwargs...) = pbdb_query("specs/list"; kwargs...)
pbdb_ref_specimens(; kwargs...) = pbdb_query("specs/refs"; kwargs...)
pbdb_measurements(; kwargs...) = pbdb_query("specs/measurements"; kwargs...)

pbdb_opinion(id::Union{Integer,AbstractString}; kwargs...) =
    pbdb_query("opinions/single"; id=id, kwargs...)
pbdb_opinions(; kwargs...) = pbdb_query("opinions/list"; kwargs...)
pbdb_opinions_taxa(; kwargs...) = pbdb_query("taxa/opinions"; kwargs...)

end # module

