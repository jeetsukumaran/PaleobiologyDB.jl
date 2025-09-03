using DataFrames
using DataFrames: DataFrame
using Statistics
using PaleobiologyDB

include("geocalcs.jl")

function query_occurrences(query_kwargs)::DataFrame
    pbdb_occurrences(
        ;
        show=[
            # Adds most extra fields: coords, paleocoord
            "full",
            # Required to also add: 'species_name'
            "ident",
        ],
        # Use the expanded field names
        vocab="pbdb",
        # Use the modern "occ:####" id styleggg
        extids=true,
        # Rest of query
        query_kwargs...,
    )
end

"""
Returns a occurrences dataset queried by `query_kwargs`, cleaned to minimum
taxonomic resolutions.

Examples:

```julia

carnivora = read_taxon_resolved_occurrences(;
    base_name = "Carnivora",
    extant = false,
)
mammals = read_taxon_resolved_occurrences(;
    base_name = "Mammalia",
    extant = false,
)
brachs = read_taxon_resolved_occurrences(
    :genus;
    base_name = "Brachiopoda",
    extant = false,
)
```

"""
function read_taxon_resolved_occurrences(
    taxonomic_resolution::Symbol=:species, # :species | :genus | :family
    ;
    query_kwargs...,
)::DataFrame
    query_kwargs = (idreso=taxonomic_resolution, query_kwargs...)
    query_occurrences(query_kwargs)
end

function adapt_data(
    df::DataFrame,
    data_adapter::Dict{Symbol,Symbol}
)::DataFrame
    original_names = collect(keys(data_adapter))
    rename!(select!(dropmissing(df, original_names), original_names), data_adapter)
end

function aggregate_data(adapted_df::DataFrame, minimum_group_size::Int=2)::GroupedDataFrame
    gdf = groupby(adapted_df, :identifier)
    filter(sdf -> nrow(sdf) >= minimum_group_size, gdf)
end

function transform_data(gdf::GroupedDataFrame)::DataFrame
    combine(gdf, [
        :identifier => unique => :identifier,
        :identifier => length => :n_samples,
        :age => (ages -> maximum(ages) - minimum(ages)) => :age_span,
        [:lon, :lat] => ((lon, lat) -> begin
            # dists = geospatial_distance_summary(lon, lat)
            gdists = pairwise_geospatial_distance_summary(lon, lat)
            return (
                geo_dist_min=gdists.min,
                geo_dist_max=gdists.min,
                geo_dist_mean=gdists.mean,
                geo_dist_median=gdists.median,
            )
        end) => AsTable,
        # [:lon, :lat] => ( (lon, lat) -> geospatial_distance_summary(lon, lat) ) => AsTable,
        # AsTable([:lon, :lat]) => ( coords -> geospatial_distance_summary(coords.lon, coords.lat) ) => AsTable,
    ]
    )
end

function process_df(
    occurs_df::DataFrame
    ;
    identifier::Symbol=:accepted_name,
    age::Symbol=:direct_ma_value,
    lon::Symbol=:paleolng,
    lat::Symbol=:paleolat,
    min_occurs::Int=2,
)::DataFrame
    data_adapter = Dict(
        identifier => :identifier,
        age => :age,
        lon => :lon,
        lat => :lat,
    )
    return (
        occurs_df
		|> df -> adapt_data(occurs_df, data_adapter)
        |> df -> aggregate_data(df, min_occurs)
        |> df -> transform_data(df)
        |> df -> filter(r.age_span > 0, df)
    )
end
## -- In the REPL --

using DataFrames
using CSV
using GLMakie

# live_df = taxon_resolved_occurrences(; base_name = "Mammalia", extant = "no")
# cached_df = CSV.read(".cache/_paleobiologydb/mammalia_species-directma-paleocoords.tsv", DataFrame)
cached_df = CSV.read(".cache/_paleobiologydb/brachioda_genus.tsv", DataFrame)
occurs_df = cached_df
rdf = process_df(occurs_df,
    identifier=:genus,
    age=:max_ma,
    lon=:lng,
    lat=:lat,
)

# function process_df(
#     occurs_df::DataFrame,
#     data_adapter::Dict{Symbol, Symbol},
#     min_occurs::Int = 2,
# )::DataFrame
#     return (
#         occurs_df
#             |> df -> adapt_data(occurs_df, data_adapter)
#             |> df -> aggregate_data(df, min_occurs)
#             |> df -> transform_data(df)
#             |> df -> filter(r.age_span > 0, df)
#     )
# end
