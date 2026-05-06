using Documenter
using PaleobiologyDB
using PaleobiologyDB.ApiHelp
using PaleobiologyDB.Taxonomy
using PaleobiologyDB.Depot

# Trigger PBDBMakie extension (requires a Makie backend).
# PhyloPicMakie is a hard dep of PaleobiologyDB and loads Makie transitively.
using CairoMakie
using PaleobiologyDB.PBDBMakie

pbdb_makie_ext = Base.get_extension(PaleobiologyDB, :PBDBMakieExt)
isnothing(pbdb_makie_ext) && error("PBDBMakieExt did not load after using PaleobiologyDB.PBDBMakie.")
phylopic_impl = getproperty(pbdb_makie_ext, :PhyloPic)

makedocs(
    sitename = "PaleobiologyDB.jl",
    authors = "Jeet Sukumaran",
    modules = [
        PaleobiologyDB,
        PaleobiologyDB.ApiHelp,
        PaleobiologyDB.Taxonomy,
        PaleobiologyDB.Depot,
        PaleobiologyDB.PBDBMakie,
        pbdb_makie_ext,
    ],
    checkdocs_ignored_modules = [phylopic_impl],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://jeetsukumaran.github.io/PaleobiologyDB.jl",
    ),
    pages = [
        "Home" => "index.md",
        "Guide" => [
            "Quick Start"      => "guide/quickstart.md",
            "Caching"          => "guide/caching.md",
            "PBDBMakie"    => "guide/taxonomytree_makie.md",
            "PhyloPicMakie"    => "guide/phylopic_makie.md",
            "Contributing"     => "guide/contributing.md",
        ],
        "API Reference" => [
            "Occurrences"      => "api/occurrences.md",
            "Collections"      => "api/collections.md",
            "Taxa"             => "api/taxa.md",
            "Specimens"        => "api/specimens.md",
            "Other"            => "api/other.md",
            "Interactive Help" => "api/apihelp.md",
            "Taxonomy: Filtering"   => "api/taxonomy_filtering.md",
            "Taxonomy: Queries"     => "api/taxonomy_queries.md",
            "Taxonomy: Graphs"      => "api/taxonomy_graphs.md",
            "Taxonomy: Search"      => "api/taxonomy_search.md",
            "PBDBMakie"            => "api/taxonomytree_makie.md",
            "PhyloPic: Acquisition" => "api/phylopic_acquire.md",
            "PhyloPic: Rendering"   => "api/phylopic_makie.md",
            "Depot"                 => "api/depot.md",
        ],
    ],
    checkdocs = :exports,
    warnonly = true,
)

deploydocs(
    repo = "github.com/jeetsukumaran/PaleobiologyDB.jl",
    devbranch = "main",
)
