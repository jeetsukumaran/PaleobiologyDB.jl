using Documenter
using PaleobiologyDB
using PaleobiologyDB.ApiHelp
using PaleobiologyDB.Taxonomy
using PaleobiologyDB.Depot
import PhyloPicMakie

# Trigger TaxonTreeMakie extension (requires CairoMakie)
using CairoMakie
using PaleobiologyDB.TaxonTreeMakie

makedocs(
    sitename = "PaleobiologyDB.jl",
    authors = "Jeet Sukumaran",
    modules = [PaleobiologyDB, PaleobiologyDB.ApiHelp, PaleobiologyDB.Taxonomy, PaleobiologyDB.Taxonomy.PhyloPicPBDB, PaleobiologyDB.Depot, PhyloPicMakie, PaleobiologyDB.TaxonTreeMakie],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://jeetsukumaran.github.io/PaleobiologyDB.jl",
    ),
    pages = [
        "Home" => "index.md",
        "Guide" => [
            "Quick Start"      => "guide/quickstart.md",
            "Caching"          => "guide/caching.md",
            "TaxonTreeMakie"   => "guide/taxontree_makie.md",
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
            "Taxonomy"         => "api/taxonomy.md",
            "TaxonTreeMakie"   => "api/taxontree_makie.md",
            "PhyloPicMakie"    => "api/phylopic_makie.md",
        ],
    ],
    checkdocs = :exports,
    warnonly = true,
)

deploydocs(
    repo = "github.com/jeetsukumaran/PaleobiologyDB.jl",
    devbranch = "main",
)
