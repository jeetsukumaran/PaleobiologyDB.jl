# PhyloPicMakie — Makie plot integration

`PaleobiologyDB.PhyloPic` provides PhyloPic silhouette overlays
for existing Makie plots.  It is a top-level submodule of `PaleobiologyDB` —
`PhyloPicMakie` (and `FileIO` for image decoding) are hard dependencies of
`PaleobiologyDB`, so no extension activation is needed.

## Installation

```
pkg> add PaleobiologyDB CairoMakie
```

## Activation

```julia
using PaleobiologyDB
using CairoMakie   # or GLMakie, WGLMakie, …
using PaleobiologyDB.PhyloPic
# → augment_phylopic!, augment_phylopic_ranges!, pbdb_phylopic_grid!, etc.
# are now in scope
```

## Stratigraphic range chart — quick start

```julia
using PaleobiologyDB
using CairoMakie
using PaleobiologyDB.PhyloPic

taxa      = ["Tyrannosaurus", "Triceratops", "Ankylosaurus",
             "Pachycephalosaurus", "Edmontosaurus"]
first_app = [68.0, 68.0, 70.0, 74.0, 76.0]
last_app  = [66.0, 66.0, 66.0, 66.0, 66.0]

fig = Figure(size = (800, 420))
ax  = Axis(
    fig[1, 1];
    xlabel         = "Age (Ma)",
    title          = "Latest Cretaceous taxa — stratigraphic ranges",
    xreversed      = true,
    yticks         = (1:length(taxa), taxa),
    yticklabelsize = 13,
)

for (i, (fa, la)) in enumerate(zip(first_app, last_app))
    lines!(ax, [fa, la], [i, i]; linewidth = 6, color = :gray30)
end

augment_phylopic_ranges!(
    ax,
    first_app,
    last_app,
    collect(1.0:length(taxa));
    taxon      = taxa,
    at         = :start,
    glyph_size = 0.38,
    placement  = :center,
)

xlims!(ax, 78, 64)
display(fig)
```

## Table-oriented API

When data is in a DataFrame (or any `propertynames`-compatible structure) the
table overloads accept column selectors directly:

```julia
using PaleobiologyDB
using CairoMakie
using PaleobiologyDB.PhyloPic
using DataFrames

df = pbdb_occurrences(base_name = "Ursidae"; show = "full", vocab = "pbdb")
df = dropmissing(df, [:genus, :max_ma, :min_ma])
df.midpoint_age = (df.max_ma .+ df.min_ma) ./ 2

appearance_df = combine(
    groupby(df, :genus; sort = true),
    :midpoint_age => maximum => :first_app,
    :midpoint_age => minimum => :last_app,
)
appearance_df = sort(appearance_df, :first_app; rev = true)
appearance_df.row = collect(1.0:nrow(appearance_df))

fig = Figure()
ax  = Axis(
    fig[1, 1];
    xlabel = "Midpoint age (Ma)",
    ylabel = "Genus",
    yticks = (1:nrow(appearance_df), appearance_df.genus),
    xreversed = true,
)

for r in eachrow(appearance_df)
    lines!(ax, [r.first_app, r.last_app], [r.row, r.row])
end

augment_phylopic_ranges!(
    ax, appearance_df;
    xstart    = :first_app,
    xstop     = :last_app,
    y         = :row,
    taxon     = :genus,
    at        = :start,
    glyph_size = 0.4,
)
display(fig)
```

## Supplying a pre-loaded glyph

Pass `glyph` instead of `taxon` to bypass the taxon-lookup pipeline and use
an image you have already loaded:

```julia
using PaleobiologyDB
using CairoMakie
using PaleobiologyDB.PhyloPic
import PhyloPicMakie

rec = acquire_phylopic("Canis lupus")
img = PhyloPicMakie._load_phylopic_image(rec.phylopic_thumbnail)

fig = Figure()
ax  = Axis(fig[1, 1])
scatter!(ax, [1.0, 2.0, 3.0], [1.0, 2.0, 3.0])

# Overlay the same silhouette at every point
augment_phylopic!(ax, [1.0, 2.0, 3.0], [1.0, 2.0, 3.0];
    glyph = img, glyph_size = 0.3)
display(fig)
```

## Image caching

Downloaded thumbnail images are automatically cached via the same
`DataCaches.jl` infrastructure used by the rest of PaleobiologyDB.  Each
unique thumbnail URL is downloaded at most once per cache lifetime; subsequent
calls for the same URL return the stored matrix without any network activity.

The cache is controlled via `PaleobiologyDB.set_autocaching!`:

```julia
import PhyloPicMakie

# Enable caching for image downloads (default)
PaleobiologyDB.set_autocaching!(true, PhyloPicMakie._load_phylopic_image)

# Disable caching
PaleobiologyDB.set_autocaching!(false, PhyloPicMakie._load_phylopic_image)
```

This is independent of the taxon-metadata cache (controlled via
`set_autocaching!(enable, acquire_phylopic)`).

## Placement and sizing

All `augment_phylopic!` functions accept the following layout keywords:

| Keyword | Default | Description |
|---|---|---|
| `placement` | `:center` | Anchor corner/edge on the glyph: `:center`, `:left`, `:right`, `:top`, `:bottom`, `:topleft`, `:topright`, `:bottomleft`, `:bottomright` |
| `xoffset` | `0.0` | Additional x offset in data units after anchoring |
| `yoffset` | `0.0` | Additional y offset in data units after anchoring |
| `glyph_size` | `0.4` | Half-height of the rendered glyph in data units |
| `aspect` | `:preserve` | Aspect ratio: `:preserve` (original) or `:stretch` (square) |
| `rotation` | `0.0` | Clockwise rotation: `0`, `90`, `180`, or `270` degrees |
| `mirror` | `false` | Horizontal flip |
| `clip` | `true` | Clip to axis bounds (handled automatically by Makie) |
| `on_missing` | `:skip` | Behaviour when no image is available: `:skip`, `:error`, or `:placeholder` |

## Range placement

`augment_phylopic_ranges!` adds the `at` keyword to control where along the
range the glyph is anchored:

| Value | Anchor position |
|---|---|
| `:start` (default) | `xstart` |
| `:stop` | `xstop` |
| `:midpoint` | `(xstart + xstop) / 2` |


## Thumbnail gallery

Use `pbdb_phylopic_grid` to build a gallery of silhouettes paired with taxon
names. The default layout keeps the number of columns bounded, so larger
collections grow downward rather than becoming excessively wide.

```julia
using PaleobiologyDB
using CairoMakie
using PaleobiologyDB.PhyloPic

fig = pbdb_phylopic_grid(
    [
        "Tyrannosaurus",
        "Triceratops",
        "Ankylosaurus",
        "Pachycephalosaurus",
        "Edmontosaurus",
        "Maiasaura",
    ];
    ncols = 3,
    label_fontsize = 18,
    title = "Latest Cretaceous thumbnail gallery",
)
display(fig)
```
