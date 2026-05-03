include(joinpath(@__DIR__, "src", "taxonomytree.jl"))

function main(; output_dir::Union{Nothing, AbstractString} = nothing)::Vector{String}
    output_paths = TaxonomyTreeExample.smoke_main(; output_dir)
    missing_paths = filter(path -> !isfile(path), output_paths)
    isempty(missing_paths) || error(
        "Taxonomy tree smoke run did not create expected artifacts: $(join(missing_paths, ", "))."
    )
    return output_paths
end

if abspath(PROGRAM_FILE) == @__FILE__
    for output_path in main()
        println(output_path)
    end
end
