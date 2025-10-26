# using Dates

"""
Internal function to handle caching logic for PBDB queries.
"""
function _handle_cache(
    cache_path::Union{String, Nothing},
    query_func::Function; 
    is_force_refresh::Bool = false
)
    if isnothing(cache_path)
        # No caching requested, execute query directly
        return query_func()
    end
    ext = lowercase(splitext(cache_path)[2])
    delim = ext == ".tsv" ? '\t' : ','
    if isfile(cache_path) && !is_force_refresh
        # Cache file exists, read it
        try
            # Determine format from file extension
            df = DataFrame(CSV.File(cache_path; delim = delim, normalizenames = true))
            @debug "Read cache file '$cache_path': DataFrame with size $(size(df))."
            @warn "Using cached results from: '$cache_path'"
            return df
        catch e
            @debug "Failed to read cache file $cache_path: $e. Executing fresh query."
        end
    end

    # Cache doesn't exist or failed to read, execute query
    @debug "Running live query"
    df = query_func()
    
    # Create parent directory if it doesn't exist
    @debug "Caching query results"
    cache_dir = dirname(cache_path)
    if !isdir(cache_dir) && !isempty(cache_dir)
        mkpath(cache_dir)
    end
    
    # Write to cache
    try
        CSV.write(cache_path, df; delim = delim)
        @debug "Wrote cache file $cache_path: DataFrame with size $(size(df))."
    catch e
        @warn "Failed to write cache file $cache_path: $e"
    end
    
    return df
end