# test/phylopic_makie.jl
# Tests for PaleobiologyDB.PhyloPic rendering integration.
#
# Structure:
#   1. Makie-gated tests — require CairoMakie
#      - PhyloPic submodule loaded
#      - augment_phylopic! vector and ranges API (PBDB wrappers, glyph=pre-resolved)
#      - augment_phylopic! table (DataFrame) API
#      - augment_phylopic_ranges! table API
#      - pbdb_phylopic_grid! offline validation (PBDB wrapper)
#   2. Live tests — gated on ENV["PBDB_LIVE"]="1"
#
# Pure-function PhyloPicMakie helpers (_compute_image_bbox, _apply_rotation,
# _range_anchor, _infer_thumbnail_grid_shape, _rows_grid_positions, etc.) are
# tested in PhyloPicMakie.jl's own test suite, not here.
#
# PhyloPicMakie is a hard dep of PaleobiologyDB and is always available.
# CairoMakie is in test/Project.toml.  The _EXT_AVAILABLE guard provides a
# graceful skip path in environments where CairoMakie is absent.

using Test
using DataFrames
using PaleobiologyDB

# ---------------------------------------------------------------------------
# Load CairoMakie to activate the PBDBMakie extension and provide a
# Makie backend.  PhyloPicMakie is a hard dep — always available.
# ---------------------------------------------------------------------------

const _CAIRO_AVAILABLE = !isnothing(Base.find_package("CairoMakie"))
const _EXT_AVAILABLE = _CAIRO_AVAILABLE

if _EXT_AVAILABLE
    @eval using CairoMakie
    # PhyloPicMakie is a hard dep of PaleobiologyDB; import for unit-test helpers.
    @eval import PhyloPicMakie
end

# ---------------------------------------------------------------------------
# 1. Makie-gated tests (require CairoMakie)
# ---------------------------------------------------------------------------

if !_EXT_AVAILABLE
    @testset "PhyloPicMakie — Makie-gated tests (skipped)" begin
        @info "PhyloPicMakie Makie-gated tests skipped." cairo=_CAIRO_AVAILABLE
        @test true
    end
else

using Makie: RGBA, N0f8, Image

@testset "PhyloPic — submodule loaded" begin
    # PhyloPic is a submodule of the PBDBMakie extension.
    @test isdefined(PaleobiologyDB.PBDBMakie, :_PhyloPic) && !isnothing(PaleobiologyDB.PBDBMakie._PhyloPic[])
    @test PaleobiologyDB.PBDBMakie._PhyloPic[] isa Module
    @test :augment_phylopic!        ∈ names(PaleobiologyDB.PBDBMakie._PhyloPic[])
    @test :augment_phylopic         ∈ names(PaleobiologyDB.PBDBMakie._PhyloPic[])
    @test :augment_phylopic_ranges! ∈ names(PaleobiologyDB.PBDBMakie._PhyloPic[])
    @test :augment_phylopic_ranges  ∈ names(PaleobiologyDB.PBDBMakie._PhyloPic[])
    @test :pbdb_phylopic_grid! ∈ names(PaleobiologyDB.PBDBMakie._PhyloPic[])
    @test :pbdb_phylopic_grid  ∈ names(PaleobiologyDB.PBDBMakie._PhyloPic[])

    # PhyloPicMakie is a hard dep of PaleobiologyDB — always available.
    @test PhyloPicMakie isa Module
    @test PhyloPicMakie.PhyloPicDB isa Module
end

# Synthetic 4-row × 8-column opaque grey RGBA image for offline render tests.
const _TEST_IMG = fill(RGBA{N0f8}(0.5, 0.5, 0.5, 1.0), 4, 8)

# Convenience: count rendered PhyloPic glyph markers added to an axis.
function _count_images(ax)
    n = 0
    for plot in ax.scene.plots
        plot isa Image && (n += 1)
        marker = try
            plot.marker[]
        catch
            nothing
        end
        if marker isa AbstractVector && !isempty(marker) && all(m -> m isa AbstractMatrix, marker)
            n += length(marker)
        elseif marker isa AbstractMatrix
            n += 1
        end
    end
    return n
end

@testset "PhyloPic — augment_phylopic! vector API" begin

    @testset "glyph broadcast to all data points" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        augment_phylopic!(ax, [0.0, 1.0, 2.0], [0.0, 1.0, 2.0];
            glyph = _TEST_IMG, glyph_size = 1.0)
        @test _count_images(ax) == 3
    end

    @testset "on_missing=:skip — missing taxon produces no image" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        augment_phylopic!(ax, [0.0], [0.0];
            taxon = [missing], on_missing = :skip)
        @test _count_images(ax) == 0
    end

    @testset "neither taxon nor glyph throws ArgumentError" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_throws ArgumentError augment_phylopic!(ax, [0.0], [0.0])
    end

    @testset "on_missing=:placeholder — adds poly for missing" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        n0 = length(ax.scene.plots)
        augment_phylopic!(ax, [0.0], [0.0];
            taxon = [missing], on_missing = :placeholder, glyph_size = 0.4)
        @test length(ax.scene.plots) > n0
    end

    @testset "mirror=true — image still added" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        augment_phylopic!(ax, [0.0], [0.0];
            glyph = _TEST_IMG, glyph_size = 1.0, mirror = true)
        @test _count_images(ax) == 1
    end

    @testset "rotation=90 — image still added" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        augment_phylopic!(ax, [0.0], [0.0];
            glyph = _TEST_IMG, glyph_size = 1.0, rotation = 90.0)
        @test _count_images(ax) == 1
    end

    @testset "non-bang alias (augment_phylopic)" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        augment_phylopic(ax, [0.0, 1.0], [0.0, 1.0];
            glyph = _TEST_IMG, glyph_size = 1.0)
        @test _count_images(ax) == 2
    end

    @testset "mismatched x/y length throws ArgumentError" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_throws ArgumentError augment_phylopic!(ax, [0.0, 1.0], [0.0];
            glyph = _TEST_IMG)
    end

end  # augment_phylopic! vector API

@testset "PhyloPic — augment_phylopic_ranges! vector API" begin

    @testset "at=:start" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        augment_phylopic_ranges!(ax, [10.0], [20.0], [1.0];
            glyph = _TEST_IMG, glyph_size = 1.0, at = :start)
        @test _count_images(ax) == 1
    end

    @testset "at=:stop" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        augment_phylopic_ranges!(ax, [10.0], [20.0], [1.0];
            glyph = _TEST_IMG, glyph_size = 1.0, at = :stop)
        @test _count_images(ax) == 1
    end

    @testset "at=:midpoint" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        augment_phylopic_ranges!(ax, [10.0], [20.0], [1.0];
            glyph = _TEST_IMG, glyph_size = 1.0, at = :midpoint)
        @test _count_images(ax) == 1
    end

    @testset "non-bang alias (augment_phylopic_ranges)" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        augment_phylopic_ranges(ax, [10.0, 5.0], [20.0, 15.0], [1.0, 2.0];
            glyph = _TEST_IMG, glyph_size = 1.0)
        @test _count_images(ax) == 2
    end

    @testset "mismatched xstart/xstop throws" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_throws ArgumentError augment_phylopic_ranges!(
            ax, [10.0, 11.0], [20.0], [1.0]; glyph = _TEST_IMG)
    end

end  # augment_phylopic_ranges! vector API

@testset "PhyloPic — table API (DataFrame)" begin
    df = DataFrame(x = [0.0, 1.0, 2.0], y = [0.0, 1.0, 2.0])

    @testset "augment_phylopic! with Symbol column selectors" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        augment_phylopic!(ax, df; x = :x, y = :y,
            glyph = _TEST_IMG, glyph_size = 1.0)
        @test _count_images(ax) == 3
    end

    @testset "augment_phylopic non-bang alias" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        augment_phylopic(ax, df; x = :x, y = :y,
            glyph = _TEST_IMG, glyph_size = 1.0)
        @test _count_images(ax) == 3
    end

    @testset "missing column selector throws ArgumentError" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_throws ArgumentError augment_phylopic!(ax, df;
            x = :nonexistent, y = :y, glyph = _TEST_IMG)
    end

end  # table API

@testset "PhyloPic — range table API (DataFrame)" begin
    df = DataFrame(
        first_app = [68.0, 68.0],
        last_app  = [66.0, 66.0],
        row       = [1.0, 2.0],
    )

    @testset "augment_phylopic_ranges! with DataFrame" begin
        fig = Figure(); ax = Axis(fig[1, 1]; xreversed = true)
        augment_phylopic_ranges!(ax, df;
            xstart = :first_app, xstop = :last_app, y = :row,
            glyph = _TEST_IMG, glyph_size = 0.4)
        @test _count_images(ax) == 2
    end

    @testset "augment_phylopic_ranges non-bang alias" begin
        fig = Figure(); ax = Axis(fig[1, 1]; xreversed = true)
        augment_phylopic_ranges(ax, df;
            xstart = :first_app, xstop = :last_app, y = :row,
            glyph = _TEST_IMG, glyph_size = 0.4)
        @test _count_images(ax) == 2
    end

end  # range table API


@testset "PhyloPic — thumbnail grid" begin

    # Offline tests: no network needed.
    #
    # Note on empty-name behaviour: the new image-pool resolution returns an
    # empty pool for blank/whitespace names, so they contribute zero cells to
    # the grid.  The `on_missing` policy applies only to cells whose selected
    # image could not be downloaded — not to taxa that produced no pool at all.

    @testset "empty names produce no cells (skip mode)" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        n0 = length(ax.scene.plots)
        pbdb_phylopic_grid!(ax, ["", " "]; on_missing = :skip, ncols = 1)
        @test _count_images(ax) == 0
        @test length(ax.scene.plots) == n0   # nothing drawn for empty names
    end

    @testset "empty names produce no cells (placeholder mode)" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        n0 = length(ax.scene.plots)
        pbdb_phylopic_grid!(ax, ["", " "]; on_missing = :placeholder, ncols = 1)
        @test _count_images(ax) == 0
        @test length(ax.scene.plots) == n0   # blank names → no pool → no cells
    end

    @testset "empty names do not trigger error mode" begin
        # Empty names yield 0 cells; on_missing=:error only fires for cells
        # with a selected image whose download failed — not for missing pools.
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_nowarn pbdb_phylopic_grid!(ax, [""]; on_missing = :error)
    end

    @testset "image_filter = :clade, empty names → no cells" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        n0 = length(ax.scene.plots)
        pbdb_phylopic_grid!(ax, ["", " "]; image_filter = :clade)
        @test _count_images(ax) == 0
        @test length(ax.scene.plots) == n0
    end

    @testset "image_filter = :node, empty names, blocks layout → no cells" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        n0 = length(ax.scene.plots)
        pbdb_phylopic_grid!(ax, ["", " "];
            image_filter = :node, image_layout = :blocks)
        @test _count_images(ax) == 0
        @test length(ax.scene.plots) == n0
    end

    @testset "image_layout = :rows, empty names → no cells" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        n0 = length(ax.scene.plots)
        pbdb_phylopic_grid!(ax, ["", " "]; image_filter = :node, image_layout = :rows)
        @test _count_images(ax) == 0
        @test length(ax.scene.plots) == n0
    end

    @testset "image_label = :attribution, empty names → no crash" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_nowarn pbdb_phylopic_grid!(ax, ["", " "];
            image_filter = :primary, image_label = :attribution)
    end

    @testset "image_label callable, empty names → no crash" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_nowarn pbdb_phylopic_grid!(ax, ["", " "];
            image_filter = :primary, image_label = (name, k, img) -> "$name-$k")
    end

    @testset "non-bang: nrows not over-constrained by taxon count (regression)" begin
        # Regression guard: non-bang must not forward its inferred nrows to the
        # bang variant, because when image_filter != :primary the cell count can
        # exceed the taxon count, causing _infer_thumbnail_grid_shape to throw.
        # Empty names produce 0 cells, so this is fully offline.
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_nowarn pbdb_phylopic_grid!(ax, ["", "", ""];
            image_filter = :primary, ncols = 1, nrows = 1)
    end

    @testset "image_label = :BASICFIELDS (default), empty names → no crash" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_nowarn pbdb_phylopic_grid!(ax, ["", " "];
            image_filter = :primary, image_label = :BASICFIELDS)
    end

    @testset "image_label = :ALLFIELDS, empty names → no crash" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_nowarn pbdb_phylopic_grid!(ax, ["", " "];
            image_filter = :primary, image_label = :ALLFIELDS)
    end

    @testset "image_label = :BASICFIELDS, empty names → no crash" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_nowarn pbdb_phylopic_grid!(ax, ["", " "];
            image_filter = :primary, image_label = :BASICFIELDS)
    end

    @testset "image_label = Vector{Symbol}, empty names → no crash" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_nowarn pbdb_phylopic_grid!(ax, ["", " "];
            image_filter = :primary, image_label = [:taxon_name, :index, :uuid])
    end

    @testset "labeljoin forwarded through non-bang, empty names → no crash" begin
        @test_nowarn pbdb_phylopic_grid(["", " "];
            image_filter = :primary, image_label = :BASICFIELDS, labeljoin = " | ")
    end

    @testset "label_lines = 1 suppresses eff_cell_height expansion" begin
        # Empty names → no cells; ymax = 1 row × eff_cell_height.
        # With label_lines = 1, eff_cell_height equals the nominal cell_height.
        fig1 = Figure(); ax1 = Axis(fig1[1, 1])
        pbdb_phylopic_grid!(ax1, ["", " "]; image_filter = :primary)
        fig2 = Figure(); ax2 = Axis(fig2[1, 1])
        pbdb_phylopic_grid!(ax2, ["", " "]; image_filter = :primary, label_lines = 1)
        @test ax1.limits[] == ax2.limits[]
    end

    @testset "label_lines = 3 expands eff_cell_height above nominal" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        pbdb_phylopic_grid!(ax, ["", " "]; image_filter = :primary, label_lines = 3)
        ymax         = ax.limits[][2][2]
        default_cell = PhyloPicMakie.DEFAULT_THUMBNAIL_GRID_CELL_HEIGHT
        @test ymax > default_cell
    end

    @testset "label_lines forwarded through non-bang, empty names → no crash" begin
        @test_nowarn pbdb_phylopic_grid(["", " "];
            image_filter = :primary, label_lines = 2)
    end

    if !LIVE
        @info "Live thumbnail grid tests skipped. Set ENV[\"PBDB_LIVE\"]=\"1\" to enable."
    else
        @testset "invalid glyph fraction throws ArgumentError" begin
            fig = Figure(); ax = Axis(fig[1, 1])
            @test_throws ArgumentError pbdb_phylopic_grid!(ax, ["Tyrannosaurus"]; glyph_fraction = 1.0)
        end

        @testset "invalid image_filter throws ArgumentError" begin
            fig = Figure(); ax = Axis(fig[1, 1])
            @test_throws ArgumentError pbdb_phylopic_grid!(
                ax, ["Tyrannosaurus"]; image_filter = :universe)
        end

        @testset "invalid image_layout throws ArgumentError" begin
            fig = Figure(); ax = Axis(fig[1, 1])
            @test_throws ArgumentError pbdb_phylopic_grid!(
                ax, ["Tyrannosaurus"]; image_layout = :diagonal)
        end

        @testset "image_layout = :grouped now throws ArgumentError (renamed to :blocks)" begin
            fig = Figure(); ax = Axis(fig[1, 1])
            @test_throws ArgumentError pbdb_phylopic_grid!(
                ax, ["Tyrannosaurus"]; image_layout = :grouped)
        end

        @testset "primary filter — one image per taxon" begin
            taxa = ["Tyrannosaurus", "Triceratops", "Ankylosaurus", "Edmontosaurus"]
            fig = Figure(); ax = Axis(fig[1, 1])
            n0 = length(ax.scene.plots)
            pbdb_phylopic_grid!(ax, taxa;
                image_filter = :primary, glyph_fraction = 0.5,
                ncols = 2, on_missing = :placeholder)
            @test _count_images(ax) == 4
            @test length(ax.scene.plots) ≥ n0 + 8   # 4 images + 4 labels
        end

        @testset "clade filter, :first selector — one cell per taxon" begin
            taxa = ["Tyrannosaurus", "Triceratops"]
            fig = Figure(); ax = Axis(fig[1, 1])
            pbdb_phylopic_grid!(ax, taxa;
                image_filter = :clade, image_selector = :first,
                on_missing = :placeholder, ncols = 2)
            @test length(ax.scene.plots) ≥ 2
        end

        @testset "clade filter, integer selector — one cell per taxon" begin
            fig = Figure(); ax = Axis(fig[1, 1])
            pbdb_phylopic_grid!(ax, ["Tyrannosaurus"];
                image_filter = :clade, image_selector = 1,
                on_missing = :placeholder, ncols = 2)
            @test length(ax.scene.plots) ≥ 1
        end

        @testset "node filter, all images, blocks layout" begin
            fig = Figure(); ax = Axis(fig[1, 1])
            pbdb_phylopic_grid!(ax, ["Tyrannosaurus"];
                image_filter = :node, image_layout = :blocks,
                image_max_pages = 1, on_missing = :placeholder, ncols = 4)
            @test length(ax.scene.plots) ≥ 1
        end

        @testset "callable selector returns list" begin
            fig = Figure(); ax = Axis(fig[1, 1])
            pbdb_phylopic_grid!(ax, ["Carnivora"];
                image_filter = :clade,
                image_selector = imgs -> isempty(imgs) ? imgs : [imgs[1]],
                image_layout = :flat, image_max_pages = 1, ncols = 4)
            @test length(ax.scene.plots) ≥ 1
        end

        @testset "non-bang constructor returns a Figure" begin
            fig = pbdb_phylopic_grid(
                ["Tyrannosaurus", "Triceratops", "Ankylosaurus"]; ncols = 2)
            @test fig isa Figure
        end

        @testset "non-bang with clade filter returns a Figure" begin
            fig = pbdb_phylopic_grid(
                ["Tyrannosaurus"];
                image_filter = :clade, image_selector = :first, ncols = 2)
            @test fig isa Figure
        end
    end

end

end  # if _EXT_AVAILABLE

# ---------------------------------------------------------------------------
# 3. Live tests: real image download + autocaching
# ---------------------------------------------------------------------------

@testset "PhyloPicMakie — live image caching" begin
    if !LIVE
        @info "Live PhyloPicMakie tests skipped. Set ENV[\"PBDB_LIVE\"]=\"1\" to enable."
        return
    end
    if !_EXT_AVAILABLE
        @info "Live PhyloPicMakie tests skipped: extension not available."
        return
    end

    using DataCaches

    @testset "image download and DataCache hit" begin
        cache  = DataCache(mktempdir())
        # _load_phylopic_image lives in PhyloPicMakie.
        loader = PhyloPicMakie._load_phylopic_image
        PaleobiologyDB.set_autocaching!(true, loader; cache = cache)

        rec = PaleobiologyDB.Taxonomy.acquire_phylopic("Tyrannosaurus")
        @test !ismissing(rec.phylopic_thumbnail)

        url   = rec.phylopic_thumbnail
        img1  = loader(url)
        @test img1 isa Matrix

        n_before = length(cache)
        img2 = loader(url)
        @test img2 == img1
        @test length(cache) == n_before   # no new cache entry

        PaleobiologyDB.set_autocaching!(false, loader; cache = cache)
        # (loader is PhyloPicMakie._load_phylopic_image)
    end

    @testset "augment_phylopic! end-to-end with real taxon" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        augment_phylopic!(ax, [68.0], [1.0];
            taxon = ["Tyrannosaurus"], glyph_size = 0.4, placement = :left)
        @test _count_images(ax) == 1
    end

end  # live image caching
