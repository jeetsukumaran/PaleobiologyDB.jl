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
    time::Symbol = :direct_ma_value,
    lon::Symbol = :paleolng,
    lat::Symbol = :paleolat,
)::Dict{Symbol, Symbol}
    Dict(
        taxon => :taxon,
        time => :time,
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


# tdf = adapted_df[rand(1:759, 10), :]
# function spatial_data_aggregator(
#     df::DataFrame,
#     data_adapter::Dict{Symbol, Symbol},
#     minimum_r
# )::DataFrame
#     df_ = dropmissing(df, keys(data_adapter))
#     rename!(df_, da.taxon => :taxon)
#     df_
# end

function spatiotemporal_spans(
    df::DataFrame,
    data_adapter::Dict{Symbol, Symbol}
)::DataFrame
    df = dropmissing(df, original_names)
    spans = combine(groupby(df, taxonomy_field),
        da_keys .=> transform_fn .=> da_values
    )
    rename!(spans, da.taxon => :taxon)
    sort!(spans, [:lat_span, :lon_span, :time_span])
end



function run()
    occs = taxon_resolved_occurrences(
        :species ; # minimal taxonomic data quality
        base_name = "Mammalia",
        extant = "no",
    )
    # 62180×141 DataFrame
end
