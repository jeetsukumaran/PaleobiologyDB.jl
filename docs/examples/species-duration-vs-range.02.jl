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
		# Use the modern "occ:####" id styleggg
		extids = true,
		# Rest of query
		query_kwargs...,
	)
end

"""
Returns a occurrences dataset queried by `query_kwargs`, cleaned to minimum
taxonomic resolutions.

Examples:

```julia

carnivora = acquire_data(;
	base_name = "Carnivora",
	extant = false,
)
mammals = acquire_data(;
	base_name = "Mammalia",
	extant = false,
)
brachs = acquire_data(
	:genus;
	base_name = "Brachiopoda",
	extant = false,
)
```

"""
function acquire_data(
	taxonomic_resolution::Symbol = :species, # :species | :genus | :family
	;
	query_kwargs...,
)::DataFrame
	query_kwargs = (idreso = taxonomic_resolution, query_kwargs...)
	query_occurrences(query_kwargs)
end

function adapt_data(
	df::DataFrame,
	data_adapter::Dict{Symbol, Symbol},
)::DataFrame
	original_names = collect(keys(data_adapter))
	rename!(select!(dropmissing(df, original_names), original_names), data_adapter)
end

function aggregate_data(adapted_df::DataFrame, minimum_group_size::Int = 2)::GroupedDataFrame
	gdf = groupby(adapted_df, :identifier)
	filter(sdf -> nrow(sdf) >= minimum_group_size, gdf)
end

function transform_data(gdf::GroupedDataFrame)::DataFrame
	combine(
		gdf,
		[
			:identifier => unique => :identifier,
			:identifier => length => :n_samples,
			:age => (ages -> maximum(ages) - minimum(ages)) => :age_span,
			[:lon, :lat] => ((lon, lat) -> begin
				# dists = geospatial_distance_summary(lon, lat)
				gdists = pairwise_geospatial_distance_summary(lon, lat)
				return (
					geo_dist_min = gdists.min,
					geo_dist_max = gdists.min,
					geo_dist_mean = gdists.mean,
					geo_dist_median = gdists.median,
				)
			end) => AsTable,
			# [:lon, :lat] => ( (lon, lat) -> geospatial_distance_summary(lon, lat) ) => AsTable,
			# AsTable([:lon, :lat]) => ( coords -> geospatial_distance_summary(coords.lon, coords.lat) ) => AsTable,
		],
	)
end

function screen_results(rdf::DataFrame)::DataFrame
	gt0_fields = [
		:age_span,
		:geo_dist_min,
		:geo_dist_max,
		:geo_dist_mean,
		:geo_dist_median
	]
	subset(rdf, gt0_fields .=> (r -> r .> 0))
end

function process_df(
	occurs_df::DataFrame
	;
	identifier::Symbol = :accepted_name,
	age::Symbol = :direct_ma_value,
	lon::Symbol = :paleolng,
	lat::Symbol = :paleolat,
	min_occurs::Int = 2,
)::DataFrame
	data_adapter = Dict(
		identifier => :identifier,
		age => :age,
		lon => :lon,
		lat => :lat,
	)
	return(
		occurs_df 
			|> df -> adapt_data(occurs_df, data_adapter) 
			|> df -> aggregate_data(df, min_occurs) 
			|> transform_data
			|> screen_results
	)
end

## -- In the REPL --

using DataFrames
using CSV
using GLMakie

# mammals_df = acquire_data(:species; base_name = "Mammalia", extant = "no")
# # CSV.write(".cache/_paleobiologydb/mammalia_species.tsv", mammals_df; delim = '\t')
# brachs_df = acquire_data(:species; base_name = "Brachiopoda", extant = "no")
# # CSV.write(".cache/_paleobiologydb/brachipoda_species.tsv", brachs_df; delim = '\t')
# cached_df = CSV.read(".cache/_paleobiologydb/mammalia_species.tsv", DataFrame; delim = '\t')
# cached_df = CSV.read(".cache/_paleobiologydb/brachipoda.tsv", DataFrame; delim = '\t')
# occurs_df = cached_df
rdf = process_df(occurs_df,
	identifier = :accepted_name,
	age = :max_ma,
	lon = :lng,
	lat = :lat,
)