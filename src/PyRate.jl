module PyRate

# Based on:
#
#    [PyRate](https://github.com/dsilvestro/PyRate):
#
#    [PyRate/pyrate_utilities.r at master · dsilvestro/PyRate](https://github.com/dsilvestro/PyRate/blob/master/pyrate_utilities.r)
# 
# under the terms of the AGPL 3.0 License (see LICENSE).

using DataFrames, CSV, Distributions, Random, Statistics
export extract_ages, extract_ages_pbdb, extract_ages_tbl, extract_ages_14c, fit_prior

# Final output format - only custom struct needed
struct PyRateData
    data_arrays::Vector{Vector{Vector{Float64}}}
    names::Vector{String}
    taxa_names::Vector{String}
    traits::Union{Vector{Float64}, Nothing}
    
    function PyRateData(data_arrays, names, taxa_names, traits=nothing)
        new(data_arrays, names, taxa_names, traits)
    end
end

# Lightweight utility functions
no_extension(filename) = splitext(filename)[1]

function validate_input_data!(df::DataFrame)
    # Check for missing data in critical columns
    critical_cols = [:Species, :Status, :min_age, :max_age]
    for col in critical_cols
        if any(ismissing, df[!, col])
            missing_rows = findall(ismissing, df[!, col])
            error("Missing data in column $col at rows: $missing_rows")
        end
    end
    
    # Clean species names
    df.Species = replace.(df.Species, r"\s+" => "_")
    
    # Check for species listed as both extinct and extant
    species_status = combine(groupby(df, :Species), :Status => (x -> unique(x)) => :statuses)
    conflicts = filter(row -> length(row.statuses) > 1, species_status)
    if nrow(conflicts) > 0
        error("Species listed as both extinct and extant: $(conflicts.Species)")
    end
    
    return df
end

function apply_cutoff!(df::DataFrame, cutoff::Union{Float64, Nothing})
    if !isnothing(cutoff)
        age_ranges = df.max_age .- df.min_age
        excluded_mask = age_ranges .>= cutoff
        excluded_pct = round(100 * sum(excluded_mask) / nrow(df), digits=1)
        
        filter!(row -> (row.max_age - row.min_age) < cutoff, df)
        println("Excluded $excluded_pct% occurrences with age range ≥ $cutoff")
    end
    return df
end

function randomize_ages!(df::DataFrame, random::Bool, site_column::Union{Symbol, Nothing}=nothing)
    if !isnothing(site_column) && site_column in names(df)
        # Site-based randomization
        println("By-site age randomization...")
        site_stats = combine(groupby(df, site_column), 
                           :min_age => mean => :mean_min,
                           :max_age => mean => :mean_max)
        
        # Fix min/max order and generate random ages per site
        site_stats.adj_min = min.(site_stats.mean_min, site_stats.mean_max)
        site_stats.adj_max = max.(site_stats.mean_min, site_stats.mean_max)
        site_stats.random_age = [round(rand(Uniform(row.adj_min, row.adj_max)), digits=6) 
                               for row in eachrow(site_stats)]
        
        # Map back to original data
        site_lookup = Dict(zip(site_stats[!, site_column], site_stats.random_age))
        df.new_age = [site_lookup[site] for site in df[!, site_column]]
        
    elseif random
        # Individual randomization
        df.new_age = [round(rand(Uniform(min(row.min_age, row.max_age), 
                                       max(row.min_age, row.max_age))), digits=6)
                     for row in eachrow(df)]
    else
        # Use mean age
        df.new_age = (df.min_age .+ df.max_age) ./ 2
    end
    
    return df
end

function build_occurrence_arrays(df::DataFrame)
    species_list = sort(unique(df.Species))
    species_status = Dict()
    
    # Get status for each species (should be unique after validation)
    for species in species_list
        status = first(df[df.Species .== species, :Status])
        species_status[species] = lowercase(string(status))
    end
    
    # Build occurrence arrays
    occurrence_data = Vector{Float64}[]
    
    for species in species_list
        ages = df[df.Species .== species, :new_age]
        
        # Add 0 for extant species
        if species_status[species] == "extant"
            push!(ages, 0.0)
        end
        
        push!(occurrence_data, sort(ages, rev=true))  # PyRate expects newest first
    end
    
    return occurrence_data, species_list, species_status
end

function write_pyrate_file(output_file::String, data_sets::Vector{Vector{Vector{Float64}}}, 
                          names::Vector{String}, taxa_names::Vector{String}, 
                          traits::Union{Vector{Float64}, Nothing}=nothing)
    
    open(output_file, "w") do io
        println(io, "#!/usr/bin/env python")
        println(io, "from numpy import *")
        println(io, "")
        
        # Write each replicate
        for (i, data) in enumerate(data_sets)
            println(io, "data_$i=[")
            for (j, species_data) in enumerate(data)
                array_str = join(species_data, ",")
                if j < length(data)
                    println(io, "array([$array_str]),")
                else
                    println(io, "array([$array_str])")
                end
            end
            println(io, "]")
            println(io, "")
        end
        
        # Write data list and names
        data_refs = ["data_$i" for i in 1:length(data_sets)]
        println(io, "d=[$(join(data_refs, ","))]")
        println(io, "names=[$(join(["'$name'" for name in names], ","))]")
        println(io, "def get_data(i): return d[i]")
        println(io, "def get_out_name(i): return names[i]")
        
        # Write taxa names
        taxa_str = join(["'$name'" for name in taxa_names], "','")
        println(io, "taxa_names=['$taxa_str']")
        println(io, "def get_taxa_names(): return taxa_names")
        
        # Write traits if present
        if !isnothing(traits)
            trait_str = join(replace(string.(traits), "NaN" => "nan", "missing" => "nan"), ",")
            println(io, "")
            println(io, "trait1=array([$trait_str])")
            println(io, "traits=[trait1]")
            println(io, "def get_continuous(i): return traits[i]")
        end
    end
end

# Main API functions - R-like interface
function extract_ages(file::String; replicates::Int=1, cutoff::Union{Float64, Nothing}=nothing, 
                     random::Bool=true, outname::String="_PyRate", save_tax_list::Bool=true)
    
    # Load and validate data
    df = CSV.read(file, DataFrame, delim='\t', stripwhitespace=true)
    
    # Standardize column names
    ncols = ncol(df)
    if ncols == 4
        names!(df, [:Species, :Status, :min_age, :max_age])
    elseif ncols == 5
        if "site" in lowercase.(names(df)) || "SITE" in names(df)
            names!(df, [:Species, :Status, :min_age, :max_age, :site])
        else
            names!(df, [:Species, :Status, :min_age, :max_age, :trait])
        end
    else
        error("Input file must have 4 or 5 columns")
    end
    
    validate_input_data!(df)
    apply_cutoff!(df, cutoff)
    
    # Force random=true for multiple replicates
    if replicates > 1
        random = true
    end
    
    # Generate replicates
    fname = no_extension(basename(file))
    outfile = joinpath(dirname(file), fname * outname * ".py")
    
    all_data_sets = Vector{Vector{Float64}}[]
    all_names = String[]
    
    site_col = :site in names(df) ? :site : nothing
    
    for rep in 1:replicates
        println("Replicate $rep")
        
        # Create a copy for this replicate
        df_rep = copy(df)
        randomize_ages!(df_rep, random, site_col)
        
        occurrence_data, taxa_names, _ = build_occurrence_arrays(df_rep)
        push!(all_data_sets, occurrence_data)
        push!(all_names, "$(fname)_$rep")
    end
    
    # Extract traits if present
    traits = nothing
    if :trait in names(df)
        species_list = sort(unique(df.Species))
        traits = [mean(skipmissing(df[df.Species .== species, :trait])) for species in species_list]
    end
    
    # Write PyRate file
    write_pyrate_file(outfile, all_data_sets, all_names, taxa_names, traits)
    
    # Save taxon list if requested
    if save_tax_list
        splist_file = joinpath(dirname(file), fname * "_TaxonList.txt")
        splist = unique(df[!, [:Species, :Status]])
        sort!(splist, :Species)
        CSV.write(splist_file, splist, delim='\t')
    end
    
    println("\nPyRate input file was saved in: $outfile\n")
    
    # Return Julia object for further processing
    return PyRateData(all_data_sets, all_names, taxa_names, traits)
end

function extract_ages_pbdb(file::String; sep::String=",", extant_species::Vector{String}=String[], 
                          replicates::Int=1, cutoff::Union{Float64, Nothing}=nothing, random::Bool=true)
    
    println("This function is currently being tested - caution with the results!")
    
    # Read PBDB format
    tbl = CSV.read(file, DataFrame, delim=sep[1])
    
    # Convert to standard format
    new_data = DataFrame()
    new_data.Species = replace.(tbl.accepted_name, " " => "_")
    new_data.Status = [name in extant_species ? "extant" : "extinct" for name in tbl.accepted_name]
    new_data.min_age = tbl.min_ma
    new_data.max_age = tbl.max_ma
    
    # Save as temporary file and process
    output_file = no_extension(file) * ".txt"
    CSV.write(output_file, new_data, delim='\t')
    
    return extract_ages(output_file; replicates=replicates, cutoff=cutoff, random=random)
end

function extract_ages_tbl(file::String; sep::String="\t", extant_species::Vector{String}=String[],
                         replicates::Int=1, cutoff::Union{Float64, Nothing}=nothing, random::Bool=true)
    
    tbl = CSV.read(file, DataFrame, delim=sep[1])
    
    # Convert to standard format
    new_data = DataFrame()
    new_data.Species = replace.(string.(tbl[!, 1]), " " => "_")
    new_data.Status = [name in extant_species ? "extant" : "extinct" for name in tbl[!, 1]]
    new_data.min_age = tbl[!, 2]
    new_data.max_age = tbl[!, 3]
    
    # Add trait column if present
    if ncol(tbl) > 3
        new_data.trait = tbl[!, 4]
    end
    
    # Save as temporary file and process
    output_file = no_extension(file) * ".txt"
    CSV.write(output_file, new_data, delim='\t')
    
    return extract_ages(output_file; replicates=replicates, cutoff=cutoff, random=random)
end

function extract_ages_14c(file::String; outname::String="_PyRate")
    df = CSV.read(file, DataFrame, delim='\t', stripwhitespace=true)
    
    # Clean species names
    df[!, 1] = replace.(df[!, 1], r"\s+" => "_")
    
    # Rename columns
    rename!(df, 1 => :Lineage, 2 => :Status)
    
    # Get replicates from remaining columns
    age_columns = names(df)[3:end]
    replicates = length(age_columns)
    
    fname = no_extension(basename(file))
    outfile = joinpath(dirname(file), fname * outname * ".py")
    
    all_data_sets = Vector{Vector{Float64}}[]
    all_names = String[]
    
    for (rep, col) in enumerate(age_columns)
        println("Replicate $rep")
        
        df_rep = select(df, :Lineage, :Status, col => :new_age)
        occurrence_data, taxa_names, _ = build_occurrence_arrays(df_rep)
        
        push!(all_data_sets, occurrence_data)
        push!(all_names, "$(fname)_$rep")
    end
    
    write_pyrate_file(outfile, all_data_sets, all_names, taxa_names)
    
    println("\nPyRate input file was saved in: $outfile\n")
    
    return PyRateData(all_data_sets, all_names, taxa_names)
end

function fit_prior(file::String, lineage::String="root_age")
    # try
    #     using Distributions
    # catch
    #     error("Distributions.jl package required for prior fitting. Please install it.")
    # end
    
    dat = CSV.read(file, DataFrame, delim='\t')
    fname = no_extension(basename(file))
    outfile = joinpath(dirname(file), "$(lineage)_Prior.txt")
    
    lineage_col = lineage * "_TS"
    if !(lineage_col in names(dat))
        error("Lineage '$lineage_col' not found in data. Available columns: $(names(dat))")
    end
    
    times = dat[!, lineage_col]
    times_shifted = times .- (minimum(times) - 0.01)
    
    # Fit gamma distribution using method of moments as approximation
    μ = mean(times_shifted)
    σ² = var(times_shifted)
    
    # Method of moments estimates
    scale = σ² / μ
    shape = μ / scale
    
    offset = minimum(times)
    
    # Write results
    open(outfile, "w") do io
        print(io, "Lineage: $lineage; Shape: $shape; Scale: $scale; Offset: $offset")
    end
    
    println("Prior parameters saved to: $outfile")
    return (shape=shape, scale=scale, offset=offset)
end

end # module