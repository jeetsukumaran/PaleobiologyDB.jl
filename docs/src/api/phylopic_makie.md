```@meta
CurrentModule = PaleobiologyDB.PhyloPicPBDB
```

# PhyloPic: Rendering — API Reference

`PaleobiologyDB.PhyloPicPBDB` overlays
[PhyloPic](https://www.phylopic.org/) silhouette images on existing Makie axes.
`PhyloPicMakie` (and `FileIO` for image decoding) are hard dependencies of
`PaleobiologyDB`, so no extension activation step is needed — just load a Makie
backend.

For taxon-name resolution and image acquisition, see the
[`acquire_phylopic`](phylopic_acquire.md) API.

See the [PhyloPicMakie guide](../guide/phylopic_makie.md) for installation
instructions, worked examples, and a keyword-argument reference.

```@docs
PhyloPicPBDB
```

## Point placement

```@docs
augment_phylopic!
augment_phylopic
```

## Range placement

```@docs
augment_phylopic_ranges!
augment_phylopic_ranges
```

## Thumbnail grids

```@docs
pbdb_phylopic_grid!
pbdb_phylopic_grid
```
