using DataFrames
using DataFrames: DataFrame
using Statistics
using PaleobiologyDB

include("geocalcs.jl")

function query_occurrences(query_kwargs)::DataFrame
    pbdb_occurrences(
        ;
        show = [
            # Adds most extra fields: coords, paleocoord
            "full",
            # Required to also add: 'species_name'
            "ident",
        ],
        # Use the expanded field names
        vocab = "pbdb",
        # Use the modern "occ:####" id style
        extids = true,
        # Rest of query
        query_kwargs...,
    )
end

"""
Returns a occurrences dataset queried by `query_kwargs`, cleaned to minimum
taxonomic resolutions.
"""
function taxon_resolved_occurrences(
        taxonomic_resolution::Symbol = :species, # :species | :genus | :family
        ;
        query_kwargs...,
)::DataFrame
    query_kwargs = (idreso = taxonomic_resolution, query_kwargs...)
    query_occurrences(query_kwargs)
end

function occurrence_data_adapter(
    taxon::Symbol = :accepted_name,
    age::Symbol = :direct_ma_value,
    lon::Symbol = :paleolng,
    lat::Symbol = :paleolat,
)::Dict{Symbol, Symbol}
    Dict(
        taxon => :taxon,
        age => :age,
        lon => :lon,
        lat => :lat,
    )
end

function adapt_data(
    df::DataFrame,
    data_adapter::Dict{Symbol, Symbol}
)::DataFrame
    original_names = sort!(collect(keys(data_adapter)))
    rename!(select!(dropmissing(df, original_names), original_names), data_adapter)
end

function aggregate_data(adapted_df::DataFrame, minimum_nrows::Int = 2)::GroupedDataFrame
    gdf = groupby(df, :taxon)
    filter(sdf -> nrow(sdf) >= minimum_nrows, gdf)
end

function transform_data(gdf::GroupedDataFrame)::DataFrame
    combine(gdf, [
            :taxon => unique => :taxon,
            :age   => (ages -> maximum(ages) - minimum(ages)) => :age_span,
        ]
    )
end

## -----
using DataFrames
using CSV

# live_df = taxon_resolved_occurrences(; base_name = "Mammalia", extant = "no")
cached_df = CSV.read(".cache/_paleobiologydb/mammalia_species-directma-paleocoords.tsv", DataFrame)
df = cached_df
da = occurrence_data_adapter()
adapted_df = adapt_data(df, da)
grouped_data = aggregate_data(

gdf = groupby(df, :taxon)
sort(combine(gdf, nrow), :nrow)



result_df = transform_data(adapted_df)
result_df