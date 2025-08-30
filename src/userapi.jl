export collection_occurrences

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
