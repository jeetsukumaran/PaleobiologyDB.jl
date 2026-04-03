# Other

## Time intervals and scales

```@docs
pbdb_interval
pbdb_intervals
pbdb_scale
pbdb_scales
```

## Stratigraphy

```@docs
pbdb_strata
pbdb_strata_auto
```

## References

The reference functions retrieve bibliographic data associated with taxa,
occurrences, or collections, and can fetch a specific reference record directly.

```julia
# References for a taxon group
refs = pbdb_ref_taxa(name = "Canidae", show = ["both", "comments"])

# References cited in occurrence records
occ_refs = pbdb_ref_occurrences(base_name = "Canis", ref_pubyr = 2000)

# A specific reference record
ref_detail = pbdb_reference(1003, show = "both")
```

```@docs
pbdb_reference
pbdb_references
```

## Opinions

```@docs
pbdb_opinion
pbdb_opinions
```

## Counting

```@docs
pbdb_count
```
