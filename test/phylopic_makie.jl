# test/phylopic_makie.jl
# Tests for PaleobiologyDB.PhyloPicPBDB and PhyloPicMakie.
#
# Structure:
#   1. Offline / pure-function tests — no Makie backend needed (coordinates, rotation, range)
#   2. Makie-gated tests — require CairoMakie
#   3. Live tests — gated on ENV["PBDB_LIVE"]="1"
#
# PhyloPicMakie is a hard dep of PaleobiologyDB and is always available.
# CairoMakie is in test/Project.toml.  The _EXT_AVAILABLE guard provides a
# graceful skip path in environments where CairoMakie is absent.

using Test
using DataFrames
using PaleobiologyDB

# ---------------------------------------------------------------------------
# Load CairoMakie to activate the TaxonTreeMakie extension and provide a
# Makie backend.  PhyloPicMakie is a hard dep — always available.
# ---------------------------------------------------------------------------

const _CAIRO_AVAILABLE = !isnothing(Base.find_package("CairoMakie"))
const _EXT_AVAILABLE = _CAIRO_AVAILABLE

if _EXT_AVAILABLE
    @eval using CairoMakie
    @eval using PaleobiologyDB.PhyloPicPBDB
    # PhyloPicMakie is a hard dep of PaleobiologyDB; import for unit-test helpers.
    @eval import PhyloPicMakie
end

# ---------------------------------------------------------------------------
# 1. Offline / pure-function tests (no Makie needed)
# ---------------------------------------------------------------------------

if _EXT_AVAILABLE
    # Coordinate helpers live in PhyloPicMakie.
    const _bbox_fn = PhyloPicMakie._compute_image_bbox
    const _rot_fn  = PhyloPicMakie._apply_rotation
    const _ra_fn   = PhyloPicMakie._range_anchor

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

        @testset "axis_scale_correction scales half_w for :preserve" begin
            # scale_correction = 2.0 → x-extent doubles, y-extent unchanged
            x_lo1, x_hi1, y_lo1, y_hi1 = _bbox_fn(
                0.0, 0.0, 8, 4;
                glyph_size = 1.0, aspect = :preserve,
                placement = :center, xoffset = 0.0, yoffset = 0.0,
                axis_scale_correction = 1.0,
            )
            x_lo2, x_hi2, y_lo2, y_hi2 = _bbox_fn(
                0.0, 0.0, 8, 4;
                glyph_size = 1.0, aspect = :preserve,
                placement = :center, xoffset = 0.0, yoffset = 0.0,
                axis_scale_correction = 2.0,
            )
            @test (x_hi2 - x_lo2) ≈ 2 * (x_hi1 - x_lo1)
            @test y_lo2 ≈ y_lo1
            @test y_hi2 ≈ y_hi1
        end

        @testset "axis_scale_correction ignored for :stretch" begin
            x_lo1, x_hi1, _, _ = _bbox_fn(
                0.0, 0.0, 8, 4;
                glyph_size = 1.0, aspect = :stretch,
                placement = :center, xoffset = 0.0, yoffset = 0.0,
                axis_scale_correction = 1.0,
            )
            x_lo2, x_hi2, _, _ = _bbox_fn(
                0.0, 0.0, 8, 4;
                glyph_size = 1.0, aspect = :stretch,
                placement = :center, xoffset = 0.0, yoffset = 0.0,
                axis_scale_correction = 3.0,
            )
            @test x_lo1 ≈ x_lo2
            @test x_hi1 ≈ x_hi2
        end

    end  # _compute_image_bbox

    @testset "PhyloPicMakie — _axis_scale_correction_obs" begin
        # Creates a Figure + Axis and checks the observable returns a positive Float64.
        # Before the figure is displayed the projectionview may be degenerate, in
        # which case _axis_scale_correction_obs returns the safe default 1.0.
        fig = Figure()
        ax  = Axis(fig[1, 1])
        obs = PhyloPicMakie._axis_scale_correction_obs(ax.scene)
        @test obs isa Makie.Observable
        sc = obs[]
        @test sc isa Float64
        @test sc > 0.0
    end

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
        infer_shape = PhyloPicMakie._infer_thumbnail_grid_shape
        @test infer_shape(0) == (1, 1)
        @test infer_shape(1) == (1, 1)
        @test infer_shape(6) == (3, 2)
        @test infer_shape(17) == (4, 5)
        @test infer_shape(6; ncols = 2) == (2, 3)
        @test infer_shape(6; nrows = 2) == (3, 2)
        @test_throws ArgumentError infer_shape(6; ncols = 0)
        @test_throws ArgumentError infer_shape(6; ncols = 2, nrows = 2)
    end

    # Unit tests for _extract_image_field, _join_fields, _build_label.
    # Uses PhyloPicMakie.PhyloPicDB._null_image to construct a minimal PhyloPicImage offline.
    @testset "PhyloPicMakie — _extract_image_field" begin
        extract  = PhyloPicMakie._extract_image_field
        null_img = PhyloPicMakie.PhyloPicDB._null_image(1)   # all optional fields missing/nothing, uuid = ""

        @testset "virtual field :taxon_name" begin
            @test extract(:taxon_name, "Felidae", 3, null_img) == "Felidae"
        end

        @testset "virtual field :index" begin
            @test extract(:index, "Felidae", 3, null_img) == "3"
        end

        @testset ":node_name nothing on null image" begin
            @test isnothing(extract(:node_name, "Felidae", 1, null_img))
        end

        @testset ":uuid always returns a String (empty for null image)" begin
            val = extract(:uuid, "Felidae", 1, null_img)
            @test val isa String
        end

        @testset ":attribution missing on null image" begin
            @test ismissing(extract(:attribution, "Felidae", 1, null_img))
        end

        @testset ":license missing on null image" begin
            @test ismissing(extract(:license, "Felidae", 1, null_img))
        end

        @testset ":specific_node_uuid nothing on null image" begin
            @test isnothing(extract(:specific_node_uuid, "Felidae", 1, null_img))
        end

        @testset "unknown symbol throws ArgumentError" begin
            @test_throws ArgumentError extract(:notafield, "Felidae", 1, null_img)
        end
    end

    @testset "PhyloPicMakie — _join_fields" begin
        join_f   = PhyloPicMakie._join_fields
        null_img = PhyloPicMakie.PhyloPicDB._null_image(1)

        @testset "virtual-only fields always present" begin
            result = join_f([:taxon_name, :index], "Felidae", 2, null_img, " | ")
            @test result == "Felidae | 2"
        end

        @testset "missing structural field skipped" begin
            # :attribution is missing → only :taxon_name survives
            result = join_f([:taxon_name, :attribution], "Felidae", 1, null_img, "\n")
            @test result == "Felidae"
        end

        @testset "nothing structural field skipped" begin
            # :node_name is nothing on null_img → only :taxon_name survives
            result = join_f([:taxon_name, :node_name], "Felidae", 1, null_img, "\n")
            @test result == "Felidae"
        end

        @testset "empty uuid skipped" begin
            # null_img.uuid == "" → skipped
            result = join_f([:taxon_name, :uuid], "Felidae", 1, null_img, "\n")
            @test result == "Felidae"
        end

        @testset "empty field list → empty string" begin
            @test join_f(Symbol[], "Felidae", 1, null_img, "\n") == ""
        end

        @testset "custom separator respected" begin
            result = join_f([:taxon_name, :index], "Carnivora", 5, null_img, " :: ")
            @test result == "Carnivora :: 5"
        end
    end

    @testset "PhyloPicMakie — _build_label" begin
        bl       = PhyloPicMakie._build_label
        null_img = PhyloPicMakie.PhyloPicDB._null_image(1)

        @testset "nothing, single-image group → name only" begin
            @test bl("Felidae", 1, false, null_img, nothing, "\n") == "Felidae"
        end

        @testset "nothing, multi-image group → name [k]" begin
            @test bl("Felidae", 3, true, null_img, nothing, "\n") == "Felidae [3]"
        end


        @testset ":BASICFIELDS is [:index, :node_name, :taxon_name]; node_name absent on null" begin
            # null_img: node_name=nothing → skipped; index and taxon_name survive
            result = bl("Felidae", 2, true, null_img, :BASICFIELDS, " | ")
            @test result == "2 | Felidae"
        end

        @testset "Vector{Symbol}: missing/nothing fields dropped, labeljoin used" begin
            # :attribution missing → only :taxon_name
            @test bl("Felidae", 1, false, null_img, [:taxon_name, :attribution], "\n") == "Felidae"
            # :taxon_name + :index with custom sep
            @test bl("Carnivora", 3, true, null_img, [:taxon_name, :index], " — ") == "Carnivora — 3"
        end

        @testset "single known symbol missing/nothing → falls back to default" begin
            @test bl("Felidae", 1, false, null_img, :attribution, "\n") == "Felidae"
            @test bl("Felidae", 2, true,  null_img, :attribution, "\n") == "Felidae [2]"
            # :node_name is nothing on null_img → falls back to default
            @test bl("Felidae", 1, false, null_img, :node_name, "\n") == "Felidae"
            @test bl("Felidae", 3, true,  null_img, :node_name, "\n") == "Felidae [3]"
        end

        @testset "callable receives name, k, img" begin
            f = (name, k, img) -> "$(name):$(k)"
            @test bl("Felidae", 7, true, null_img, f, "\n") == "Felidae:7"
        end

        @testset "unknown Symbol throws ArgumentError" begin
            @test_throws ArgumentError bl("Felidae", 1, false, null_img, :notafield, "\n")
        end
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
    @testset "PhyloPicMakie — Makie-gated tests (skipped)" begin
        @info "PhyloPicMakie Makie-gated tests skipped." cairo=_CAIRO_AVAILABLE
        @test true
    end
else

using Makie: RGBA, N0f8, Image

@testset "PhyloPicPBDB — submodule loaded" begin
    # PhyloPicPBDB is a top-level submodule of PaleobiologyDB.
    @test isdefined(PaleobiologyDB, :PhyloPicPBDB)
    @test PaleobiologyDB.PhyloPicPBDB isa Module
    @test :augment_phylopic!        ∈ names(PaleobiologyDB.PhyloPicPBDB)
    @test :augment_phylopic         ∈ names(PaleobiologyDB.PhyloPicPBDB)
    @test :augment_phylopic_ranges! ∈ names(PaleobiologyDB.PhyloPicPBDB)
    @test :augment_phylopic_ranges  ∈ names(PaleobiologyDB.PhyloPicPBDB)
    @test :phylopic_thumbnail_grid! ∈ names(PaleobiologyDB.PhyloPicPBDB)
    @test :phylopic_thumbnail_grid  ∈ names(PaleobiologyDB.PhyloPicPBDB)

    # PhyloPicMakie is a hard dep of PaleobiologyDB — always available.
    @test PhyloPicMakie isa Module
    @test PhyloPicMakie.PhyloPicDB isa Module
end

# Synthetic 4-row × 8-column opaque grey RGBA image for offline render tests.
const _TEST_IMG = fill(RGBA{N0f8}(0.5, 0.5, 0.5, 1.0), 4, 8)

# Convenience: count Image plots added to an axis.
_count_images(ax) = count(p -> p isa Image, ax.scene.plots)

@testset "PhyloPicPBDB — augment_phylopic! vector API" begin

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

@testset "PhyloPicPBDB — augment_phylopic_ranges! vector API" begin

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

# ---------------------------------------------------------------------------
# Smoke tests: generic PhyloPicMakie entry points (pre-resolved images)
# ---------------------------------------------------------------------------

# Shared keyword args for the generic augment_phylopic! (no default keywords).
const _AUGMENT_KW = (
    glyph_size = 1.0,
    aspect     = :preserve,
    placement  = :center,
    xoffset    = 0.0,
    yoffset    = 0.0,
    rotation   = 0.0,
    mirror     = false,
    on_missing = :skip,
)

@testset "PhyloPicMakie — augment_phylopic! (pre-resolved images)" begin

    @testset "nothing image, on_missing=:skip → no images added" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        PhyloPicMakie.augment_phylopic!(ax, [0.0], [0.0], [nothing];
            _AUGMENT_KW..., on_missing = :skip)
        @test _count_images(ax) == 0
    end

    @testset "nothing image, on_missing=:placeholder → placeholder poly added" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        n0 = length(ax.scene.plots)
        PhyloPicMakie.augment_phylopic!(ax, [0.0], [0.0], [nothing];
            _AUGMENT_KW..., on_missing = :placeholder)
        @test length(ax.scene.plots) > n0
    end

    @testset "pre-resolved image matrix rendered without taxon resolution" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        PhyloPicMakie.augment_phylopic!(ax, [0.0], [0.0], [_TEST_IMG];
            _AUGMENT_KW...)
        @test _count_images(ax) == 1
    end

end  # PhyloPicMakie augment_phylopic! pre-resolved

@testset "PhyloPicMakie — augment_phylopic_ranges! (pre-resolved images)" begin

    @testset "at=:midpoint, pre-resolved image → one image" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        PhyloPicMakie.augment_phylopic_ranges!(
            ax, [10.0], [20.0], [1.0], [_TEST_IMG];
            glyph_size = 1.0, aspect = :preserve, placement = :center,
            xoffset = 0.0, yoffset = 0.0, rotation = 0.0, mirror = false,
            on_missing = :skip, at = :midpoint)
        @test _count_images(ax) == 1
    end

    @testset "mismatched xstart/xstop throws ArgumentError" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_throws ArgumentError PhyloPicMakie.augment_phylopic_ranges!(
            ax, [10.0, 11.0], [20.0], [1.0], [_TEST_IMG, _TEST_IMG];
            glyph_size = 1.0, aspect = :preserve, placement = :center,
            xoffset = 0.0, yoffset = 0.0, rotation = 0.0, mirror = false,
            on_missing = :skip)
    end

end  # PhyloPicMakie augment_phylopic_ranges! pre-resolved

@testset "PhyloPicMakie — phylopic_thumbnail_grid! (pre-built cells)" begin

    @testset "empty cell list renders without error" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_nowarn PhyloPicMakie.phylopic_thumbnail_grid!(
            ax, [], String[], Int[])
    end

    @testset "single nothing cell with on_missing=:placeholder → no crash" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_nowarn PhyloPicMakie.phylopic_thumbnail_grid!(
            ax, [nothing], ["label"], [1]; on_missing = :placeholder)
    end

    @testset "single pre-resolved image cell renders" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        n0 = length(ax.scene.plots)
        PhyloPicMakie.phylopic_thumbnail_grid!(
            ax, [_TEST_IMG], ["test label"], [1])
        @test length(ax.scene.plots) > n0
    end

    @testset "factory (non-bang) returns a Figure" begin
        fig = PhyloPicMakie.phylopic_thumbnail_grid(
            [_TEST_IMG], ["test label"], [1])
        @test fig isa Figure
    end

end  # PhyloPicMakie phylopic_thumbnail_grid! pre-built cells

@testset "PhyloPicPBDB — table API (DataFrame)" begin
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

@testset "PhyloPicPBDB — range table API (DataFrame)" begin
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


@testset "PhyloPicPBDB — thumbnail grid" begin

    # Offline tests: no network needed.
    #
    # Note on empty-name behaviour: the new image-pool resolution returns an
    # empty pool for blank/whitespace names, so they contribute zero cells to
    # the grid.  The `on_missing` policy applies only to cells whose selected
    # image could not be downloaded — not to taxa that produced no pool at all.

    @testset "empty names produce no cells (skip mode)" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        n0 = length(ax.scene.plots)
        phylopic_thumbnail_grid!(ax, ["", " "]; on_missing = :skip, ncols = 1)
        @test _count_images(ax) == 0
        @test length(ax.scene.plots) == n0   # nothing drawn for empty names
    end

    @testset "empty names produce no cells (placeholder mode)" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        n0 = length(ax.scene.plots)
        phylopic_thumbnail_grid!(ax, ["", " "]; on_missing = :placeholder, ncols = 1)
        @test _count_images(ax) == 0
        @test length(ax.scene.plots) == n0   # blank names → no pool → no cells
    end

    @testset "empty names do not trigger error mode" begin
        # Empty names yield 0 cells; on_missing=:error only fires for cells
        # with a selected image whose download failed — not for missing pools.
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_nowarn phylopic_thumbnail_grid!(ax, [""]; on_missing = :error)
    end

    @testset "invalid glyph fraction throws ArgumentError" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_throws ArgumentError phylopic_thumbnail_grid!(ax, ["Tyrannosaurus"]; glyph_fraction = 1.0)
    end

    @testset "invalid image_filter throws ArgumentError" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_throws ArgumentError phylopic_thumbnail_grid!(
            ax, ["Tyrannosaurus"]; image_filter = :universe)
    end

    @testset "invalid image_layout throws ArgumentError" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_throws ArgumentError phylopic_thumbnail_grid!(
            ax, ["Tyrannosaurus"]; image_layout = :diagonal)
    end

    @testset "image_filter = :clade, empty names → no cells" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        n0 = length(ax.scene.plots)
        phylopic_thumbnail_grid!(ax, ["", " "]; image_filter = :clade)
        @test _count_images(ax) == 0
        @test length(ax.scene.plots) == n0
    end

    @testset "image_filter = :node, empty names, blocks layout → no cells" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        n0 = length(ax.scene.plots)
        phylopic_thumbnail_grid!(ax, ["", " "];
            image_filter = :node, image_layout = :blocks)
        @test _count_images(ax) == 0
        @test length(ax.scene.plots) == n0
    end

    @testset "image_layout = :rows, empty names → no cells" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        n0 = length(ax.scene.plots)
        phylopic_thumbnail_grid!(ax, ["", " "]; image_filter = :node, image_layout = :rows)
        @test _count_images(ax) == 0
        @test length(ax.scene.plots) == n0
    end

    @testset "image_layout = :grouped now throws ArgumentError (renamed to :blocks)" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_throws ArgumentError phylopic_thumbnail_grid!(
            ax, ["Tyrannosaurus"]; image_layout = :grouped)
    end

    @testset "image_label = :attribution, empty names → no crash" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_nowarn phylopic_thumbnail_grid!(ax, ["", " "];
            image_filter = :primary, image_label = :attribution)
    end

    @testset "image_label callable, empty names → no crash" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_nowarn phylopic_thumbnail_grid!(ax, ["", " "];
            image_filter = :primary, image_label = (name, k, img) -> "$name-$k")
    end

    @testset "_rows_grid_positions: empty groups → 1×1 grid, no positions" begin
        pos, r, c = PhyloPicMakie._rows_grid_positions(
            Int[]; cell_width = 1.0, cell_height = 1.6)
        @test isempty(pos)
        @test r == 1
        @test c == 1
    end

    @testset "_rows_grid_positions: two groups of sizes [2, 3]" begin
        pos, r, c = PhyloPicMakie._rows_grid_positions(
            [2, 3]; cell_width = 1.0, cell_height = 1.6)
        @test length(pos) == 5   # 2 + 3
        @test r == 2             # two non-empty groups
        @test c == 3             # widest group has 3
    end

    @testset "non-bang: nrows not over-constrained by taxon count (regression)" begin
        # Regression guard: non-bang must not forward its inferred nrows to the
        # bang variant, because when image_filter != :primary the cell count can
        # exceed the taxon count, causing _infer_thumbnail_grid_shape to throw.
        # Empty names produce 0 cells, so this is fully offline.
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_nowarn phylopic_thumbnail_grid!(ax, ["", "", ""];
            image_filter = :primary, ncols = 1, nrows = 1)
    end

    @testset "image_label = :BASICFIELDS (default), empty names → no crash" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_nowarn phylopic_thumbnail_grid!(ax, ["", " "];
            image_filter = :primary, image_label = :BASICFIELDS)
    end

    @testset "image_label = :ALLFIELDS, empty names → no crash" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_nowarn phylopic_thumbnail_grid!(ax, ["", " "];
            image_filter = :primary, image_label = :ALLFIELDS)
    end

    @testset "image_label = :BASICFIELDS, empty names → no crash" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_nowarn phylopic_thumbnail_grid!(ax, ["", " "];
            image_filter = :primary, image_label = :BASICFIELDS)
    end

    @testset "image_label = Vector{Symbol}, empty names → no crash" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        @test_nowarn phylopic_thumbnail_grid!(ax, ["", " "];
            image_filter = :primary, image_label = [:taxon_name, :index, :uuid])
    end

    @testset "labeljoin forwarded through non-bang, empty names → no crash" begin
        @test_nowarn phylopic_thumbnail_grid(["", " "];
            image_filter = :primary, image_label = :BASICFIELDS, labeljoin = " | ")
    end

    @testset "label_lines = 1 suppresses eff_cell_height expansion" begin
        # Empty names → no cells; ymax = 1 row × eff_cell_height.
        # With label_lines = 1, eff_cell_height equals the nominal cell_height.
        fig1 = Figure(); ax1 = Axis(fig1[1, 1])
        phylopic_thumbnail_grid!(ax1, ["", " "]; image_filter = :primary)
        fig2 = Figure(); ax2 = Axis(fig2[1, 1])
        phylopic_thumbnail_grid!(ax2, ["", " "]; image_filter = :primary, label_lines = 1)
        @test ax1.limits[] == ax2.limits[]
    end

    @testset "label_lines = 3 expands eff_cell_height above nominal" begin
        fig = Figure(); ax = Axis(fig[1, 1])
        phylopic_thumbnail_grid!(ax, ["", " "]; image_filter = :primary, label_lines = 3)
        ymax         = ax.limits[][2][2]
        default_cell = PhyloPicMakie.DEFAULT_THUMBNAIL_GRID_CELL_HEIGHT
        @test ymax > default_cell
    end

    @testset "label_lines forwarded through non-bang, empty names → no crash" begin
        @test_nowarn phylopic_thumbnail_grid(["", " "];
            image_filter = :primary, label_lines = 2)
    end

    if !LIVE
        @info "Live thumbnail grid tests skipped. Set ENV[\"PBDB_LIVE\"]=\"1\" to enable."
    else
        @testset "primary filter — one image per taxon" begin
            taxa = ["Tyrannosaurus", "Triceratops", "Ankylosaurus", "Edmontosaurus"]
            fig = Figure(); ax = Axis(fig[1, 1])
            n0 = length(ax.scene.plots)
            phylopic_thumbnail_grid!(ax, taxa;
                image_filter = :primary, glyph_fraction = 0.5,
                ncols = 2, on_missing = :placeholder)
            @test _count_images(ax) == 4
            @test length(ax.scene.plots) ≥ n0 + 8   # 4 images + 4 labels
        end

        @testset "clade filter, :first selector — one cell per taxon" begin
            taxa = ["Tyrannosaurus", "Triceratops"]
            fig = Figure(); ax = Axis(fig[1, 1])
            phylopic_thumbnail_grid!(ax, taxa;
                image_filter = :clade, image_selector = :first,
                on_missing = :placeholder, ncols = 2)
            @test length(ax.scene.plots) ≥ 2
        end

        @testset "clade filter, integer selector — one cell per taxon" begin
            fig = Figure(); ax = Axis(fig[1, 1])
            phylopic_thumbnail_grid!(ax, ["Tyrannosaurus"];
                image_filter = :clade, image_selector = 1,
                on_missing = :placeholder, ncols = 2)
            @test length(ax.scene.plots) ≥ 1
        end

        @testset "node filter, all images, blocks layout" begin
            fig = Figure(); ax = Axis(fig[1, 1])
            phylopic_thumbnail_grid!(ax, ["Tyrannosaurus"];
                image_filter = :node, image_layout = :blocks,
                image_max_pages = 1, on_missing = :placeholder, ncols = 4)
            @test length(ax.scene.plots) ≥ 1
        end

        @testset "callable selector returns list" begin
            fig = Figure(); ax = Axis(fig[1, 1])
            phylopic_thumbnail_grid!(ax, ["Carnivora"];
                image_filter = :clade,
                image_selector = imgs -> isempty(imgs) ? imgs : [imgs[1]],
                image_layout = :flat, image_max_pages = 1, ncols = 4)
            @test length(ax.scene.plots) ≥ 1
        end

        @testset "non-bang constructor returns a Figure" begin
            fig = phylopic_thumbnail_grid(
                ["Tyrannosaurus", "Triceratops", "Ankylosaurus"]; ncols = 2)
            @test fig isa Figure
        end

        @testset "non-bang with clade filter returns a Figure" begin
            fig = phylopic_thumbnail_grid(
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
