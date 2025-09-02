# # Objective
#
# Plot species temporal spans
# vs spatial spans (e.g. latitudinal
# or longitudinal ranges) to see
# if there is a positive correlation between
# them.

# This brings in a suite of useful functions
# serving as "commands" in the REPL to work
# with `DataFrame`'s, the fundamental
# organization unit of data in our
# ecosystem, statistics, and
# visualizations.
using DataFrames
using Statistics

# This brings in a suite of functions
# to work with the Paleobiology Database
# (PBDB) data service.
using PaleobiologyDB

# We can get a sense of the "endpoints" of
# the data service, by listing the functions
# provided by the PaleobiologyDB package.
# The PaleobiologyDB package is models the
# API of the PBDB exactly.
names(PaleobiologyDB) # truncated view
foreach(println, names(PaleobiologyDB))

# The "`pbdb_occurrences` seems like what we want.
#
# The PaleobiologDB library interface is richly
# documented at several levels, including at the
# source code level, which makes self-learning
# discovery very much easier.
#
# You can type `?pbdb_occurrences` at the REPL
# to read the help for the function, or you can
# also read the function docstring that forms
# the help for the PaleobiologyDB module function
# directly by:
@doc pbdb_occurrences

# ::: {.callout-tip title = "PBDB data service API help'}
#
# MUCH more thorough documentation of the
# upstream endpoints (parameters and response
# fields are also available,
#
# ```
# julia> using PaleobiologyDB.ApiHelp
# julia> names(ApiHelp)
# ```
#
# There's even help on using this help!
#
# ```
# julia> ?ApiHelp
# julia> ?pbdb_help()
# julia> ?pbdb_endpoints()
# julia> ?pbdb_parameters()
# julia> ?pbdb_fields()
# julia> ?pbdb_search()
# ```
#
# To review the parameters for querying
# the "occurrences" endpoint, for example,
# you can:
#
# ```
# julia> pbdb_parameters("occurrences")
# SELECTION PARAMETERS:
#   all_records
#     Select all occurrences entered in the database
#   occ_id
#     Comma-separated list of occurrence identifiers
#   coll_id
#     Comma-separated list of collection identifiers
#   base_name
#     Taxonomic name(s), including all subtaxa and synonyms
#   taxon_name
# .
# .
# .
# ```
# julia> pbdb_fields("occurrences")
# BASIC FIELDS:
#   occurrence_no (oid)
#     Unique occurrence identifier
#   collection_no (cid)
#     Associated collection identifier
#   identified_name (idn)
#     Taxonomic name as identified
#   accepted_name (tna)
#     Accepted taxonomic name
#   accepted_rank (rnk)
#     Taxonomic rank
#   early_interval (oei)
#     Early geologic time interval
#   late_interval (oli)
#     Late geologic time interval
#   max_ma (eag)
#     Early age bound (Ma)
#   min_ma (lag)
#     Late age bound (Ma)
#
# COORDS FIELDS:
#   lng (lng)
#     Longitude (degrees)
#   lat (lat)
#     Latitude (degrees)
#
# CLASS FIELDS:
#   phylum (phl)
#     Phylum name
#   class (cll)
#     Class name
#   order (odl)
#     Order name
#   family (fml)
#     Family name
#   genus (gnl)
#     Genus name
#
#```
#
# :::

# Having reviewed the database query parameter
# and response field, let us begin to explore
# the data.

# Get all carnivore occurrence data
# using the PaleobiologDB function
# `pbdb_occurences`.
occs = pbdb_occurrences(
    ; # the ';' indicated end of positional arguments
    base_name = "Carnivora",
    show = "full",
    vocab = "pbdb",
    extids = true,
    # limit = 1000,
)

# Get a sense of the data
nrow(occs) # number of rows
names(occs) # truncated column list
foreach(println,
    names(occs)) # full column list

# See availability of occurrences
# registered at each taxonomic
# rank
combine(groupby(occs, :accepted_rank), nrow)

# ## Data quality
# Auditing the data involves more than
# ensuring it is present (thought that's
# a start), it also means making sure the
# data that is present meets our standards.
# And for that, we need to decide our
# standards.
#
# We need to decide the threshold of data
# quality that we will accept.
#
# The three classes of data values we need
# are (a) the identity of the lineage,
# (b) the timing of the occurrence,
# and (c) spatial location.
#
# We shall set a definitive species
# identity as our minimum data standard
# for taxonomic resolution to start with,
# and a `accepted_rank` field with a value
# of "species" or subspecies will be considered
# good enough to meet this, again, to start
# with.

# Let's create a function that implements
# this now, to make it easy to change later.
clean_taxonomy_flt = row -> row.accepted_rank == "species" || row.accepted_rank == "subspecies"

# Quick review of column/row selection:
#
# - `subset()` and `filter()` for choosing *rows*.
# - `select()` for choosing *columns*.
# - `[.. , ..]` index notation for rows choosing or columns or both by
#    numerical or boolean *indexes*.

# Different ways of saying:
# "give me all the rows that have
# `accepted_rank == focal_rank`
#
# ```julia
# occs_accepted_rank = occs[occs.accepted_rank .== focal_rank, :]
# occs_accepted_rank = filter(r -> r.accepted_rank == focal_rank, occs)
# occs_accepted_rank = subset(occs, :accepted_rank => rank_rows -> rank_rows .== focal_rank)
# occs_accepted_rank = subset(occs, :accepted_rank => ByRow(r -> r == focal_rank))
# occs_accepted_rank = subset(occs, :accepted_rank => ByRow((== focal_rank))
# occs_accepted_rank = subset(occs, :accepted_rank => ByRow(r -> r == focal_rank))
# occs_accepted_rank = subset(occs, :accepted_rank => rows -> rows .== focal_rank)
# occs_accepted_rank = occs |> df -> subset(df, :accepted_rank => rows -> rows .== focal_rank)
# ```

# occs_accepted_rank = occs[occs.accepted_rank .== focal_rank, :]
occs_accepted_rank = filter(clean_taxonomy_flt, occs)

# Knowing what we know now, we might just query for this
# resolution direction from the very beginning
occs_accepted_rank = pbdb_occurrences(
    ; # the ';' indicated end of positional arguments
    base_name = "Carnivora",
    show = "full",
    vocab = "pbdb",
    extids = true,
    idreso = "species",
)



# Have a look at the first row
occs[1, :]
# Sometimes, a vertical layout is nice
foreach(println, pairs(occs[1, :]))

# Next, we have to decide our standards for
# the chronological information.
#
# There are lots of different date values
# associated with a fossil occurrence, and
# selection of these might have different impact
# on the structure of both the data as well as
# errors we might be dealing.

# Let us start with seeing the types of
# chronological information available.
# As all the PBDB columns with dates have a
# "_ma" in their names, we can use a
# regular expression based column selector
# to view them.
occs_accepted_rank[:, r".*_ma.*"]

# There is a *lot* of missing data!
#
# We are looking at trade-offs here in multiple
# dimensions: precision, accuracy,
# data coverage, etc.

# We could accept dates based on the geological
# layer in which they are found, which means
# we have to deal with the imprecision of
# ranges of values, on top of any inherent
# measurement uncertainty.

# We could accept dates based on more precise
# methods, but then, in addition to losing
# a lot of data due to greater effort, difficulty,
# challenges, etc. of this type measurement, we
# might be dealing with a much larger errors of
# measurement impacting accuracy, even as we are
# increasing the precision.

# In all cases, increasing the data quality
# threshold reduces the amount of data available,
# which leads to weaker inference, which itself
# may be a problem, and, depending on method, maybe
# a *worse* problem.
#
# For parametric approaches, e.g. probabilistic
# modeling, my *PERSONAL* preference is to have
# higher quality data even if that means less data.
# The methods I prefer to use, e.g Bayesian approaches,
# are more easily misled by data that violates the
# models than less data (up to a point, either way).
#
# On the other hand, for non-parameteric, machine
# learning, simulations based, fuzzy matching,
# correlative methods---they can handle a lot
# of wonky data and noise and measurement error
# a lot better due to the inherent nature of the
# "squinting at the world through vaseline-smeared
# sunglasses" perspective they take of the world.

# Here we opt for having a
# valid direct age `:direct_ma_value`,
# alomg with minumum and maximum
# of quantification of the precision of range of the
# estimate, `:min_ma` and `:max_ma``, is a
# standard to start with.

occs_with_ages = dropmissing(occs_accepted_rank, [
    :direct_ma_value,
    # :direct_ma_error,
    :max_ma,
    # :max_ma_error,
    :min_ma,
    # :min_ma_error,
])

# We *could* also demand that we have errors
# on each of these values, `direct_ma_error`,
# `min_ma_error`, and `max_ma_error`, but this might
# leave us with not enough data for some unrealistic
# idealized version of data quality.

nrow(dropmissing(occs_accepted_rank, r".*direct_ma.*"))
#269

nrow(dropmissing(occs_accepted_rank, r".*max_ma.*"))
#198

nrow(dropmissing(occs_accepted_rank, r".*min_ma.*"))
#200

nrow(dropmissing(occs_accepted_rank, r".*_ma.*"))
#0

nrow(dropmissing(occs_accepted_rank, r".*direct_ma_error*"))
#272

nrow(dropmissing(occs_accepted_rank, r".*max_ma_error*"))
#199

nrow(dropmissing(occs_accepted_rank, r".*min_ma_error*"))
#201

nrow(dropmissing(occs_accepted_rank, r".*ma_error*"))
#0

# Again, knowing what we know now, we can query for this
# directly:
# occs_accepted_rank = pbdb_occurrences(
#     ; # the ';' indicated end of positional arguments
#     base_name = "Carnivora",
#     show = "full",
#     vocab = "pbdb",
#     extids = true,
#     idreso = "species",
#     hasage = "direct",
# )

# Let's have a look at how much taxonomic variation
# is remaining that meets our taxonomic and chronological
# data standards.

# number of species
nrow(combine(groupby(occs_with_ages, :accepted_name), nrow))
#171

# number of genera
nrow(combine(groupby(occs_with_ages, :genus), nrow))
#110

# number of families
nrow(combine(groupby(occs_with_ages, :family), nrow))
#16

# Now for spatial data standards.
nrow(dropmissing(occs_with_ages, [:lng, :lat]))
#411
nrow(dropmissing(occs_with_ages, [:paleolng, :paleolat]))
#127
nrow(dropmissing(occs_with_ages, [:lng, :lat, :paleolng, :paleolat]))
#127

# We will go with the strictest again, and again
# the take hit in data
occs_with_ages_and_locs = dropmissing(occs_with_ages, [:lng, :lat, :paleolng, :paleolat])
nrow(combine(groupby(occs_with_ages_and_locs, :accepted_name), nrow))
#112
nrow(combine(groupby(occs_with_ages_and_locs, :genus), nrow))
#84
nrow(combine(groupby(occs_with_ages_and_locs, :family), nrow))
#15


# Compute chronological and spatial spans per accepted_nane
#
# When I was *first* exploring the data, this is what I did at the REPL:
#
# ```
# occs_grouped = groupby(occs_with_ages_and_locs, :accepted_name)
# occs_ages = combine(occs_grouped,
#                     :direct_ma_value .=> [length, maximum, minimum, mean])
# occs_time_span = occs_ages.direct_ma_value_maximum - occs_ages.direct_ma_value_minimum
# occs_lats = combine(occs_grouped,
#                     :paleolat .=> [length, maximum, minimum, mean])
# occs_lat_spans = occs_lats.paleolat_maximum - occs_lats.paleolat_minimum
# occs_lngs = combine(occs_grouped,
#                     :paleolng .=> [length, maximum, minimum, mean])
# occs_lng_spans = occs_lngs.paleolng_maximum - occs_lngs.paleolng_minimum
#
# ```
#
# After figuring out how I wanted to organize the information,
# I packaged it up in this way (not so easy to type in the REPL,
# but much cleaner and easier to maintain/change).

# spans = combine(groupby(occs_with_ages_and_locs, :accepted_name),
#     :direct_ma_value => (x -> maximum(skipmissing(x)) - minimum(skipmissing(x))) => :time_span,
#     :paleolat        => (x -> maximum(skipmissing(x)) - minimum(skipmissing(x))) => :lat_span,
#     :paleolng        => (x -> maximum(skipmissing(x)) - minimum(skipmissing(x))) => :lng_span,
# )
span_fn = vals -> maximum(vals) - minimum(vals)
spans = combine(groupby(occs_with_ages_and_locs, :accepted_name),
    [:direct_ma_value, :paleolat, :paleolng] .=> span_fn .=> [:time_span, :lat_span, :lng_span]
)
rename!(spans, :accepted_name => :taxon)
# drop any rows with a 0 in any span
spans_nz = filter(r -> (r.time_span != 0) &&
                    (r.lat_span != 0) &&
                    (r.lng_span != 0), spans)
spans_nz
sort!(spans_nz, :lat_span, :lng_span, :time_span)

# This is nowhere near a complete analysis, let alone a valid one.
# But as a pilot data discovery session, it has served its purpose, allowing us to understand
# the data model, availability, quality and qualityt/scope trade-offs, as well as the
# feasibility of the analysis and the type of functions, logic, transformations etc.
# required for a general "pipeline" for this study.