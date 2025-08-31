
# This brings in a suite of useful functions
# serving as "commands" in the REPL to work
# with `DataFrame`'s, the fundamental
# organization unit of data in our
# ecosystem.
using DataFrames

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

# `pbdb_occurrences` seems like what we want.
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

# > help?> pbdb_occurrences
# > search: pbdb_occurrences pbdb_occurrence pbdb_ref_occurrences pbdb_references pbdb_reference collection_occurrences pbdb_measurements pbdb_specimens pbdb_scales pbdb_opinions
# >
# >   pbdb_occurrences(; kwargs...)
# >
# >   Get information about fossil occurrence records stored in the Paleobiology Database.
# >
# >   Arguments
# >   ≡≡≡≡≡≡≡≡≡
# >
# >     •  kwargs...: Filtering and output parameters. Common options include:
# >        • limit: Maximum number of records to return (Int or "all").
# >        • taxon_name: Return only records with the specified taxonomic name(s).
# >        • base_name: Return records for the specified name(s) and all descendant taxa.
# >        • lngmin, lngmax, latmin, latmax: Geographic bounding box.
# >        • min_ma, max_ma: Minimum and maximum age in millions of years.
# >        • interval: Named geologic interval (e.g. "Miocene").
# >        • cc: Country/continent codes (ISO two-letter or three-letter).
# >        • show: Extra information blocks ("coords", "classext", "ident", etc.).
# >        • vocab: Vocabulary for field names ("pbdb" for full names, "com" for short codes).
# >
# >   Returns
# >   ≡≡≡≡≡≡≡
# >
# >   A DataFrame with fossil occurrence records matching the query.
# >
# >   Examples
# >   ≡≡≡≡≡≡≡≡
# >
# >  # `taxon_name` retrieves *only* units of this rank
# >  occs = pbdb_occurrences(;
# >      taxon_name="Canis",
# >      show="full", # all columns
# >      limit=100,
# >  )
# >
# >  # `base_name` retrieves units of this and nested rank
# >  occs = pbdb_occurrences(;
# >      base_name="Canis",
# >      show=["coords","classext"],
# >      limit=100,
# >  )


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

# > 13×2 DataFrame
# >  Row │ accepted_rank   nrow
# >      │ String15        Int64
# > ─────┼───────────────────────
# >    1 │ species          8350
# >    2 │ genus            2922
# >    3 │ subfamily         337
# >    4 │ family           1020
# >    5 │ order             188
# >    6 │ suborder            8
# >    7 │ infraorder          1
# >    8 │ tribe              24
# >    9 │ superfamily        14
# >   10 │ subspecies        100
# >   11 │ subgenus            5
# >   12 │ unranked clade     36
# >   13 │ subtribe


# ## Data quality
#
# We need to decide the threshold of data
# quality that we will accept.
#
# The three classes of data values we need
# are (a) the identity of the lineage,
# (b) the timing of the occurrence,
# and (c) spatial location.
#
# Auditing the data involves more than
# ensuring it is present (thought that's
# a start), it also means making sure the
# data that is present meets our standards.
# And for that, we need to decide our
# standards.
#
# We shall set a definitive species
# identity as our minimum data standard
# for taxonomic resolution to start with,
# and a `accepted_rank` field with a value
# of (exactly) "species" will be considered
# good enough to meet this, again, to start
# with.

# Let's create a function that implements
# this now, to make it easy to change later.
clean_taxonomy_flt = row -> row.accepted_rank == "species"

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
# occs_accepted_rank = occs[occs.accepted_rank .== focal_rank, :]
# occs_accepted_rank = filter(r -> r.accepted_rank == focal_rank, occs)
# occs_accepted_rank = subset(occs, :accepted_rank => rank_rows -> rank_rows .== focal_rank)
# occs_accepted_rank = subset(occs, :accepted_rank => ByRow(r -> r == focal_rank))
# occs_accepted_rank = subset(occs, :accepted_rank => ByRow((== focal_rank))
# occs_accepted_rank = subset(occs, :accepted_rank => ByRow(r -> r == focal_rank))
# occs_accepted_rank = subset(occs, :accepted_rank => rows -> rows .== focal_rank)
# occs_accepted_rank = occs |> df -> subset(df, :accepted_rank => rows -> rows .== focal_rank)
#
# occs_accepted_rank = occs[occs.accepted_rank .== focal_rank, :]
occs_accepted_rank = filter(clean_taxonomy_flt, occs)

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
#
# We could accept dates based on the geological
# layer in which they are found, which means
# we have to deal with the imprecision of
# ranges of values, on top of any inherent
# measurement uncertainty.
#
# We could accept dates based on more precise
# methods, but then, in addition to losing
# a lot of data due to greater effort, difficulty,
# challenges, etc. of this type measurement, we
# might be dealing with a much larger errors of
# measurement impacting accuracy, even as we are
# increasing the precision.

# Here we opt for the latter to start with,
# and decide that our standards are having a
# valid direct age `:direct_ma_value`,
# alomg with minumum and maximum
# of quantification of the error range of the
# estimate, as well as `:min_ma` and `:max_ma``.
#
occs_with_ages = dropmissing(occs_accepted_rank, [
    :direct_ma_value,
    :direct_ma_error,
    :max_ma,
    :max_ma_error,
    :min_ma,
    :min_ma_error,
])




# ## Putting it altogether
#
# This is a pipeline or chaining syntax.
# The is one of the ways Julia provides for
# constructing stacks of functions applied
# one after the other.
#
# In chaining, the flow is from left to
# right, that is the functions are applied in
# left to right order as they appear in
# the code (as opposed to left to right
# as in function composition), so it makes
# it easy to build up computations as
# we step through the process in our head.
#
# We use the pipe operator and so sometimes
# we say we are pipelining instead of
# chaining.
#
#
# occs_accepted_rank = occs |>
#     df -> subset(df, :accepted_rank => rows -> rows .== "species")

# In contrast to function composition, another
# approach where the order of function
# application is from "inside-out", which
# follows classical mathematical convention.

