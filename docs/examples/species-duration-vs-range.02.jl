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
    occurrences_df(; kwargs...)

Return a occurrences dataset queried by `kwargs`, cleaned to minimum
taxonomic, temporal, and spatial data resolutions.
"""
function occurrences_df(
        taxonomic_resolution::Symbol = :species, # :species | :genus | :family
        time_source::Symbol = :direct_ma_value,
        ;
        filter_kwargs...,
)
    filter_kwargs = (idreso = taxonomic_resolution, filter_kwargs...)
    label_field = if taxonomic_resolution == :species
            :accepted_name
        else
            taxonomic_resolution
        end
    span_fn = vals -> maximum(vals) - minimum(vals)
    return (
        filter_kwargs
            |> fetch_occurrences_pbdb
            |> df -> dropmissing(df, [:accepted_rank, time_source, label_field])
            # |> df -> filter(row -> minimum_taxonomy_fn(row) && minimum_chronology_fn(row), df)
    )
end