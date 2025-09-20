# using Dates

"""
Internal function to handle caching logic for PBDB queries.
"""
function _handle_cache(cache_path::Union{String, Nothing}, query_func::Function)
    if isnothing(cache_path)
        # No caching requested, execute query directly
        return query_func()
    end
    
    if isfile(cache_path)
        # Cache file exists, read it
        try
            # Determine format from file extension
            ext = lowercase(splitext(cache_path)[2])
            if ext == ".tsv"
                return DataFrame(CSV.File(cache_path; delim='\t', normalizenames=true))
            elseif ext == ".csv"
                return DataFrame(CSV.File(cache_path; delim=',', normalizenames=true))
            else
                # Default to CSV
                return DataFrame(CSV.File(cache_path; normalizenames=true))
            end
        catch e
            @warn "Failed to read cache file $cache_path: $e. Executing fresh query."
            # If reading fails, fall through to execute fresh query
        end
    end

    # Cache doesn't exist or failed to read, execute query
    df = query_func()
    
    # Create parent directory if it doesn't exist
    cache_dir = dirname(cache_path)
    if !isdir(cache_dir) && !isempty(cache_dir)
        mkpath(cache_dir)
    end
    
    # Write to cache
    try
        # Determine format from file extension
        ext = lowercase(splitext(cache_path)[2])
        if ext == ".tsv"
            CSV.write(cache_path, df; delim='\t')
        elseif ext == ".csv"
            CSV.write(cache_path, df; delim=',')
        else
            # Default to CSV
            CSV.write(cache_path, df)
        end
    catch e
        @warn "Failed to write cache file $cache_path: $e"
    end
    
    return df
end