```@meta
CurrentModule = PaleobiologyDB.TaxonomyMakie
```

# PhyloPic: Rendering — API Reference

`PaleobiologyDB.TaxonomyMakie` overlays
[PhyloPic](https://www.phylopic.org/) silhouette images on existing Makie axes.
It is a package extension that activates when both a Makie backend (e.g. `CairoMakie`)
and `PhyloPicMakie` are loaded.

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
phylopic_thumbnail_grid!
phylopic_thumbnail_grid
```
