# PhyloPicMakie — API Reference

`PaleobiologyDB.PhyloPicMakie` is an optional package extension that overlays
[PhyloPic](https://www.phylopic.org/) silhouette images on existing Makie axes.
It activates automatically when both a Makie backend (e.g. `CairoMakie`) and
`FileIO` are loaded.

See the [PhyloPicMakie guide](../guide/phylopic_makie.md) for installation
instructions, worked examples, and a keyword-argument reference.

## Point placement

```@docs
PaleobiologyDB.PhyloPicMakie.augment_phylopic!
PaleobiologyDB.PhyloPicMakie.augment_phylopic
```

## Range placement

```@docs
PaleobiologyDB.PhyloPicMakie.augment_phylopic_ranges!
PaleobiologyDB.PhyloPicMakie.augment_phylopic_ranges
```

## Thumbnail grids

```@docs
PaleobiologyDB.PhyloPicMakie.phylopic_thumbnail_grid!
PaleobiologyDB.PhyloPicMakie.phylopic_thumbnail_grid
```
