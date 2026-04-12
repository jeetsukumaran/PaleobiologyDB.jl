# test/phylopic_makie.jl
# Tests for PaleobiologyDB.PhyloPicMakie extension.
#
# Structure:
#   1. Offline / pure-function tests — no Makie needed (coordinates, rotation, range)
#   2. Extension-loaded tests — require CairoMakie + FileIO (Makie-gated at top level)
#   3. Live tests — gated on ENV["PBDB_LIVE"]="1"
#
# CairoMakie and FileIO are in test/Project.toml; they are always available
# when running the standard test suite.  The _EXT_AVAILABLE guard provides a
# graceful skip path in environments where they are absent.

using Test
using DataFrames
using PaleobiologyDB

# ---------------------------------------------------------------------------
# Trigger extension by loading CairoMakie + FileIO.
# ---------------------------------------------------------------------------

const _CAIRO_AVAILABLE = !isnothing(Base.find_package("CairoMakie"))
const _FILEIO_AVAILABLE = !isnothing(Base.find_package("FileIO"))
const _EXT_AVAILABLE = _CAIRO_AVAILABLE && _FILEIO_AVAILABLE

if _EXT_AVAILABLE
    # Load trigger packages — this causes the extension to load automatically.
    @eval using CairoMakie
    @eval using FileIO
    # Explicitly reference the extension module to ensure it is bound.
    @eval using PaleobiologyDB.PhyloPicMakie
end

# ---------------------------------------------------------------------------
# 1. Offline / pure-function tests (no Makie needed)
# ---------------------------------------------------------------------------

if _EXT_AVAILABLE
    # Access coordinate helpers through the extension module.
    const _bbox_fn = PaleobiologyDB.PhyloPicMakie._compute_image_bbox
    const _rot_fn  = PaleobiologyDB.PhyloPicMakie._apply_rotation
    const _ra_fn   = PaleobiologyDB.PhyloPicMakie._range_anchor

    @testset "PhyloPicMakie — _compute_image_bbox" begin

        @testset ":center placement" begin
            x_lo, x_hi, y_lo, y_hi = _bbox_fn(
                0.0, 0.0, 8, 4;
                glyph_size = 1.0, aspect = :preserve,
                placement = :center, xoffset = 0.0, yoffset = 0.0,
            )
            # aspect ratio = 8/4 = 2 → half_w = 2*1.0 = 2.0, half_h = 1.0
            @test x_lo ≈ -2.0
            @test x_hi ≈  2.0
            @test y_lo ≈ -1.0
            @test y_hi ≈  1.0
        end

        @testset ":left placement anchors at left edge" begin
            x_lo, x_hi, _, _ = _bbox_fn(
                0.0, 0.0, 8, 4;
                glyph_size = 1.0, aspect = :preserve,
                placement = :left, xoffset = 0.0, yoffset = 0.0,
            )
            @test x_lo ≈ 0.0    # left edge at anchor
            @test x_hi ≈ 4.0
        end

        @testset ":right placement anchors at right edge" begin
            x_lo, x_hi, _, _ = _bbox_fn(
                0.0, 0.0, 8, 4;
                glyph_size = 1.0, aspect = :preserve,
                placement = :right, xoffset = 0.0, yoffset = 0.0,
            )
            @test x_hi ≈ 0.0    # right edge at anchor
            @test x_lo ≈ -4.0
        end

        @testset ":stretch aspect makes square" begin
            x_lo, x_hi, y_lo, y_hi = _bbox_fn(
                0.0, 0.0, 8, 4;
                glyph_size = 1.0, aspect = :stretch,
                placement = :center, xoffset = 0.0, yoffset = 0.0,
            )
            @test (x_hi - x_lo) ≈ (y_hi - y_lo)
            @test x_lo ≈ -1.0
            @test x_hi ≈  1.0
        end

        @testset "xoffset/yoffset applied after anchoring" begin
            x_lo, x_hi, y_lo, y_hi = _bbox_fn(
                0.0, 0.0, 4, 4;
                glyph_size = 1.0, aspect = :preserve,
                placement = :center, xoffset = 5.0, yoffset = 3.0,
            )
            @test x_lo ≈ 4.0
            @test y_lo ≈ 2.0
        end

        @testset "unknown aspect throws ArgumentError" begin
            @test_throws ArgumentError _bbox_fn(
                0.0, 0.0, 4, 4;
                glyph_size = 1.0, aspect = :bad,
                placement = :center, xoffset = 0.0, yoffset = 0.0,
            )
        end

        @testset "unknown placement throws ArgumentError" begin
            @test_throws ArgumentError _bbox_fn(
                0.0, 0.0, 4, 4;
                glyph_size = 1.0, aspect = :preserve,
                placement = :diagonal, xoffset = 0.0, yoffset = 0.0,
            )
        end

    end  # _compute_image_bbox

    @testset "PhyloPicMakie — _apply_rotation" begin
        img = collect(reshape(1:8, 2, 4))   # 2 rows × 4 cols

        @testset "0° is identity" begin
            @test _rot_fn(img, 0.0) === img
        end

        @testset "90° changes dimensions" begin
            @test size(_rot_fn(img, 90.0)) == (4, 2)
        end

        @testset "180° same dimensions" begin
            @test size(_rot_fn(img, 180.0)) == (2, 4)
        end

        @testset "270° equals -90°" begin
            @test _rot_fn(img, 270.0) == _rot_fn(img, -90.0)
        end

        @testset "non-multiple-of-90 throws ArgumentError" begin
            @test_throws ArgumentError _rot_fn(img, 45.0)
            @test_throws ArgumentError _rot_fn(img, 1.0)
        end
    end  # _apply_rotation

    @testset "PhyloPicMakie — _range_anchor" begin
        @test _ra_fn(10.0, 20.0, :start)    ≈ 10.0
        @test _ra_fn(10.0, 20.0, :stop)     ≈ 20.0
        @test _ra_fn(10.0, 20.0, :midpoint) ≈ 15.0
        @test_throws ArgumentError _ra_fn(10.0, 20.0, :unknown)
    end

    @testset "PhyloPicMakie — _infer_thumbnail_grid_shape" begin
        infer_shape = PaleobiologyDB.PhyloPicMakie._infer_thumbnail_grid_shape
        @test infer_shape(0) == (1, 1)
        @test infer_shape(1) == (1, 1)
        @test infer_shape(6) == (3, 2)
        @test infer_shape(17) == (4, 5)
        @test infer_shape(6; ncols = 2) == (2, 3)
        @test infer_shape(6; nrows = 2) == (3, 2)
        @test_throws ArgumentError infer_shape(6; ncols = 0)
        @test_throws ArgumentError infer_shape(6; ncols = 2, nrows = 2)
    end

else
    @testset "PhyloPicMakie — offline / coordinates (skipped)" begin
        @info "PhyloPicMakie coordinate tests skipped: extension not available." cairo=_CAIRO_AVAILABLE fileio=_FILEIO_AVAILABLE
        @test true
    end
end

# ---------------------------------------------------------------------------
# 2. Extension-loaded tests (require Makie)
# ---------------------------------------------------------------------------

if !_EXT_AVAILABLE
    @testset "PhyloPicMakie — extension loaded (skipped)" begin
        @info "PhyloPicMakie extension tests skipped." cairo=_CAIRO_AVAILABLE fileio=_FILEIO_AVAILABLE
        @test true
    end
else

using Makie: RGBA, N0f8, Image

@testset "PhyloPicMakie — extension loaded" begin
    @test isdefined(PaleobiologyDB, :PhyloPicMakie)
    @test PaleobiologyDB.PhyloPicMakie isa Module
    @test :augment_phylopic!        ∈ names(PaleobiologyDB.PhyloPicMakie)
    @test :augment_phylopic         ∈ names(PaleobiologyDB.PhyloPicMakie)
    @test :augment_phylopic_ranges! ∈ names(PaleobiologyDB.PhyloPicMakie)
    @test :augment_phylopic_ranges  ∈ names(PaleobiologyDB.PhyloPicMakie)
    @test :phylopic_thumbnail_grid! ∈ names(PaleobiologyDB.PhyloPicMakie)
    @test :phylopic_thumbnail_grid  ∈ names(PaleobiologyDB.PhyloPicMakie)
end

# Synthetic 4-row × 8-column opaque grey RGBA image for offline render tests.
const _TEST_IMG = fill(RGBA{N0f8}(0.5, 0.5, 0.5, 1.0), 4, 8)

# Convenience: count Image plots added to an axis.
_count_images(ax) = count(p -> p isa Image, ax.scene.plots)

@testset "PhyloPicMakie — augment_phylopic! vector API" begin

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

@testset "PhyloPicMakie — augment_phylopic_ranges! vector API" begin

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

@testset "PhyloPicMakie — table API (DataFrame)" begin
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

@testset "PhyloPicMakie — range table API (DataFrame)" begin
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


@testset "PhyloPicMakie — thumbnail grid" begin

    # These three tests are safe without network: empty/whitespace names are
    # skipped by _resolve_images before acquire_phylopic is called, and the
    # invalid-fraction test throws ArgumentError before _resolve_images runs.
    @testset "placeholder mode draws plot objects for missing thumbnails" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        n0 = length(ax.scene.plots)
        phylopic_thumbnail_grid!(ax, ["", " "]; on_missing = :placeholder, ncols = 1)
        @test _count_images(ax) == 0
        @test length(ax.scene.plots) ≥ n0 + 4
    end

    @testset "error mode throws for unresolved thumbnails" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_throws ErrorException phylopic_thumbnail_grid!(ax, [""]; on_missing = :error)
    end

    @testset "invalid glyph fraction throws" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_throws ArgumentError phylopic_thumbnail_grid!(ax, ["Tyrannosaurus"]; glyph_fraction = 1.0)
    end

    if !LIVE
        @info "Live thumbnail grid tests skipped. Set ENV[\"PBDB_LIVE\"]=\"1\" to enable."
    else
        @testset "bang variant adds one image per taxon and labels" begin
            taxa = ["Tyrannosaurus", "Triceratops", "Ankylosaurus", "Edmontosaurus"]
            fig = Figure(); ax = Axis(fig[1, 1])
            n0 = length(ax.scene.plots)
            phylopic_thumbnail_grid!(ax, taxa; glyph_fraction = 0.5, ncols = 2, on_missing = :placeholder)
            @test _count_images(ax) == 4
            @test length(ax.scene.plots) ≥ n0 + 8
        end

        @testset "non-bang constructor returns a figure" begin
            fig = phylopic_thumbnail_grid(["Tyrannosaurus", "Triceratops", "Ankylosaurus"]; ncols = 2)
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
        loader = PaleobiologyDB.PhyloPicMakie._load_phylopic_image
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
    end

    @testset "augment_phylopic! end-to-end with real taxon" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        augment_phylopic!(ax, [68.0], [1.0];
            taxon = ["Tyrannosaurus"], glyph_size = 0.4, placement = :left)
        @test _count_images(ax) == 1
    end

end  # live image caching
