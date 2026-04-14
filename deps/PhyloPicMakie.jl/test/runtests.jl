# test/runtests.jl — PhyloPicMakie standalone package tests
#
# Structure:
#   1. Pure-function offline tests (no Makie backend needed):
#      _compute_image_bbox, _apply_rotation, _range_anchor,
#      _infer_thumbnail_grid_shape, _extract_image_field, _join_fields,
#      _build_label
#   2. Makie-level smoke test: _axis_scale_correction_obs (requires CairoMakie)
#   3. Code quality: Aqua + JET

using Test
using PhyloPicMakie
import Makie
using CairoMakie

# PhyloPicDB is a hard dep of PhyloPicMakie and accessible as a nested module.
const PhyloPicDB = PhyloPicMakie.PhyloPicDB

# ---------------------------------------------------------------------------
# 1. Pure-function offline tests
# ---------------------------------------------------------------------------

@testset "PhyloPicMakie — _compute_image_bbox" begin

    @testset ":center placement" begin
        x_lo, x_hi, y_lo, y_hi = PhyloPicMakie._compute_image_bbox(
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
        x_lo, x_hi, _, _ = PhyloPicMakie._compute_image_bbox(
            0.0, 0.0, 8, 4;
            glyph_size = 1.0, aspect = :preserve,
            placement = :left, xoffset = 0.0, yoffset = 0.0,
        )
        @test x_lo ≈ 0.0    # left edge at anchor
        @test x_hi ≈ 4.0
    end

    @testset ":right placement anchors at right edge" begin
        x_lo, x_hi, _, _ = PhyloPicMakie._compute_image_bbox(
            0.0, 0.0, 8, 4;
            glyph_size = 1.0, aspect = :preserve,
            placement = :right, xoffset = 0.0, yoffset = 0.0,
        )
        @test x_hi ≈ 0.0    # right edge at anchor
        @test x_lo ≈ -4.0
    end

    @testset ":stretch aspect makes square" begin
        x_lo, x_hi, y_lo, y_hi = PhyloPicMakie._compute_image_bbox(
            0.0, 0.0, 8, 4;
            glyph_size = 1.0, aspect = :stretch,
            placement = :center, xoffset = 0.0, yoffset = 0.0,
        )
        @test (x_hi - x_lo) ≈ (y_hi - y_lo)
        @test x_lo ≈ -1.0
        @test x_hi ≈  1.0
    end

    @testset "xoffset/yoffset applied after anchoring" begin
        x_lo, x_hi, y_lo, y_hi = PhyloPicMakie._compute_image_bbox(
            0.0, 0.0, 4, 4;
            glyph_size = 1.0, aspect = :preserve,
            placement = :center, xoffset = 5.0, yoffset = 3.0,
        )
        @test x_lo ≈ 4.0
        @test y_lo ≈ 2.0
    end

    @testset "unknown aspect throws ArgumentError" begin
        @test_throws ArgumentError PhyloPicMakie._compute_image_bbox(
            0.0, 0.0, 4, 4;
            glyph_size = 1.0, aspect = :bad,
            placement = :center, xoffset = 0.0, yoffset = 0.0,
        )
    end

    @testset "unknown placement throws ArgumentError" begin
        @test_throws ArgumentError PhyloPicMakie._compute_image_bbox(
            0.0, 0.0, 4, 4;
            glyph_size = 1.0, aspect = :preserve,
            placement = :diagonal, xoffset = 0.0, yoffset = 0.0,
        )
    end

    @testset "axis_scale_correction scales half_w for :preserve" begin
        x_lo1, x_hi1, y_lo1, y_hi1 = PhyloPicMakie._compute_image_bbox(
            0.0, 0.0, 8, 4;
            glyph_size = 1.0, aspect = :preserve,
            placement = :center, xoffset = 0.0, yoffset = 0.0,
            axis_scale_correction = 1.0,
        )
        x_lo2, x_hi2, y_lo2, y_hi2 = PhyloPicMakie._compute_image_bbox(
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
        x_lo1, x_hi1, _, _ = PhyloPicMakie._compute_image_bbox(
            0.0, 0.0, 8, 4;
            glyph_size = 1.0, aspect = :stretch,
            placement = :center, xoffset = 0.0, yoffset = 0.0,
            axis_scale_correction = 1.0,
        )
        x_lo2, x_hi2, _, _ = PhyloPicMakie._compute_image_bbox(
            0.0, 0.0, 8, 4;
            glyph_size = 1.0, aspect = :stretch,
            placement = :center, xoffset = 0.0, yoffset = 0.0,
            axis_scale_correction = 3.0,
        )
        @test x_lo1 ≈ x_lo2
        @test x_hi1 ≈ x_hi2
    end

end  # _compute_image_bbox

@testset "PhyloPicMakie — _apply_rotation" begin
    img = collect(reshape(1:8, 2, 4))   # 2 rows × 4 cols

    @testset "0° is identity" begin
        @test PhyloPicMakie._apply_rotation(img, 0.0) === img
    end

    @testset "90° changes dimensions" begin
        @test size(PhyloPicMakie._apply_rotation(img, 90.0)) == (4, 2)
    end

    @testset "180° same dimensions" begin
        @test size(PhyloPicMakie._apply_rotation(img, 180.0)) == (2, 4)
    end

    @testset "270° equals -90°" begin
        @test PhyloPicMakie._apply_rotation(img, 270.0) == PhyloPicMakie._apply_rotation(img, -90.0)
    end

    @testset "non-multiple-of-90 throws ArgumentError" begin
        @test_throws ArgumentError PhyloPicMakie._apply_rotation(img, 45.0)
        @test_throws ArgumentError PhyloPicMakie._apply_rotation(img, 1.0)
    end
end  # _apply_rotation

@testset "PhyloPicMakie — _range_anchor" begin
    @test PhyloPicMakie._range_anchor(10.0, 20.0, :start)    ≈ 10.0
    @test PhyloPicMakie._range_anchor(10.0, 20.0, :stop)     ≈ 20.0
    @test PhyloPicMakie._range_anchor(10.0, 20.0, :midpoint) ≈ 15.0
    @test_throws ArgumentError PhyloPicMakie._range_anchor(10.0, 20.0, :unknown)
end

@testset "PhyloPicMakie — _infer_thumbnail_grid_shape" begin
    @test PhyloPicMakie._infer_thumbnail_grid_shape(0) == (1, 1)
    @test PhyloPicMakie._infer_thumbnail_grid_shape(1) == (1, 1)
    @test PhyloPicMakie._infer_thumbnail_grid_shape(6) == (3, 2)
    @test PhyloPicMakie._infer_thumbnail_grid_shape(17) == (4, 5)
    @test PhyloPicMakie._infer_thumbnail_grid_shape(6; ncols = 2) == (2, 3)
    @test PhyloPicMakie._infer_thumbnail_grid_shape(6; nrows = 2) == (3, 2)
    @test_throws ArgumentError PhyloPicMakie._infer_thumbnail_grid_shape(6; ncols = 0)
    @test_throws ArgumentError PhyloPicMakie._infer_thumbnail_grid_shape(6; ncols = 2, nrows = 2)
end

@testset "PhyloPicMakie — _extract_image_field" begin
    null_img = PhyloPicDB._null_image(1)

    @testset "virtual field :taxon_name" begin
        @test PhyloPicMakie._extract_image_field(:taxon_name, "Felidae", 3, null_img) == "Felidae"
    end

    @testset "virtual field :index" begin
        @test PhyloPicMakie._extract_image_field(:index, "Felidae", 3, null_img) == "3"
    end

    @testset ":node_name nothing on null image" begin
        @test isnothing(PhyloPicMakie._extract_image_field(:node_name, "Felidae", 1, null_img))
    end

    @testset ":uuid always returns a String (empty for null image)" begin
        val = PhyloPicMakie._extract_image_field(:uuid, "Felidae", 1, null_img)
        @test val isa String
    end

    @testset ":attribution missing on null image" begin
        @test ismissing(PhyloPicMakie._extract_image_field(:attribution, "Felidae", 1, null_img))
    end

    @testset ":license missing on null image" begin
        @test ismissing(PhyloPicMakie._extract_image_field(:license, "Felidae", 1, null_img))
    end

    @testset ":specific_node_uuid nothing on null image" begin
        @test isnothing(PhyloPicMakie._extract_image_field(:specific_node_uuid, "Felidae", 1, null_img))
    end

    @testset "unknown symbol throws ArgumentError" begin
        @test_throws ArgumentError PhyloPicMakie._extract_image_field(:notafield, "Felidae", 1, null_img)
    end
end

@testset "PhyloPicMakie — _join_fields" begin
    null_img = PhyloPicDB._null_image(1)

    @testset "virtual-only fields always present" begin
        result = PhyloPicMakie._join_fields([:taxon_name, :index], "Felidae", 2, null_img, " | ")
        @test result == "Felidae | 2"
    end

    @testset "missing structural field skipped" begin
        result = PhyloPicMakie._join_fields([:taxon_name, :attribution], "Felidae", 1, null_img, "\n")
        @test result == "Felidae"
    end

    @testset "nothing structural field skipped" begin
        result = PhyloPicMakie._join_fields([:taxon_name, :node_name], "Felidae", 1, null_img, "\n")
        @test result == "Felidae"
    end

    @testset "empty uuid skipped" begin
        result = PhyloPicMakie._join_fields([:taxon_name, :uuid], "Felidae", 1, null_img, "\n")
        @test result == "Felidae"
    end

    @testset "empty field list → empty string" begin
        @test PhyloPicMakie._join_fields(Symbol[], "Felidae", 1, null_img, "\n") == ""
    end

    @testset "custom separator respected" begin
        result = PhyloPicMakie._join_fields([:taxon_name, :index], "Carnivora", 5, null_img, " :: ")
        @test result == "Carnivora :: 5"
    end
end

@testset "PhyloPicMakie — _build_label" begin
    null_img = PhyloPicDB._null_image(1)

    @testset "nothing, single-image group → name only" begin
        @test PhyloPicMakie._build_label("Felidae", 1, false, null_img, nothing, "\n") == "Felidae"
    end

    @testset "nothing, multi-image group → name [k]" begin
        @test PhyloPicMakie._build_label("Felidae", 3, true, null_img, nothing, "\n") == "Felidae [3]"
    end

    @testset ":BASICFIELDS is [:index, :node_name, :taxon_name]; node_name absent on null" begin
        result = PhyloPicMakie._build_label("Felidae", 2, true, null_img, :BASICFIELDS, " | ")
        @test result == "2 | Felidae"
    end

    @testset "Vector{Symbol}: missing/nothing fields dropped, labeljoin used" begin
        @test PhyloPicMakie._build_label("Felidae", 1, false, null_img, [:taxon_name, :attribution], "\n") == "Felidae"
        @test PhyloPicMakie._build_label("Carnivora", 3, true, null_img, [:taxon_name, :index], " — ") == "Carnivora — 3"
    end

    @testset "single known symbol missing/nothing → falls back to default" begin
        @test PhyloPicMakie._build_label("Felidae", 1, false, null_img, :attribution, "\n") == "Felidae"
        @test PhyloPicMakie._build_label("Felidae", 2, true,  null_img, :attribution, "\n") == "Felidae [2]"
        @test PhyloPicMakie._build_label("Felidae", 1, false, null_img, :node_name, "\n") == "Felidae"
        @test PhyloPicMakie._build_label("Felidae", 3, true,  null_img, :node_name, "\n") == "Felidae [3]"
    end

    @testset "callable receives name, k, img" begin
        f = (name, k, img) -> "$(name):$(k)"
        @test PhyloPicMakie._build_label("Felidae", 7, true, null_img, f, "\n") == "Felidae:7"
    end

    @testset "unknown Symbol throws ArgumentError" begin
        @test_throws ArgumentError PhyloPicMakie._build_label("Felidae", 1, false, null_img, :notafield, "\n")
    end
end

# ---------------------------------------------------------------------------
# 2. Makie-level smoke test
# ---------------------------------------------------------------------------

@testset "PhyloPicMakie — _axis_scale_correction_obs" begin
    # CairoMakie loaded above; Figure + Axis are available.
    # Before the figure is displayed the projectionview may be degenerate,
    # in which case _axis_scale_correction_obs returns the safe default 1.0.
    fig = Figure()
    ax  = Axis(fig[1, 1])
    obs = PhyloPicMakie._axis_scale_correction_obs(ax.scene)
    @test obs isa Makie.Observable
    sc = obs[]
    @test sc isa Float64
    @test sc > 0.0
end

# ---------------------------------------------------------------------------
# 3. Code quality
# ---------------------------------------------------------------------------

@testset "PhyloPicMakie — Aqua" begin
    Aqua.test_all(PhyloPicMakie)
end

@testset "PhyloPicMakie — JET" begin
    JET.test_package(PhyloPicMakie; target_defined_modules = true)
end
