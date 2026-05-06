```@meta
CurrentModule = PaleobiologyDB.PBDBMakie
```

# PhyloPic: Rendering — API Reference

`PaleobiologyDB.PBDBMakie` overlays
[PhyloPic](https://www.phylopic.org/) silhouette images on existing Makie axes.
It is a package extension that activates when both a Makie backend (e.g. `CairoMakie`)
and `PhyloPicMakie` are loaded.

For taxon-name resolution and image acquisition, see the
[`acquire_phylopic`](phylopic_acquire.md) API.

See the [PhyloPicMakie guide](../guide/phylopic_makie.md) for installation
instructions, worked examples, and a keyword-argument reference.

The vendored `PhyloPic` submodule is an internal implementation detail of
`PBDBMakieExt`. It provides the PBDB-to-PhyloPic name-resolution pipeline and
the Makie rendering wrappers used by the exported
`PaleobiologyDB.PBDBMakie` functions documented below, but it is not itself a
supported public binding on `PaleobiologyDB.PBDBMakie`.

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
