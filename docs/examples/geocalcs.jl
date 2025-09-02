export distance_stats, haversine_deg

# -- Great-circle (haversine) distance on a sphere with inputs in degrees --
"""
    haversine_deg(λ1, ϕ1, λ2, ϕ2; radius_km=6371.0088)

Great-circle distance (km) between (lon, lat) points given in degrees.
Longitude wrap-around at ±180° is handled via normalized Δλ ∈ [-π, π].
"""
function haversine_deg(λ1::Real, ϕ1::Real, λ2::Real, ϕ2::Real; radius_km::Float64=6371.0088)
    deg2rad = π / 180.0
    λ1r = float(λ1) * deg2rad
    ϕ1r = float(ϕ1) * deg2rad
    λ2r = float(λ2) * deg2rad
    ϕ2r = float(ϕ2) * deg2rad

    # normalize Δλ to [-π, π]
    Δλ = mod(λ2r - λ1r + π, 2π) - π
    Δϕ = ϕ2r - ϕ1r

    s = sin(Δϕ/2)^2 + cos(ϕ1r)*cos(ϕ2r)*sin(Δλ/2)^2
    s = clamp(s, 0.0, 1.0)
    c = 2 * asin(sqrt(s))
    return radius_km * c
end

# -- Internal: compute summary stats over a Vector{Float64} of distances --
@inline function _summarize(dists::Vector{Float64})
    npairs = length(dists)
    @assert npairs > 0 "no distances to summarize"

    # min/max/mean in one pass
    mn = dists[1]; mx = dists[1]; tot = 0.0
    @inbounds for d in dists
        d < mn && (mn = d)
        d > mx && (mx = d)
        tot += d
    end
    meanv = tot / npairs

    sort!(dists)
    medianv = if isodd(npairs)
        dists[(npairs + 1) >>> 1]
    else
        i = npairs >>> 1
        (dists[i] + dists[i+1]) / 2
    end

    return mn, mx, meanv, medianv, npairs
end

# -- API 1: Lon/Lat specialization with pluggable distance function --
"""
    distance_stats(lon::AbstractVector{<:Real}, lat::AbstractVector{<:Real};
                   dist=:haversine_deg, radius_km::Float64=6371.0088)

Compute pairwise distance summary statistics (min, max, mean, median) for geographic points.

Arguments
- `lon`, `lat`: vectors (same length) of longitudes and latitudes in degrees.
- `dist`: either
    * `:haversine_deg` (default), or
    * a callable `f(λ1, ϕ1, λ2, ϕ2) -> distance` (units determined by `f`).
- `radius_km`: sphere radius for `:haversine_deg` (ignored otherwise).

Returns a `NamedTuple`:
`(min = …, max = …, mean = …, median = …, n_points = …, n_pairs = …)`
"""
function distance_stats(lon::AbstractVector{<:Real}, lat::AbstractVector{<:Real};
                        dist=:haversine_deg, radius_km::Float64=6371.0088)
    length(lon) == length(lat) || throw(ArgumentError("lon and lat must have the same length"))
    n = length(lon)
    n < 2 && throw(ArgumentError("need at least 2 points"))

    # Filter invalid (NaN) pairs
    L = Float64[]; B = Float64[]
    @inbounds for i in 1:n
        λ = float(lon[i]); ϕ = float(lat[i])
        if !(isnan(λ) || isnan(ϕ))
            push!(L, λ); push!(B, ϕ)
        end
    end
    nvalid = length(L)
    nvalid < 2 && throw(ArgumentError("need at least 2 valid points (after removing NaNs), got $nvalid"))

    # Choose metric
    metric = dist === :haversine_deg ? ( (aλ,aϕ,bλ,bϕ)->haversine_deg(aλ,aϕ,bλ,bϕ; radius_km=radius_km) ) :
             (dist isa Function ? dist :
              throw(ArgumentError("`dist` must be :haversine_deg or a callable (λ1,ϕ1,λ2,ϕ2)->distance")))

    # Collect upper-triangle distances
    npairs = nvalid * (nvalid - 1) ÷ 2
    dists = Vector{Float64}(undef, npairs)
    k = 1
    @inbounds for i in 1:(nvalid-1)
        λi = L[i]; ϕi = B[i]
        for j in (i+1):nvalid
            dists[k] = metric(λi, ϕi, L[j], B[j])
            k += 1
        end
    end

    mn, mx, meanv, medianv, _ = _summarize(dists)
    return (min = mn, max = mx, mean = meanv, median = medianv,
            n_points = nvalid, n_pairs = npairs)
end

# -- API 2: Generic coordinates with arbitrary metrics (e.g., Distances.jl) --
"""
    distance_stats(X::AbstractMatrix{<:Real}; metric)

Compute summary statistics of pairwise distances between rows of `X` using `metric`.

- `X`: matrix with observations in rows (size `n × d`).
  Rows with any `NaN` are dropped.
- `metric`: any callable two-argument function `metric(a::AbstractVector, b::AbstractVector)`
  returning a real distance. This includes metrics from Distances.jl
  (e.g., `Distances.Euclidean()`), which are callable.

Returns a `NamedTuple`:
`(min = …, max = …, mean = …, median = …, n_points = …, n_pairs = …)`
"""
function distance_stats(X::AbstractMatrix{<:Real}; metric)
    n, d = size(X)
    n < 2 && throw(ArgumentError("need at least 2 points"))
    # Keep rows without NaN
    keep = trues(n)
    @inbounds for i in 1:n
        for j in 1:d
            if isnan(float(X[i,j]))
                keep[i] = false
                break
            end
        end
    end
    idx = findall(keep)
    nvalid = length(idx)
    nvalid < 2 && throw(ArgumentError("need at least 2 valid points (after removing NaNs), got $nvalid"))

    # Materialize valid rows as vectors of length d
    pts = [view(X, idx[i], :) for i in 1:nvalid]

    # Metric must be callable
    (metric isa Function) || throw(ArgumentError("`metric` must be a callable (a, b)->distance"))

    # Pairwise distances
    npairs = nvalid * (nvalid - 1) ÷ 2
    dists = Vector{Float64}(undef, npairs)
    k = 1
    @inbounds for i in 1:(nvalid-1)
        ai = pts[i]
        for j in (i+1):nvalid
            dists[k] = metric(ai, pts[j])
            k += 1
        end
    end

    mn, mx, meanv, medianv, _ = _summarize(dists)
    return (min = mn, max = mx, mean = meanv, median = medianv,
            n_points = nvalid, n_pairs = npairs)
end

# ---------------------------------------------------------------------------
# Example usage:
# lon = [170.0, -170.0, 0.0, 45.0]
# lat = [ 10.0,  -10.0, 0.0, 30.0]
# distance_stats(lon, lat)  # default haversine (km)
#
# using Distances
# X = randn(5, 3)
# distance_stats(X; metric=Distances.Euclidean())
# ---------------------------------------------------------------------------