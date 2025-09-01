using DataFrames
using Statistics
using PaleobiologyDB

function fetch_occurrences_pbdb(filter_kwargs)
    pbdb_occurrences(
        ;
        show = [
            "full", # coords, paleocoords
            "ident", # 'species_name'
        ],
        vocab = "pbdb",
        extids = true,
        filter_kwargs...,
    )
end

"""
Returns a occurrences dataset queried by `filter_kwargs`, cleaned to minimum
taxonomic resolutions.
"""
function occurrences_df(
        taxonomic_quality::Symbol = :species, # :species | :genus | :family
        ;
        filter_kwargs...,
)
    filter_kwargs = (idreso = taxonomic_quality, filter_kwargs...)
    fetch_occurrences_pbdb(filter_kwargs)
end

function spatiotemporal_spans_df(df;
        taxonomy_field::Symbol = :accepted_name,
        time_field::Symbol = :direct_ma_value,
        spatial_fields::Tuple{Symbol, Symbol} = (:paleolng, :paleolat),
)
    df = dropmissing(df, [taxonomy_field, time_field, spatial_fields...])
    span_fn = vals -> maximum(vals) - minimum(vals)
    spans = combine(groupby(df, taxonomy_field),
        [time_field, spatial_fields...] .=> span_fn .=> [:time_span, :lat_span, :lng_span]
    )
    rename!(spans, taxonomy_field => :taxon)
    filter!(r -> (r.time_span != 0) &&
                      (r.lat_span != 0) &&
                      (r.lng_span != 0), spans)

    sort!(spans, [:lat_span, :lng_span, :time_span])
end
