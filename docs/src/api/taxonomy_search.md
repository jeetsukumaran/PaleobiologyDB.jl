```@meta
CurrentModule = PaleobiologyDB.Taxonomy
```

# Taxonomy — Search

## Taxon occurrence search: taxon_occursin

`taxon_occursin` searches for taxonomic patterns across multiple columns. It comes in two forms:

- **2-arg** `taxon_occursin(pattern, df)` → `Vector{Bool}` — searches across all
  taxonomy columns; use for `df[mask, :]` filtering.
- **1-arg** `taxon_occursin(pattern)` → `ByRow` predicate — for use directly with
  `subset(df, :col => taxon_occursin(pattern))`.

By placing the pattern first, this function works naturally with piping and functional composition.

Vector inputs (`AbstractVector{<:AbstractString}` or `AbstractVector{<:Regex}`) accept
a `combine` keyword (`all` by default): `combine=all` requires **all** elements to
match (AND); `combine=any` requires **any** to match (OR).

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy: taxon_occursin

df = pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")

# 2-arg: multi-column boolean mask
df[taxon_occursin("Canis", df), :]
df[taxon_occursin(r"^Canis\b", df), :]

# 2-arg: AND — every name must appear in some column (default combine=all)
df[taxon_occursin(["Canis", "Mammalia"], df), :]

# 2-arg: OR — any name matches any column
df[taxon_occursin(["Canis", "Vulpes"], df; combine=any), :]

# 2-arg: AND patterns — each regex must match at least one column
df[taxon_occursin([r"Canidae", r"Canis"], df), :]

# 1-arg: use directly with subset
df2 = augment_taxonomy(df)
subset(df2, :taxonomy_genus => taxon_occursin("Canis"))
subset(df2, :taxonomy_clades => taxon_occursin(r"Borophaginae"))

# 1-arg: regex AND on composite column (default combine=all)
# rows where taxonomy_clades contains BOTH patterns
subset(df2, :taxonomy_clades => taxon_occursin([r"Canidae", r"lupus"]))

# 1-arg: regex OR
subset(df2, :taxonomy_clades => taxon_occursin([r"^Canis\b", r"^Vulpes\b"]; combine=any))

# 1-arg: string OR
subset(df2, :taxonomy_genus => taxon_occursin(["Canis", "Vulpes"]; combine=any))

# Chain with subset (Chain.jl)
using Chain
@chain df begin
    augment_taxonomy
    subset(:taxonomy_family   => taxon_occursin("Canidae"))
    subset(:taxonomy_clades   => taxon_occursin([r"Canis", r"lupus"]))
end
```

```@docs
taxon_occursin
```

## Taxon occurrence search: contains_taxon

`contains_taxon` provides an alternative syntax to [`taxon_occursin`](@ref) with the DataFrame
as the first argument. It comes in the same two forms:

- **2-arg** `contains_taxon(df, pattern)` → `Vector{Bool}` — searches across all
  taxonomy columns; use for `df[mask, :]` filtering.
- **1-arg** `contains_taxon(pattern)` → `ByRow` predicate — for use directly with
  `subset(df, :col => contains_taxon(pattern))`.

By placing the DataFrame first, this function is more natural for statement chaining and
method calls where data flows from left to right.

All matching semantics, column selection, and keywords are identical to `taxon_occursin`.

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy: contains_taxon

df = pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")

# 2-arg: multi-column boolean mask (DataFrame first)
df[contains_taxon(df, "Canis"), :]
df[contains_taxon(df, r"^Canis\b"), :]

# 2-arg: AND — every name must appear in some column (default combine=all)
df[contains_taxon(df, ["Canis", "Mammalia"]), :]

# 2-arg: OR — any name matches any column
df[contains_taxon(df, ["Canis", "Vulpes"]; combine=any), :]

# 2-arg: AND patterns — each regex must match at least one column
df[contains_taxon(df, [r"Canidae", r"Canis"]), :]

# 1-arg: use directly with subset
df2 = augment_taxonomy(df)
subset(df2, :taxonomy_genus => contains_taxon("Canis"))
subset(df2, :taxonomy_clades => contains_taxon(r"Borophaginae"))

# 1-arg: regex AND on composite column (default combine=all)
# rows where taxonomy_clades contains BOTH patterns
subset(df2, :taxonomy_clades => contains_taxon([r"Canidae", r"lupus"]))

# 1-arg: regex OR
subset(df2, :taxonomy_clades => contains_taxon([r"^Canis\b", r"^Vulpes\b"]; combine=any))

# 1-arg: string OR
subset(df2, :taxonomy_genus => contains_taxon(["Canis", "Vulpes"]; combine=any))

# Chain with subset (Chain.jl)
using Chain
@chain df begin
    augment_taxonomy
    subset(:taxonomy_family   => contains_taxon("Canidae"))
    subset(:taxonomy_clades   => contains_taxon([r"Canidae", r"lupus"]))
end
```

```@docs
contains_taxon
```

## Choosing between taxon_occursin and contains_taxon

Both `taxon_occursin` and `contains_taxon` are functionally identical and support all the same
patterns, keywords, and use cases. The choice is purely stylistic:

| Preference | Function | Usage |
|-----------|----------|--------|
| Pattern-first (functional style) | `taxon_occursin` | `df[taxon_occursin("Canis", df), :]` |
| DataFrame-first (method chaining style) | `contains_taxon` | `df[contains_taxon(df, "Canis"), :]` |

Use whichever feels more natural for your workflow. Both are equally idiomatic and supported.
