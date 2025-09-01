"""
    ApiHelp

Provides interactive help and documentation for the Paleobiology Database (PBDB) API.

## Available Functions

- `pbdb_help()` - Show available API endpoints or detailed help for a specific endpoint
- `pbdb_endpoints()` - List all available PBDB API endpoints
- `pbdb_parameters(endpoint)` - Show parameters for an endpoint
- `pbdb_fields(endpoint)` - Show response fields for an endpoint
- `pbdb_api_search(pattern)` - Search documentation for patterns

## Quick Start

```julia
# List all available endpoints
pbdb_help()

# Get detailed help for a specific endpoint
pbdb_help("occurrences")

# View parameters for an endpoint
pbdb_parameters("occurrences")

# View response fields
pbdb_fields("occurrences")

# Search documentation
pbdb_api_search("latitude")
```

## Common Usage Patterns

```julia
# Explore geographic parameters
pbdb_parameters("occurrences", category="geographic")

# Look at basic response fields only
pbdb_fields("occurrences", block="basic")

# Search only in parameters
pbdb_api_search("temporal", scope="parameters")
```
For detailed help on any function, use `?function_name` (e.g., `?pbdb_help`).

"""
module ApiHelp

using JSON3

# --- helpers ---------------------------------------------------------------

# Normalize something that might be a Symbol into a String for display
_to_string(x) = x isa Symbol ? String(x) : String(x)

# Lookup that accepts string keys for JSON3.Object with Symbol keys
# Returns the value or throws a clear error if not present
function _getkey(d, k::AbstractString)
    if haskey(d, k)
        return d[k]
    elseif haskey(d, Symbol(k))
        return d[Symbol(k)]
    else
        throw(KeyError(k))
    end
end

# Safe haskey that accepts String for JSON3.Object with Symbol keys
_haskey(d, k::AbstractString) = haskey(d, k) || haskey(d, Symbol(k))

# PBDB API Documentation as JSON strings
const API_DOCS = Dict{String, String}(
    "occurrences" => """{
        "endpoint": "/data1.2/occs/list",
        "title": "List of fossil occurrences",
        "description": "Returns information about multiple occurrences, selected according to the parameters you provide. You can select occurrences by taxonomy, geography, age, environment, and many other criteria.",
        "methods": ["GET", "HEAD"],
        "usage_examples": [
            "/data1.2/occs/list.txt?base_name=Cetacea&interval=Miocene&show=loc,class",
            "/data1.2/occs/list.json?base_name=Cetacea&interval=Miocene&show=loc,class"
        ],
        "formats": [
            {"suffix": ".json", "type": "JSON"},
            {"suffix": ".txt", "type": "Comma-separated text"},
            {"suffix": ".csv", "type": "Comma-separated text"},
            {"suffix": ".tsv", "type": "Tab-separated text"}
        ],
        "parameters": {
            "selection": [
                {"name": "all_records", "description": "Select all occurrences entered in the database"},
                {"name": "occ_id", "description": "Comma-separated list of occurrence identifiers"},
                {"name": "coll_id", "description": "Comma-separated list of collection identifiers"},
                {"name": "base_name", "description": "Taxonomic name(s), including all subtaxa and synonyms"},
                {"name": "taxon_name", "description": "Taxonomic name(s), including synonyms"},
                {"name": "taxon_id", "description": "Taxa identifiers, not including subtaxa or synonyms"}
            ],
            "geographic": [
                {"name": "lngmin", "description": "Minimum longitude bound"},
                {"name": "lngmax", "description": "Maximum longitude bound"},
                {"name": "latmin", "description": "Minimum latitude bound"},
                {"name": "latmax", "description": "Maximum latitude bound"},
                {"name": "cc", "description": "Country codes (e.g., 'US,CA') or continent codes"},
                {"name": "country_name", "description": "Full country names, may include wildcards"},
                {"name": "state", "description": "State or province names"}
            ],
            "temporal": [
                {"name": "interval", "description": "Named geologic time intervals (e.g., 'Miocene')"},
                {"name": "min_ma", "description": "Minimum age in millions of years"},
                {"name": "max_ma", "description": "Maximum age in millions of years"},
                {"name": "timerule", "description": "Temporal locality rule", "values": ["contain", "major", "overlap"]}
            ],
            "taxonomic": [
                {"name": "idreso", "description": "Taxonomic resolution", "values": ["species", "genus", "family"]},
                {"name": "taxon_status", "description": "Taxonomic status", "values": ["valid", "accepted", "invalid"]},
                {"name": "extant", "description": "Extant status", "values": ["yes", "no"]}
            ],
            "output": [
                {"name": "show", "description": "Additional info blocks", "values": ["class", "coords", "loc", "time", "strat", "env"]},
                {"name": "order", "description": "Result ordering", "values": ["id", "max_ma", "identification"]},
                {"name": "limit", "description": "Maximum number of records to return"}
            ]
        },
        "response_fields": {
            "basic": [
                {"pbdb": "occurrence_no", "com": "oid", "description": "Unique occurrence identifier"},
                {"pbdb": "collection_no", "com": "cid", "description": "Associated collection identifier"},
                {"pbdb": "identified_name", "com": "idn", "description": "Taxonomic name as identified"},
                {"pbdb": "accepted_name", "com": "tna", "description": "Accepted taxonomic name"},
                {"pbdb": "accepted_rank", "com": "rnk", "description": "Taxonomic rank"},
                {"pbdb": "early_interval", "com": "oei", "description": "Early geologic time interval"},
                {"pbdb": "late_interval", "com": "oli", "description": "Late geologic time interval"},
                {"pbdb": "max_ma", "com": "eag", "description": "Early age bound (Ma)"},
                {"pbdb": "min_ma", "com": "lag", "description": "Late age bound (Ma)"}
            ],
            "coords": [
                {"pbdb": "lng", "com": "lng", "description": "Longitude (degrees)"},
                {"pbdb": "lat", "com": "lat", "description": "Latitude (degrees)"}
            ],
            "class": [
                {"pbdb": "phylum", "com": "phl", "description": "Phylum name"},
                {"pbdb": "class", "com": "cll", "description": "Class name"},
                {"pbdb": "order", "com": "odl", "description": "Order name"},
                {"pbdb": "family", "com": "fml", "description": "Family name"},
                {"pbdb": "genus", "com": "gnl", "description": "Genus name"}
            ]
        }
    }"""
)

# Main exports (add pbdb_* aliases you advertised)
export help, endpoints, parameters, fields, search,
       pbdb_help, pbdb_endpoints, pbdb_parameters, pbdb_fields, pbdb_api_search

"""
    help()
    help(endpoint)

Show available PBDB API endpoints or detailed help for a specific endpoint.
"""
function help(endpoint::AbstractString = "")
    if isempty(endpoint)
        list_endpoints()
    else
        show_endpoint(endpoint)
    end
end

# Aliases with pbdb_* names
pbdb_help(args...; kwargs...) = help(args...; kwargs...)

"""
    endpoints()

List all available PBDB API endpoints.
"""
endpoints() = list_endpoints()
pbdb_endpoints() = endpoints()

"""
    parameters(endpoint; category="")

Show parameters for an endpoint, optionally filtered by category.
"""
function parameters(endpoint::AbstractString; category::AbstractString = "")
    doc_data = get_doc_data(endpoint)
    params = doc_data["parameters"]

    if isempty(category)
        for (cat_name, cat_params) in params
            # fix: cat_name may be a Symbol
            println("$(uppercase(_to_string(cat_name))) PARAMETERS:")
            for param in cat_params
                show_parameter(param)
            end
            println()
        end
    else
        if _haskey(params, category)
            println("$(uppercase(category)) PARAMETERS:")
            for param in _getkey(params, category)
                show_parameter(param)
            end
        else
            println("Category '$category' not found.")
            # show available categories normalized
            cats = [ _to_string(k) for (k, _) in params ]
            println("Available categories: ", join(cats, ", "))
        end
    end
end
pbdb_parameters(args...; kwargs...) = parameters(args...; kwargs...)

"""
    fields(endpoint; block="")

Show response fields for an endpoint, optionally filtered by block.
"""
function fields(endpoint::AbstractString; block::AbstractString = "")
    doc_data = get_doc_data(endpoint)
    field_blocks = doc_data["response_fields"]

    if isempty(block)
        for (block_name, block_fields) in field_blocks
            println("$(uppercase(_to_string(block_name))) FIELDS:")
            for field in block_fields
                show_field(field)
            end
            println()
        end
    else
        if _haskey(field_blocks, block)
            println("$(uppercase(block)) FIELDS:")
            for field in _getkey(field_blocks, block)
                show_field(field)
            end
        else
            println("Block '$block' not found.")
            blks = [ _to_string(k) for (k, _) in field_blocks ]
            println("Available blocks: ", join(blks, ", "))
        end
    end
end
pbdb_fields(args...; kwargs...) = fields(args...; kwargs...)

"""
    search(pattern; scope="all", endpoint="occurrences")

Search documentation for a pattern.
"""
function search(pattern; scope::AbstractString = "all", endpoint::AbstractString = "occurrences")
    doc_data = get_doc_data(endpoint)
    results = find_matches(doc_data, pattern, scope)

    if isempty(results)
        println("No matches found for '$pattern'")
        return
    end

    println("SEARCH RESULTS for '$pattern':")
    println("-" ^ 40)
    for (location, name, description) in results
        println("$location: $name")
        println("  $description")
        println()
    end
end
pbdb_api_search(args...; kwargs...) = search(args...; kwargs...)

# Internal functions
function list_endpoints()
    println("PALEOBIOLOGY DATABASE API ENDPOINTS")
    println("=" ^ 50)

    for (key, doc_json) in API_DOCS
        doc_data = JSON3.read(doc_json)
        println(key)
        println("  ", doc_data["endpoint"])
        println("  ", doc_data["title"])
        println()
    end

    println("Usage:")
    println("  help(\"endpoint_name\")     - Detailed endpoint help")
    println("  parameters(\"endpoint\")    - Show parameters")
    println("  fields(\"endpoint\")        - Show response fields")
    println("  search(\"pattern\")         - Search documentation")
end

function show_endpoint(endpoint::AbstractString)
    doc_data = get_doc_data(endpoint)

    println("ENDPOINT: ", doc_data["endpoint"])
    println("TITLE: ", doc_data["title"])
    println()
    println("DESCRIPTION:")
    println(doc_data["description"])
    println()

    println("USAGE EXAMPLES:")
    for example in doc_data["usage_examples"]
        println("  ", example)
    end
    println()

    println("AVAILABLE FORMATS:")
    for fmt in doc_data["formats"]
        println("  ", fmt["suffix"], " - ", fmt["type"])
    end
    println()

    println("Next steps:")
    println("  parameters(\"$endpoint\")  - View all parameters")
    println("  fields(\"$endpoint\")      - View response fields")
    println("  search(\"keyword\")        - Search this endpoint")
end

function get_doc_data(endpoint::AbstractString)
    if !haskey(API_DOCS, endpoint)
        println("Unknown endpoint '$endpoint'")
        println("Available endpoints:")
        for key in keys(API_DOCS)
            println("  ", key)
        end
        throw(ArgumentError("Invalid endpoint"))
    end
    return JSON3.read(API_DOCS[endpoint])
end

function show_parameter(param)
    print("  ", param["name"])
    if haskey(param, "values")
        print(" [", join(param["values"], "|"), "]")
    end
    println()
    println("    ", param["description"])
end

function show_field(field)
    println("  ", field["pbdb"], " (", field["com"], ")")
    println("    ", field["description"])
end

function find_matches(doc_data, pattern, scope::AbstractString)
    results = Vector{Tuple{String,String,String}}()
    search_regex = pattern isa Regex ? pattern : Regex(String(pattern), "i")

    # Search description
    if scope in ("all", "description")
        if occursin(search_regex, doc_data["description"])
            push!(results, ("Description", "Endpoint description", doc_data["description"]))
        end
    end

    # Search parameters
    if scope in ("all", "parameters")
        for (category, params) in doc_data["parameters"]
            cat = _to_string(category)
            for param in params
                searchtext = "$(param["name"]) $(param["description"])"
                if haskey(param, "values")
                    searchtext *= " " * join(param["values"], " ")
                end
                if occursin(search_regex, searchtext)
                    push!(results, ("Parameter", "$cat/$(param["name"])", param["description"]))
                end
            end
        end
    end

    # Search fields
    if scope in ("all", "fields")
        for (block, fields_list) in doc_data["response_fields"]
            blk = _to_string(block)
            for field in fields_list
                searchtext = "$(field["pbdb"]) $(field["description"])"
                if occursin(search_regex, searchtext)
                    push!(results, ("Field", "$blk/$(field["pbdb"])", field["description"]))
                end
            end
        end
    end

    return results
end

end # module Help
