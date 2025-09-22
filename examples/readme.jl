# PaleobiologyDB.jl — Collected examples from README with labels and success notices
# ======================================================================
using DataFrames
using PaleobiologyDB

# ----------------------------------------------------------------------
@info "Example: Get fossil occurrences (Canidae, Miocene)"
canids = pbdb_occurrences(
    base_name = "Canidae",
    interval  = "Miocene",
    show      = ["coords", "class"],
    vocab     = "pbdb",
    limit     = 100
)
@info " -> Success: Retrieved $(nrow(canids)) records"

@info "Example: Get taxonomic information (Canis)"
canis_info = pbdb_taxon(
    name  = "Canis",
    vocab = "pbdb",
    show  = ["attr", "app", "size"]
)
@info " -> Success: Retrieved $(nrow(canis_info)) records"

@info "Example: Get a specific collection (1003)"
collection = pbdb_collection(
    1003,
    show  = ["loc", "stratext"],
    vocab = "pbdb"
)
@info " -> Success: Retrieved $(nrow(collection)) records"

# ----------------------------------------------------------------------
# Basic usage

@info "Example: Simple occurrence query (Mammalia, limit=10)"
occs = pbdb_occurrences(base_name = "Mammalia", limit = 10)
@info " -> Success: Retrieved $(nrow(occs)) records"

@info "Example: Specific occurrence (1001)"
single_occ = pbdb_occurrence(1001, vocab = "pbdb", show = ["coords", "class"])
@info " -> Success: Retrieved $(nrow(single_occ)) records"

@info "Example: Geographic and temporal filtering (Pliocene mammals, N. America)"
pliocene_mammals = pbdb_occurrences(
    base_name = "Mammalia",
    interval  = "Pliocene",
    lngmin    = -130.0, lngmax = -60.0,
    latmin    = 25.0,   latmax = 70.0,
    show      = ["coords", "classext", "stratext"],
    vocab     = "pbdb"
)
@info " -> Success: Retrieved $(nrow(pliocene_mammals)) records"

@info "Example: Taxonomic data (Mammalia)"
mammalia = pbdb_taxon(name = "Mammalia", vocab = "pbdb", show = ["attr", "size"])
@info " -> Success: Retrieved $(nrow(mammalia)) records"

@info "Example: Taxonomic data (children of Carnivora)"
carnivores = pbdb_taxa(
    name  = "Carnivora",
    rel   = "children",
    vocab = "pbdb",
    show  = ["attr", "app"]
)
@info " -> Success: Retrieved $(nrow(carnivores)) records"

@info "Example: Autocomplete taxon search (Cani)"
suggestions = pbdb_taxa_auto(name = "Cani", limit = 10)
@info " -> Success: Retrieved $(nrow(suggestions)) records"

@info "Example: European collections"
european_collections = pbdb_collections(
    lngmin   = -10.0, lngmax = 40.0,
    latmin   = 35.0,  latmax = 65.0,
    interval = "Cenozoic"
)
@info " -> Success: Retrieved $(nrow(european_collections)) records"

@info "Example: Clustered collections (Europe, level=2)"
clusters = pbdb_collections_geo(
    level  = 2,
    lngmin = 0.0,  lngmax = 15.0,
    latmin = 45.0, latmax = 55.0
)
@info " -> Success: Retrieved $(nrow(clusters)) records"

@info "Example: Specimens (Cetacea, Miocene)"
whale_specimens = pbdb_specimens(
    base_name = "Cetacea",
    interval  = "Miocene",
    vocab     = "pbdb"
)
@info " -> Success: Retrieved $(nrow(whale_specimens)) records"

@info "Example: Measurements (specimens 1505, 30050)"
measurements = pbdb_measurements(
    spec_id = [1505, 30050],
    show    = ["spec", "methods"],
    vocab   = "pbdb"
)
@info " -> Success: Retrieved $(nrow(measurements)) records"

# ----------------------------------------------------------------------
# Advanced features

@info "Example: Short vs full vocab fields"
df_short = pbdb_occurrences(base_name = "Canis", limit = 5)
df_full  = pbdb_occurrences(base_name = "Canis", limit = 5, vocab = "pbdb")
@info " -> Success: Short fields $(nrow(df_short)), Full fields $(nrow(df_full))"

@info "Example: Detailed occurrences (Dinosauria, Cretaceous)"
detailed_occs = pbdb_occurrences(
    base_name = "Dinosauria",
    interval  = "Cretaceous",
    show      = ["coords", "classext", "stratext", "ident", "loc"],
    vocab     = "pbdb"
)
@info " -> Success: Retrieved $(nrow(detailed_occs)) records"

@info "Example: Old mammals (50–65 Ma)"
old_mammals = pbdb_occurrences(base_name = "Mammalia", min_ma = 50.0, max_ma = 65.0)
@info " -> Success: Retrieved $(nrow(old_mammals)) records"

@info "Example: Miocene data (North America)"
miocene_data = pbdb_occurrences(interval = "Miocene", cc = "NAM")
@info " -> Success: Retrieved $(nrow(miocene_data)) records"

@info "Example: Strata (formations, lat 30–50, long -120 to -100)"
formations = pbdb_strata(
    rank   = "formation",
    lngmin = -120, lngmax = -100,
    latmin = 30,   latmax = 50
)
@info " -> Success: Retrieved $(nrow(formations)) records"

@info "Example: References for Canidae"
refs = pbdb_ref_taxa(name = "Canidae", show = ["both", "comments"], vocab = "pbdb")
@info " -> Success: Retrieved $(nrow(refs)) records"

@info "Example: References for occurrences (Canis, published in 2000)"
occ_refs = pbdb_ref_occurrences(base_name = "Canis", ref_pubyr = 2000, vocab = "pbdb")
@info " -> Success: Retrieved $(nrow(occ_refs)) records"

@info "Example: Reference detail (1003)"
ref_detail = pbdb_reference(1003, vocab = "pbdb", show = "both")
@info " -> Success: Retrieved $(nrow(ref_detail)) records"

# ----------------------------------------------------------------------
# Error handling
@info "Example: Error handling demonstration (invalid taxon)"
try
    data = pbdb_occurrences(base_name = "InvalidTaxon", limit = 10)
    @info " -> Unexpected success: Retrieved $(nrow(data)) records"
catch e
    @info " -> Expected failure: $(e)"
end
