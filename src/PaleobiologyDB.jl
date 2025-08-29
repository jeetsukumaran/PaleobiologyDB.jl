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

# Get a single collection (positional required id, Julia style)
coll = pbdb_collection(1003; show=["loc", "stratext"])

# Geographic clusters (positional required level)
clusters = pbdb_collections_geo(2; lngmin=0, lngmax=15, latmin=45, latmax=55)
```

# Acknowledgements
Function names mirror PBDB API endpoints; implementation is independent of the R client.
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
    :tsv => '\t',   # use escaped tab for clarity
    :txt => ',',     # PBDB's .txt is comma-separated
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

# Public: central query function ---------------------------------------------

"""
    pbdb_query(endpoint::AbstractString;
               format::Symbol=:csv,
               base_url::AbstractString=DEFAULT_BASE_URL,
               readtimeout::Integer=60,
               retries::Int=3,
               kwargs...)

Low-level function that sends a request to a PBDB endpoint and returns a `DataFrame`.

- `endpoint`: path like `"occs/list"`, `"taxa/single"`, etc.
- `format`: one of `:csv` (default), `:tsv`, `:txt`, or `:json`.
- `base_url`: override host/version if needed.
- `readtimeout`: per-request read timeout (seconds).
- `retries`: simple retry count on transport errors.
- `kwargs...`: keyword arguments turned into query parameters. Values may be
  scalars or vectors (vectors become comma-separated lists). Bools become `true`/`false`.

Notes:
- For text formats, `vocab="pbdb"` is added by default if not provided.
- JSON responses use PBDB's JSON schema and are converted from the `records` array.
"""
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

# --- Thin, idiomatic wrappers (positional required args; keywords mirror PBDB) ----

# Occurrences -----------------------------------------------------------------

"""
    pbdb_occurrence(id; kwargs...)

Get information about a single occurrence record.
"""
pbdb_occurrence(id::Union{Integer,AbstractString}; kwargs...) =
    pbdb_query("occs/single"; id=id, kwargs...)

"""
    pbdb_occurrences(; kwargs...)

Get information about fossil occurrence records.
"""
pbdb_occurrences(; kwargs...) =
    pbdb_query("occs/list"; kwargs...)

"""
    pbdb_ref_occurrences(; kwargs...)

Get references associated with fossil occurrences.
"""
pbdb_ref_occurrences(; kwargs...) =
    pbdb_query("occs/refs"; kwargs...)

# Collections -----------------------------------------------------------------

"""
    pbdb_collection(id; kwargs...)

Get information about a single collection record.
"""
pbdb_collection(id::Union{Integer,AbstractString}; kwargs...) =
    pbdb_query("colls/single"; id=id, kwargs...)

"""
    pbdb_collections(; kwargs...)

Get information about multiple collections.
"""
pbdb_collections(; kwargs...) =
    pbdb_query("colls/list"; kwargs...)

"""
    pbdb_collections_geo(level; kwargs...)

Geographic clusters (summary) of collections (requires `level`).
"""
pbdb_collections_geo(level::Union{Integer,AbstractString}; kwargs...) =
    pbdb_query("colls/summary"; level=level, kwargs...)

# Taxa ------------------------------------------------------------------------

"""
    pbdb_taxon(; kwargs...)

Get information about a single taxonomic name (by `name` or `id`).
"""
pbdb_taxon(; kwargs...) =
    pbdb_query("taxa/single"; kwargs...)

"""
    pbdb_taxa(; kwargs...)

Get information about multiple taxonomic names.
"""
pbdb_taxa(; kwargs...) =
    pbdb_query("taxa/list"; kwargs...)

"""
    pbdb_taxa_auto(; kwargs...)

Autocomplete: list of taxonomic names matching a prefix/partial name (JSON only).
"""
pbdb_taxa_auto(; kwargs...) =
    pbdb_query("taxa/auto"; format=:json, kwargs...)

# Intervals & scales ----------------------------------------------------------

"""
    pbdb_interval(; kwargs...)

Get information about a single interval (by `name` or `id`).
"""
pbdb_interval(; kwargs...) =
    pbdb_query("intervals/single"; kwargs...)

"""
    pbdb_intervals(; kwargs...)

Get information about multiple intervals.
"""
pbdb_intervals(; kwargs...) =
    pbdb_query("intervals/list"; kwargs...)

"""
    pbdb_scale(id; kwargs...)

Get information about a single time scale.
"""
pbdb_scale(id::Union{Integer,AbstractString}; kwargs...) =
    pbdb_query("scales/single"; id=id, kwargs...)

"""
    pbdb_scales(; kwargs...)

Get information about multiple time scales.
"""
pbdb_scales(; kwargs...) =
    pbdb_query("scales/list"; kwargs...)

# Strata ----------------------------------------------------------------------

"""
    pbdb_strata(; kwargs...)

Get information about geological strata.
"""
pbdb_strata(; kwargs...) =
    pbdb_query("strata/list"; kwargs...)

"""
    pbdb_strata_auto(; kwargs...)

Autocomplete: list of strata matching a prefix/partial name (JSON only).
"""
pbdb_strata_auto(; kwargs...) =
    pbdb_query("strata/auto"; format=:json, kwargs...)

# References ------------------------------------------------------------------

"""
    pbdb_reference(id; kwargs...)

Get information about a single reference.
"""
pbdb_reference(id::Union{Integer,AbstractString}; kwargs...) =
    pbdb_query("refs/single"; id=id, kwargs...)

"""
    pbdb_references(; kwargs...)

Get information about multiple references.
"""
pbdb_references(; kwargs...) =
    pbdb_query("refs/list"; kwargs...)

"""
    pbdb_ref_collections(; kwargs...)

Get references from which collection data were entered.
"""
pbdb_ref_collections(; kwargs...) =
    pbdb_query("colls/refs"; kwargs...)

"""
    pbdb_ref_taxa(; kwargs...)

Get references for taxonomic names.
"""
pbdb_ref_taxa(; kwargs...) =
    pbdb_query("taxa/refs"; kwargs...)

# Specimens & measurements -----------------------------------------------------

"""
    pbdb_specimen(id; kwargs...)

Get information about a single fossil specimen.
"""
pbdb_specimen(id::Union{Integer,AbstractString}; kwargs...) =
    pbdb_query("specs/single"; id=id, kwargs...)

"""
    pbdb_specimens(; kwargs...)

Get information about multiple fossil specimens.
"""
pbdb_specimens(; kwargs...) =
    pbdb_query("specs/list"; kwargs...)

"""
    pbdb_ref_specimens(; kwargs...)

Get references for fossil specimens.
"""
pbdb_ref_specimens(; kwargs...) =
    pbdb_query("specs/refs"; kwargs...)

"""
    pbdb_measurements(; kwargs...)

Get information about specimen measurements.
"""
pbdb_measurements(; kwargs...) =
    pbdb_query("specs/measurements"; kwargs...)

# Opinions --------------------------------------------------------------------

"""
    pbdb_opinion(id; kwargs...)

Get information about a single taxonomic opinion.
"""
pbdb_opinion(id::Union{Integer,AbstractString}; kwargs...) =
    pbdb_query("opinions/single"; id=id, kwargs...)

"""
    pbdb_opinions(; kwargs...)

Get information about multiple taxonomic opinions.
"""
pbdb_opinions(; kwargs...) =
    pbdb_query("opinions/list"; kwargs...)

"""
    pbdb_opinions_taxa(; kwargs...)

Get taxonomic opinions about taxa.
"""
pbdb_opinions_taxa(; kwargs...) =
    pbdb_query("taxa/opinions"; kwargs...)

# --- Examples (commented) ----------------------------------------------------

# using PaleobiologyDB
# df = pbdb_occurrences(base_name="Canidae", interval="Quaternary", show=["coords","classext","ident"], limit="all")
# first(df, 5)

end # module