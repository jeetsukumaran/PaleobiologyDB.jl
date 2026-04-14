# PhyloPicMakie — API Reference

`PaleobiologyDB.PhyloPicPBDB` overlays
[PhyloPic](https://www.phylopic.org/) silhouette images on existing Makie axes.
`PhyloPicMakie` (and `FileIO` for image decoding) are hard dependencies of
`PaleobiologyDB`, so no extension activation step is needed — just load a Makie
backend.

See the [PhyloPicMakie guide](../guide/phylopic_makie.md) for installation
instructions, worked examples, and a keyword-argument reference.

## Point placement

```@docs
PaleobiologyDB.PhyloPicPBDB.augment_phylopic!
PaleobiologyDB.PhyloPicPBDB.augment_phylopic
```

## Range placement

```@docs
PaleobiologyDB.PhyloPicPBDB.augment_phylopic_ranges!
PaleobiologyDB.PhyloPicPBDB.augment_phylopic_ranges
```

## Thumbnail grids

```@docs
PaleobiologyDB.PhyloPicPBDB.phylopic_thumbnail_grid!
PaleobiologyDB.PhyloPicPBDB.phylopic_thumbnail_grid
```
