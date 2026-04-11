# TaxonTreeMakie — API Reference

`PaleobiologyDB.TaxonTreeMakie` is an optional package extension that renders
[`TaxonTree`](@ref) objects as Makie dendrograms.  It activates automatically
when any Makie backend (e.g. `CairoMakie`) is loaded.

See the [TaxonTreeMakie guide](../guide/taxontree_makie.md) for installation
instructions, worked examples, and a full attribute reference.

## Plot type

```@docs
PaleobiologyDB.TaxonTreeMakie.TaxonTreePlot
```

## Standalone figure

```@docs
PaleobiologyDB.TaxonTreeMakie.taxontreeplot
```

## Existing axis

```@docs
PaleobiologyDB.TaxonTreeMakie.taxontreeplot!
```

## Axis helpers

```@docs
PaleobiologyDB.TaxonTreeMakie.set_rank_axis_ticks!
```
