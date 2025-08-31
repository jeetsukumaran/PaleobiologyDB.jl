export collection_occurrences, occurrences_taxa

function collection_occurrences(coll_id; kwargs...)
    pbdb_occurrences(
        ;
        coll_id = coll_id,
        show = "full",
        vocab = "pbdb",
        extids = true,
        kwargs ...
    )
end

function occurrences_taxa(occs::DataFrame; kwargs...)
    return (

    gdf = groupby(occs, :accepted_no);
    combine(gdf, [
        :accepted_no,
        :accepted_name,
        :accepted_rank,
        :lng,
        :lat,
        :paleolng,
        :paleolat,
        :early_interval,
        :late_interval,
        :max_ma,
        :min_ma,
        :phylum,
        :class,
        :order,
        :family,
        :genus,
    ] .=> unique)
)
end