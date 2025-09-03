

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
	pbdb_collection, pbdb_collections, pbdb_collections_geo,
	pbdb_ref_collections, pbdb_config,
	pbdb_taxon, pbdb_taxa, pbdb_taxa_auto, pbdb_ref_taxa, pbdb_opinions_taxa,
	pbdb_interval, pbdb_intervals, pbdb_scale, pbdb_scales,
	pbdb_strata, pbdb_strata_auto,
	pbdb_reference, pbdb_references,
	pbdb_specimen, pbdb_specimens, pbdb_ref_specimens, pbdb_measurements,
	pbdb_opinion, pbdb_opinions

# --- Internal helpers -------------------------------------------------------

const _FORMAT_SUFFIX = Dict(
	:json => ".json",
	:csv => ".csv",
	:tsv => ".tsv",
	:txt => ".txt",
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
function _build_url(endpoint::AbstractString; base_url::AbstractString = DEFAULT_BASE_URL,
	format::Symbol = :csv, query::Dict{String, <:Any} = Dict{String, Any}())
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
function _get(
    url::AbstractString; headers = Dict{String, String}(),
    readtimeout::Integer = 300,
    retries::Int = 3
)
	last_err = nothing
	for attempt in 1:retries
		try
			return HTTP.get(url; headers = headers, readtimeout = Int(readtimeout))
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
function _fetch_df(url::AbstractString; format::Symbol = :csv, readtimeout::Integer = 300, retries::Int = 3)
	if format == :json
		resp = _get(url; headers = Dict("Accept" => "application/json"), readtimeout, retries)
		return _json_to_df(resp.body)
	elseif format in keys(_TEXT_DELIM)
		resp = _get(url; headers = Dict("Accept" => "text/plain, text/csv"), readtimeout, retries)
		io = IOBuffer(resp.body)
		return DataFrame(CSV.File(io; normalizenames = true, ignorerepeated = true, delim = _TEXT_DELIM[format]))
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
function pbdb_query(
    endpoint::AbstractString
    ;
    format::Symbol = :csv,
    base_url::AbstractString = DEFAULT_BASE_URL,
    readtimeout::Integer = 300,
    retries::Int = 3,
    kwargs...
)
	q = Dict{String, Any}()
	for (k, v) in pairs(kwargs)
		q[string(k)] = v
	end
	url = _build_url(endpoint; base_url = base_url, format = format, query = q)
	return _fetch_df(url; format = format, readtimeout, retries)
end

# --- Thin, idiomatic wrappers (keywords mirror PBDB) ------------------------

"""
	pbdb_occurrence(id; kwargs...)

Get information about a single fossil occurrence record from the Paleobiology Database.

# Arguments
- `id`: Identifier of the occurrence (required).
- `kwargs...`: Additional query parameters. Common options include:
  - `vocab`: `"pbdb"` to use full field names instead of compact 3-letter codes.
  - `show`: Extra information blocks to return (e.g. `"class"`, `"coords"`, `"loc"`, `"stratext"`, `"lithext"`).

# Returns
A `DataFrame` with information about the specified occurrence.

# Examples
```julia
pbdb_occurrence("occ:1001")
pbdb_occurrence("occ:1001"; vocab="pbdb", show="full")
pbdb_occurrence(1001)
pbdb_occurrence(1001; vocab="pbdb", show=["class","coords"])
```
"""
function pbdb_occurrence(id; kwargs...)
	return pbdb_query("occs/single"; id = id, kwargs...)
end

"""
	pbdb_occurrences(; kwargs...)

Get information about fossil occurrence records stored in the Paleobiology Database.

# Arguments
- `kwargs...`: Filtering and output parameters. Common options include:
  - `limit`: Maximum number of records to return (`Int` or `"all"`).
  - `taxon_name`: Return only records with the specified taxonomic name(s).
  - `base_name`: Return records for the specified name(s) and all descendant taxa.
  - `lngmin`, `lngmax`, `latmin`, `latmax`: Geographic bounding box.
  - `min_ma`, `max_ma`: Minimum and maximum age in millions of years.
  - `interval`: Named geologic interval (e.g. `"Miocene"`).
  - `cc`: Country/continent codes (ISO two-letter or three-letter).
  - `show`: Extra information blocks (`"coords"`, `"classext"`, `"ident"`, etc.). `show = "full"` for everything.
  - `extids`: Set `extids = true` to show the newer string identifiers.
  - `vocab`: Vocabulary for field names (`"pbdb"` for full names, `"com"` for short codes).

# Returns
A `DataFrame` with fossil occurrence records matching the query.

# Examples
```julia

# `taxon_name` retrieves *only* units of this rank
occs = pbdb_occurrences(
	taxon_name="Canis",
	show="full", # all columns
	limit=100,
)

# `base_name` retrieves units of this and nested rank
occs = pbdb_occurrences(
	base_name="Canis",
	show=["coords","classext"],
	limit=100,
)
```
"""
function pbdb_occurrences(; kwargs...)
	return pbdb_query("occs/list"; kwargs...)
end

"""
	pbdb_ref_occurrences(; kwargs...)

Get bibliographic references associated with fossil occurrence records.

# Arguments
- `kwargs...`: Filtering parameters. Common options include:
  - `base_name`: Restrict references to occurrences of a given taxon and descendants.
  - `ref_author`: Filter by author name.
  - `ref_pubyr`: Filter by publication year.
  - `pub_title`: Filter by publication title.

# Returns
A `DataFrame` with references linked to occurrence records.

# Examples
```julia
pbdb_ref_occurrences(base_name="Canis"; ref_pubyr=2000, vocab="pbdb")
```
"""
function pbdb_ref_occurrences(; kwargs...)
	return pbdb_query("occs/refs"; kwargs...)
end

# # Collections -----------------------------------------------------------------

"""
	pbdb_collection(id; kwargs...)

Get information about a single fossil collection record from the Paleobiology Database.

# Arguments
- `id`: Identifier of the collection (required).
- `kwargs...`: Additional query parameters. Common options include:
  - `vocab`: Set to `"pbdb"` to use full field names instead of compact 3-letter codes.
  - `show`: Extra information blocks to include (e.g. `"loc"`, `"stratext"`, `"lithext"`).
  - Geographic filters accepted by PBDB (e.g. `lngmin`, `lngmax`, `latmin`, `latmax`).

# Returns
A `DataFrame` describing the specified collection.

# Examples
```julia
pbdb_collection("col:1003")
pbdb_collection(1003)
pbdb_collection(
	"col:1003";
	vocab="pbdb",
	show=["loc","stratext"],
	extids=true
)
```
"""
function pbdb_collection(id; kwargs...)
	return pbdb_query("colls/single"; id = id, kwargs...)
end

"""
	pbdb_collections(; kwargs...)

Get information about multiple fossil collections.

# Arguments
- `kwargs...`: Filtering and output parameters. Common options include:
  - `base_name`: Restrict to collections containing occurrences of the named taxon (including descendants).
  - `interval`: Geologic time interval (e.g. `"Miocene"`).
  - `min_ma`, `max_ma`: Minimum and maximum age in millions of years.
  - `lngmin`, `lngmax`, `latmin`, `latmax`: Geographic bounding box.
  - `cc`: Country/continent codes (ISO-3166 two-letter; three-letter continent codes).
  - `show`: Extra blocks (`"ref"`, `"loc"`, `"stratext"`, `"lithext"`).
  - `limit`: Limit the number of records (`Int` or `"all"`).
  - `vocab`: Vocabulary for field names (`"pbdb"` for full names, `"com"` for compact codes).

# Returns
A `DataFrame` of collections matching the query.

# Examples
```julia
pbdb_collections(base_name="Cetacea", interval="Miocene"; show=["ref","loc","stratext"])
```
"""
function pbdb_collections(; kwargs...)
	return pbdb_query("colls/list"; kwargs...)
end

"""
	pbdb_collections_geo(level; kwargs...)

Geographic clusters (summary) of collections. `level` is required.

Use this method when you prefer a positional `level` per Julia convention.
All other parameters are passed as keywords and accept the same filters as `pbdb_collections`.

# Arguments
- `level`: Cluster level (required). See `pbdb_config(show = "clusters")` for available levels.
- `kwargs...`: Any `colls/summary` filters (e.g., `lngmin`, `lngmax`, `latmin`, `latmax`, `base_name`, `interval`, `vocab`).

# Returns
A `DataFrame` summarizing the selected collections by geographic clusters.

# Examples
```julia
pbdb_collections_geo(2; lngmin=0.0, lngmax=15.0, latmin=0.0, latmax=15.0, vocab="pbdb")
```
"""
function pbdb_collections_geo(level; kwargs...)
	isnothing(level) && error("Parameter `level` is required (see `pbdb_config(show = \"clusters\")`)")
	return pbdb_query("colls/summary"; level = level, kwargs...)
end

"""
	pbdb_collections_geo(; level, kwargs...)

Geographic clusters (summary) of collections. `level` is required.

This keyword-only form is provided for compatibility with existing code
that prefers `level` as a keyword. All other filters are identical to
`pbdb_collections_geo(level; ...)`.

# Arguments
- `level`: Cluster level (required). See `pbdb_config(show = "clusters")` for available levels.
- `kwargs...`: Any `colls/summary` filters (e.g., `lngmin`, `lngmax`, `latmin`, `latmax`, `base_name`, `interval`, `vocab`).

# Returns
A `DataFrame` summarizing the selected collections by geographic clusters.

# Examples
```julia
pbdb_collections_geo(level=2; lngmin=0.0, lngmax=15.0, latmin=0.0, latmax=15.0)
```
"""
function pbdb_collections_geo(; level, kwargs...)
	isnothing(level) && error("Parameter `level` is required (see `pbdb_config(show = \"clusters\")`)")
	return pbdb_query("colls/summary"; level = level, kwargs...)
end

# Taxa ------------------------------------------------------------------------

"""
	pbdb_taxon(; kwargs...)

Get information about a single taxonomic name (by `name` or `id`).

# Arguments
- `kwargs...`: One of the following must be provided (but not both):
  - `name`: Taxonomic name string; `%` and `_` may be used as wildcards.
  - `id`: PBDB identifier (integer or extended identifier).
  Additional options:
  - `show`: Extra blocks (e.g. `"attr"` attribution, `"app"` first/last appearance, `"size"` number of subtaxa).
  - `vocab`: Vocabulary for field names (`"pbdb"` for full names, `"com"` for compact).

# Returns
A `DataFrame` with information about the selected taxon.

# Examples
```julia
pbdb_taxon(name="Canis"; vocab="pbdb", show=["attr","app","size"])
```
"""
function pbdb_taxon(; kwargs...)
	return pbdb_query("taxa/single"; kwargs...)
end
function pbdb_taxon(id; kwargs...)
	return pbdb_taxon(; id = id, kwargs...)
end

"""
	pbdb_taxa(; kwargs...)

Get information about multiple taxonomic names.

# Arguments
- `kwargs...`: Filtering and output parameters. Common options include:
  - `name`: Name string (wildcards allowed).
  - `id`: Identifier (vector allowed).
  - `rel`: Relationship selector (e.g. `"synonyms"`, `"children"`, `"all_children"`, `"all_parents"`, `"common"`).
  - `extant`: Logical, select only extant or non-extant taxa.
  - `show`: Extra blocks (`"attr"`, `"app"`, `"size"`, `"class"`).
  - `vocab`: Vocabulary for field names.

# Returns
A `DataFrame` of taxa matching the query.

# Examples
```julia
pbdb_taxa(name="Canidae"; rel="all_parents", vocab="pbdb", show=["attr","app","size","class"])
```
"""
function pbdb_taxa(; kwargs...)
	return pbdb_query("taxa/list"; kwargs...)
end

"""
	pbdb_taxa_auto(; kwargs...)

Autocomplete: list of taxonomic names matching a prefix or partial name.

# Arguments
- `kwargs...`: Common options include:
  - `name`: A partial name or prefix (at least 3 significant characters).
  - `limit`: Maximum number of matches to return.

# Returns
A `DataFrame` of candidate taxonomic names, including rank and occurrence counts.
This endpoint returns JSON in PBDB; the wrapper converts to a `DataFrame`.

# Examples
```julia
pbdb_taxa_auto(name="Cani"; limit=10)
```
"""
function pbdb_taxa_auto(; kwargs...)
	return pbdb_query("taxa/auto"; format = :json, kwargs...)
end

# Intervals & scales ----------------------------------------------------------

"""
	pbdb_interval(; kwargs...)

Get information about a single geologic time interval, selected by `name` or `id`.

# Arguments
- `kwargs...`: One of the following must be provided (but not both):
  - `name`: Interval name (e.g. "Miocene").
  - `id`: PBDB interval identifier.
  Additional options:
  - `vocab`: Set to "pbdb" to return full field names (default for text formats).
  - `order`: Return the interval in a specific order (rarely used here; see PBDB docs).

# Returns
A `DataFrame` describing the selected interval.

# Examples
```julia
pbdb_interval(name="Miocene")
pbdb_interval(id=1; vocab="pbdb")
```
"""
function pbdb_interval(; kwargs...)
	return pbdb_query("intervals/single"; kwargs...)
end
function pbdb_interval(id; kwargs...)
	return pbdb_interval(; id = id, kwargs...)
end

"""
	pbdb_intervals(; kwargs...)

Get information about multiple geologic time intervals.

# Arguments
- `kwargs...`: Filtering and output parameters. Common options include:
  - `min_ma`: Return only intervals at least this old (Ma).
  - `max_ma`: Return only intervals at most this old (Ma).
  - `order`: Return intervals in the requested order (e.g. "age" or "name").
  - `vocab`: Field naming vocabulary ("pbdb" for full names).

# Returns
A `DataFrame` with the selected intervals.

# Examples
```julia
pbdb_intervals(min_ma=0, max_ma=5; vocab="pbdb")
```
"""
function pbdb_intervals(; kwargs...)
	return pbdb_query("intervals/list"; kwargs...)
end

"""
	pbdb_scale(id; kwargs...)

Get information about a single time scale, selected by identifier.

# Arguments
- `id`: PBDB scale identifier (required).
- `kwargs...`: Additional parameters, e.g.:
  - `vocab`: Set to "pbdb" to return full field names.

# Returns
A `DataFrame` with information about the requested time scale.

# Examples
```julia
pbdb_scale(1)
pbdb_scale(1; vocab="pbdb")
```
"""
function pbdb_scale(id; kwargs...)
	return pbdb_query("scales/single"; id = id, kwargs...)
end

"""
	pbdb_scales(; kwargs...)

Get information about multiple time scales.

# Arguments
- `kwargs...`: Optional parameters, e.g.:
  - `vocab`: Set to "pbdb" to return full field names.

# Returns
A `DataFrame` listing the requested time scales (or all, if no filter provided).

# Examples
```julia
pbdb_scales()
```
"""
function pbdb_scales(; kwargs...)
	return pbdb_query("scales/list"; kwargs...)
end

# Strata ----------------------------------------------------------------------

"""
	pbdb_strata(; kwargs...)

Get information about geological strata, selected by name, rank, and/or geography.

# Arguments
- `kwargs...`: Filtering and output parameters. Common options include:
  - `name`: Full or partial name (wildcards `%` and `_` allowed).
  - `rank`: One of "formation", "group", or "member".
  - `lngmin`, `lngmax`, `latmin`, `latmax`: Bounding box (if you provide one of `lngmin`/`latmin`, you must provide the paired max).
  - `loc`: WKT geometry string to constrain by polygon/geometry.
  - `vocab`: Set to "pbdb" to return full field names (default for text formats).

# Returns
A `DataFrame` with strata records matching the query.

# Examples
```julia
pbdb_strata(rank="formation", lngmin=-120, lngmax=-100, latmin=30, latmax=50)
```
"""
function pbdb_strata(; kwargs...)
	return pbdb_query("strata/list"; kwargs...)
end

"""
	pbdb_strata_auto(; kwargs...)

Autocomplete: list of strata matching a given prefix or partial name.

# Arguments
- `kwargs...`: Common options include:
  - `name`: Prefix or partial name (≥ 3 significant characters). May end with a space + `g` or `f` to hint at group/formation.
  - `rank`: Optional rank filter ("formation" or "group").
  - `lngmin`, `lngmax`, `latmin`, `latmax`: Optional bounding box to constrain suggestions.
  - `limit`: Maximum number of matches.

# Returns
A `DataFrame` of matching stratum names, ranks, and occurrence counts (JSON endpoint is converted to `DataFrame`).

# Examples
```julia
pbdb_strata_auto(name="Pin"; vocab="pbdb")
```
"""
function pbdb_strata_auto(; kwargs...)
	return pbdb_query("strata/auto"; format = :json, kwargs...)
end

# References ------------------------------------------------------------------

"""
	pbdb_reference(id; kwargs...)

Get information about a single bibliographic reference.

# Arguments
- `id`: Reference identifier (required).
- `kwargs...`: Additional parameters, for example:
  - `vocab`: Set to "pbdb" to use full field names.
  - `show`: Extra information blocks (e.g. "counts" to report numbers of taxa/opinions/occurrences/specimens; "both" to include both formatted reference and individual fields).

# Returns
A `DataFrame` with information about the requested reference.

# Examples
```julia
pbdb_reference(1003; vocab="pbdb", show="both")
```
"""
function pbdb_reference(id; kwargs...)
	return pbdb_query("refs/single"; id = id, kwargs...)
end

"""
	pbdb_references(; kwargs...)

Get information about multiple bibliographic references.

# Arguments
- `kwargs...`: Filtering and output parameters. Common options include:
  - `ref_author`: Match on author last name(s).
  - `ref_pubyr`: Publication year.
  - `pub_title`: Publication title.
  - `order`: Sort order; one or more of "author", "pubyr", "reftitle", "pubtitle", "pubtype", "created", "modified", "rank", with optional ".asc"/".desc" suffix.
  - `vocab`: Set to "pbdb" for full field names.

# Returns
A `DataFrame` with references matching the query.

# Examples
```julia
pbdb_references(ref_author="Polly")
```
"""
function pbdb_references(; kwargs...)
	return pbdb_query("refs/list"; kwargs...)
end

"""
	pbdb_ref_collections(; kwargs...)

Get bibliographic references from which collection data were entered.

# Arguments
- `kwargs...`: Filtering options, e.g.:
  - `id`: One or more collection identifiers.
  - `base_name`: Restrict to collections associated with a given taxon (and all descendants).
  - `ref_author`, `ref_pubyr`, `pub_title`: Reference filters as in `pbdb_references`.
  - `order`: Sort order (see PBDB docs).
  - `vocab`: Field naming vocabulary.

# Returns
A `DataFrame` listing references associated with the selected collections.

# Examples
```julia
pbdb_ref_collections(base_name="Canidae", interval="Quaternary", cc="ASI")
```
"""
function pbdb_ref_collections(; kwargs...)
	return pbdb_query("colls/refs"; kwargs...)
end

"""
	pbdb_ref_taxa(; kwargs...)

Get bibliographic references associated with taxonomic names.

This mirrors `pbdb_taxa` filters but returns reference records instead of taxa.

# Arguments
- `kwargs...`: Accepts the same taxon selectors as `pbdb_taxa`, e.g.:
  - `name` or `id`: Base taxon.
  - `rel`: Relationship (e.g. "synonyms", "children", "all_children", "all_parents").
  - `extant`: Logical; restrict to extant/non-extant taxa.
  - `show`: Extra blocks (e.g. "both", "comments").
  - `vocab`: Field naming vocabulary.

# Returns
A `DataFrame` with references linked to the selected taxa.

# Examples
```julia
pbdb_ref_taxa(name="Canidae"; vocab="pbdb", show=["both","comments"])
```
"""
function pbdb_ref_taxa(; kwargs...)
	return pbdb_query("taxa/refs"; kwargs...)
end

# Specimens & measurements -----------------------------------------------------

"""
	pbdb_specimen(id; kwargs...)

Get information about a single fossil specimen.

# Arguments
- `id`: Identifier of the specimen (required).
- `kwargs...`: Additional query parameters. Common options include:
  - `vocab`: Set to `"pbdb"` to use full field names.
  - `show`: Extra blocks (`"loc"`, `"stratext"`, `"lithext"`, `"refattr"`).

# Returns
A `DataFrame` describing the specified specimen.

# Examples
```julia
pbdb_specimen(30050; show=["class","loc","refattr"])
```
"""
function pbdb_specimen(id; kwargs...)
	return pbdb_query("specs/single"; id = id, kwargs...)
end

"""
	pbdb_specimens(; kwargs...)

Get information about multiple fossil specimens.

# Arguments
- `kwargs...`: Filtering and output parameters. Common options include:
  - `base_name`: Restrict to specimens of a given taxon (and descendants).
  - `interval`: Restrict by geologic interval.
  - `show`: Extra blocks (`"spec"`, `"class"`, `"loc"`, `"stratext"`, `"lithext"`).
  - `vocab`: Set to `"pbdb"` to return full field names.

# Returns
A `DataFrame` with specimen records matching the query.

# Examples
```julia
pbdb_specimens(base_name="Cetacea", interval="Miocene"; vocab="pbdb")
```
"""
function pbdb_specimens(; kwargs...)
	return pbdb_query("specs/list"; kwargs...)
end

"""
	pbdb_ref_specimens(; kwargs...)

Get bibliographic references associated with fossil specimens.

# Arguments
- `kwargs...`: Filtering options. Common parameters include:
  - `spec_id`: One or more specimen identifiers.
  - `base_name`: Taxonomic filter (taxon and descendants).
  - `ref_author`: Filter by author name.
  - `ref_pubyr`: Filter by publication year.
  - `pub_title`: Filter by publication title.

# Returns
A `DataFrame` with references linked to the selected specimens.

# Examples
```julia
pbdb_ref_specimens(spec_id=[1505, 30050])
```
"""
function pbdb_ref_specimens(; kwargs...)
	return pbdb_query("specs/refs"; kwargs...)
end

"""
	pbdb_measurements(; kwargs...)

Get information about specimen measurements.

# Arguments
- `kwargs...`: Filtering and output parameters. Common options include:
  - `spec_id`: Vector of specimen identifiers.
  - `occ_id`: Vector of occurrence identifiers.
  - `coll_id`: Vector of collection identifiers.
  - `show`: Extra blocks (e.g. `"spec"`, `"methods"`).
  - `vocab`: Field naming vocabulary.

# Returns
A `DataFrame` of measurement records.

# Examples
```julia
pbdb_measurements(spec_id=[1505,30050]; show=["spec","class","methods"], vocab="pbdb")
```
"""
function pbdb_measurements(; kwargs...)
	return pbdb_query("specs/measurements"; kwargs...)
end

# Opinions --------------------------------------------------------------------

"""
	pbdb_opinion(id; kwargs...)

Get information about a single taxonomic opinion.

# Arguments
- `id`: Identifier of the opinion (required).
- `kwargs...`: Additional parameters, for example:
  - `vocab`: Set to `"pbdb"` to return full field names.
  - `show`: Extra information blocks (e.g. `"basis"`, `"entname"`, `"refattr"`).

# Returns
A `DataFrame` with the requested opinion.

# Examples
```julia
pbdb_opinion(1000; vocab="pbdb", show="full")
```
"""
function pbdb_opinion(id; kwargs...)
	return pbdb_query("opinions/single"; id = id, kwargs...)
end

"""
	pbdb_opinions(; kwargs...)

Get information about multiple taxonomic opinions.

# Arguments
- `kwargs...`: Filtering options. Common parameters include:
  - `id`: One or more opinion identifiers.
  - `op_author`: Filter by opinion author name(s).
  - `ops_created_before`, `ops_created_after`: Date/time filters.
  - `op_type`: Opinion type filter (`"all"`, `"class"`, `"valid"`, `"accepted"`, `"junior"`, `"invalid"`).
  - `vocab`: Vocabulary for field names.

# Returns
A `DataFrame` with opinions matching the query.

# Examples
```julia
pbdb_opinions(op_pubyr=1818)
```
"""
function pbdb_opinions(; kwargs...)
	return pbdb_query("opinions/list"; kwargs...)
end

"""
	pbdb_opinions_taxa(; kwargs...)

Get taxonomic opinions about taxa, used to build the PBDB taxonomic hierarchy.

# Arguments
- `kwargs...`: Filtering options, e.g.:
  - `base_name`: Taxon (and descendants).
  - `name` or `id`: Base taxon selector.
  - `rel`: Relationship filter (e.g. `"synonyms"`, `"children"`).
  - `vocab`: Vocabulary for field names.

# Returns
A `DataFrame` with taxonomic opinions for the selected taxa.

# Examples
```julia
pbdb_opinions_taxa(base_name="Canis")
```
"""
function pbdb_opinions_taxa(; kwargs...)
	return pbdb_query("taxa/opinions"; kwargs...)
end

"""
	pbdb_config(; kwargs...)

Query the PBDB configuration endpoint.

The configuration endpoint provides metadata tables that describe
available cluster levels, continents, vocabularies, and other
reference information needed for interpreting and filtering PBDB data.

# Arguments
- `kwargs...`: Commonly used parameters include:
  - `show`: Which configuration table to return. Examples:
	- `"clusters"`: Available geographic cluster levels (for use with `pbdb_collections_geo`).
	- `"continents"`: Continent codes recognized by PBDB.
	- `"vocabularies"`: Available vocabularies for field names.
	- `"ecologies"`, `"lithologies"`, etc. (see PBDB documentation for a full list).
	- Full list:
		- 'clusters',
		- 'ranks',
		- 'continents',
		- 'countries',
		- 'collblock',
		- 'lithblock',
		- 'lithologies',
		- 'minorliths',
		- 'lithification',
		- 'lithadj',
		- 'envs',
		- 'envtypes',
		- 'tecs',
		- 'collmet',
		- 'datemet',
		- 'colltype',
		- 'collcov',
		- 'presmodes',
		- 'resgroups',
		- 'museums',
		- 'abundance',
		- 'plant',
		- 'pgmodels',
		- 'prefs',
		- 'all'

# Returns
A `DataFrame` with the requested configuration information.

# Examples
```julia
# List available geographic cluster levels
pbdb_config(show="clusters")

# List continent codes
pbdb_config(show="continents")

# List taxonomic ranks
pbdb_config(show="ranks")

```
"""
function pbdb_config(; kwargs...)
	return pbdb_query("config"; kwargs...)
end
