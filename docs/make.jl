using Documenter
using PaleobiologyDB
using PaleobiologyDB.ApiHelp

makedocs(
    sitename = "PaleobiologyDB.jl",
    authors = "Jeet Sukumaran",
    modules = [PaleobiologyDB, PaleobiologyDB.ApiHelp],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://jeetsukumaran.github.io/PaleobiologyDB.jl",
    ),
    pages = [
        "Home" => "index.md",
        "Guide" => [
            "Quick Start"      => "guide/quickstart.md",
            "Caching"          => "guide/caching.md",
        ],
        "API Reference" => [
            "Occurrences"      => "api/occurrences.md",
            "Collections"      => "api/collections.md",
            "Taxa"             => "api/taxa.md",
            "Specimens"        => "api/specimens.md",
            "Other"            => "api/other.md",
            "Interactive Help" => "api/apihelp.md",
        ],
    ],
    checkdocs = :exports,
    warnonly = true,
)

deploydocs(
    repo = "github.com/jeetsukumaran/PaleobiologyDB.jl",
    devbranch = "main",
)
