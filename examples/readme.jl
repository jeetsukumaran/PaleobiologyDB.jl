# PaleobiologyDB.jl — Collected examples from README with labels and success notices
# ======================================================================
using DataFrames
using PaleobiologyDB

# ----------------------------------------------------------------------
println("Example: Get fossil occurrences (Canidae, Miocene)")
canids = pbdb_occurrences(
    base_name = "Canidae",
    interval  = "Miocene",
    show      = ["coords", "class"],
    vocab     = "pbdb",
    limit     = 100
)
println(" -> Success: Retrieved $(nrow(canids)) records")

println("Example: Get taxonomic information (Canis)")
canis_info = pbdb_taxon(
    name  = "Canis",
    vocab = "pbdb",
    show  = ["attr", "app", "size"]
)
println(" -> Success: Retrieved $(nrow(canis_info)) records")

println("Example: Get a specific collection (1003)")
collection = pbdb_collection(
    1003,
    show  = ["loc", "stratext"],
    vocab = "pbdb"
)
println(" -> Success: Retrieved $(nrow(collection)) records")

# ----------------------------------------------------------------------
# Basic usage

println("Example: Simple occurrence query (Mammalia, limit=10)")
occs = pbdb_occurrences(base_name = "Mammalia", limit = 10)
println(" -> Success: Retrieved $(nrow(occs)) records")

println("Example: Specific occurrence (1001)")
single_occ = pbdb_occurrence(1001, vocab = "pbdb", show = ["coords", "class"])
println(" -> Success: Retrieved $(nrow(single_occ)) records")

println("Example: Geographic and temporal filtering (Pliocene mammals, N. America)")
pliocene_mammals = pbdb_occurrences(
    base_name = "Mammalia",
    interval  = "Pliocene",
    lngmin    = -130.0, lngmax = -60.0,
    latmin    = 25.0,   latmax = 70.0,
    show      = ["coords", "classext", "stratext"],
    vocab     = "pbdb"
)
println(" -> Success: Retrieved $(nrow(pliocene_mammals)) records")

println("Example: Taxonomic data (Mammalia)")
mammalia = pbdb_taxon(name = "Mammalia", vocab = "pbdb", show = ["attr", "size"])
println(" -> Success: Retrieved $(nrow(mammalia)) records")

println("Example: Taxonomic data (children of Carnivora)")
carnivores = pbdb_taxa(
    name  = "Carnivora",
    rel   = "children",
    vocab = "pbdb",
    show  = ["attr", "app"]
)
println(" -> Success: Retrieved $(nrow(carnivores)) records")

println("Example: Autocomplete taxon search (Cani)")
suggestions = pbdb_taxa_auto(name = "Cani", limit = 10)
println(" -> Success: Retrieved $(nrow(suggestions)) records")

println("Example: European collections")
european_collections = pbdb_collections(
    lngmin   = -10.0, lngmax = 40.0,
    latmin   = 35.0,  latmax = 65.0,
    interval = "Cenozoic"
)
println(" -> Success: Retrieved $(nrow(european_collections)) records")

println("Example: Clustered collections (Europe, level=2)")
clusters = pbdb_collections_geo(
    level  = 2,
    lngmin = 0.0,  lngmax = 15.0,
    latmin = 45.0, latmax = 55.0
)
println(" -> Success: Retrieved $(nrow(clusters)) records")

println("Example: Specimens (Cetacea, Miocene)")
whale_specimens = pbdb_specimens(
    base_name = "Cetacea",
    interval  = "Miocene",
    vocab     = "pbdb"
)
println(" -> Success: Retrieved $(nrow(whale_specimens)) records")

println("Example: Measurements (specimens 1505, 30050)")
measurements = pbdb_measurements(
    spec_id = [1505, 30050],
    show    = ["spec", "methods"],
    vocab   = "pbdb"
)
println(" -> Success: Retrieved $(nrow(measurements)) records")

# ----------------------------------------------------------------------
# Advanced features

println("Example: Short vs full vocab fields")
df_short = pbdb_occurrences(base_name = "Canis", limit = 5)
df_full  = pbdb_occurrences(base_name = "Canis", limit = 5, vocab = "pbdb")
println(" -> Success: Short fields $(nrow(df_short)), Full fields $(nrow(df_full))")

println("Example: Detailed occurrences (Dinosauria, Cretaceous)")
detailed_occs = pbdb_occurrences(
    base_name = "Dinosauria",
    interval  = "Cretaceous",
    show      = ["coords", "classext", "stratext", "ident", "loc"],
    vocab     = "pbdb"
)
println(" -> Success: Retrieved $(nrow(detailed_occs)) records")

println("Example: Old mammals (50–65 Ma)")
old_mammals = pbdb_occurrences(base_name = "Mammalia", min_ma = 50.0, max_ma = 65.0)
println(" -> Success: Retrieved $(nrow(old_mammals)) records")

println("Example: Miocene data (North America)")
miocene_data = pbdb_occurrences(interval = "Miocene", cc = "NAM")
println(" -> Success: Retrieved $(nrow(miocene_data)) records")

println("Example: Strata (formations, lat 30–50, long -120 to -100)")
formations = pbdb_strata(
    rank   = "formation",
    lngmin = -120, lngmax = -100,
    latmin = 30,   latmax = 50
)
println(" -> Success: Retrieved $(nrow(formations)) records")

println("Example: References for Canidae")
refs = pbdb_ref_taxa(name = "Canidae", show = ["both", "comments"], vocab = "pbdb")
println(" -> Success: Retrieved $(nrow(refs)) records")

println("Example: References for occurrences (Canis, published in 2000)")
occ_refs = pbdb_ref_occurrences(base_name = "Canis", ref_pubyr = 2000, vocab = "pbdb")
println(" -> Success: Retrieved $(nrow(occ_refs)) records")

println("Example: Reference detail (1003)")
ref_detail = pbdb_reference(1003, vocab = "pbdb", show = "both")
println(" -> Success: Retrieved $(nrow(ref_detail)) records")

# ----------------------------------------------------------------------
# Error handling
println("Example: Error handling demonstration (invalid taxon)")
try
    data = pbdb_occurrences(base_name = "InvalidTaxon", limit = 10)
    println(" -> Unexpected success: Retrieved $(nrow(data)) records")
catch e
    println(" -> Expected failure: $(e)")
end
