using Documenter
using PaleobiologyDB
using PaleobiologyDB.ApiHelp
using PaleobiologyDB.Taxonomy
using PaleobiologyDB.Depot
import PhyloPicMakie

# Trigger TaxonomyMakie extension (requires Makie + PhyloPicMakie)
using CairoMakie
using PaleobiologyDB.TaxonomyMakie

makedocs(
    sitename = "PaleobiologyDB.jl",
    authors = "Jeet Sukumaran",
    modules = [PaleobiologyDB, PaleobiologyDB.ApiHelp, PaleobiologyDB.Taxonomy, PaleobiologyDB.Depot, PaleobiologyDB.TaxonomyMakie],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://jeetsukumaran.github.io/PaleobiologyDB.jl",
    ),
    pages = [
        "Home" => "index.md",
        "Guide" => [
            "Quick Start"      => "guide/quickstart.md",
            "Caching"          => "guide/caching.md",
            "TaxonomyMakie"    => "guide/taxonomytree_makie.md",
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
            "TaxonomyMakie"            => "api/taxonomytree_makie.md",
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
