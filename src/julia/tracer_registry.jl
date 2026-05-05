# tracer_registry.jl
#
# Canonical definitions for MOST scalar tracers: physics, sign conventions,
# and default baseline parameters.  Include this file in any script that needs
# tracer-aware behaviour:
#
#   include(joinpath(@__DIR__, "tracer_registry.jl"))
#
# This file has no side-effects beyond defining constants/types/functions.

# ─────────────────────────────── Regime taxonomy ─────────────────────────────

"""
Regime bins used throughout the multi-tracer pipeline.

Labels
  :unstable        — ζ < 0  (or Ri_g < 0)
  :near_neutral    — |ζ| ≤ ζ_neutral_max  (straddles ζ = 0)
  :weakly_stable   — ζ > 0, Ri_g < Ri_c
  :strongly_stable — ζ > 0, Ri_g ≥ Ri_c

When Ri_g is not available the ζ-only fallback assumes the linear-stable
approximation  Ri_g ≈ ζ,  which is accurate for |ζ| ≲ 0.5 and gives
Ri_c = 0.25 → ζ_c = 0.25.
"""
const DEFAULT_RIC          = 0.25
const DEFAULT_ZETA_NEUTRAL = 0.1

"""
    assign_regime(ζ, Ri_g=NaN; ric, zeta_neutral) → Symbol

Returns one of :unstable, :near_neutral, :weakly_stable, :strongly_stable.
`Ri_g` = gradient Richardson number; pass NaN to use the ζ-only fallback.
"""
function assign_regime(zeta::Float64, rig::Float64 = NaN;
                       ric::Float64 = DEFAULT_RIC,
                       zeta_neutral::Float64 = DEFAULT_ZETA_NEUTRAL)
    isfinite(zeta) || return :invalid
    abs(zeta) ≤ zeta_neutral && return :near_neutral
    zeta < 0.0              && return :unstable
    # Stable branch
    stable_strong = isfinite(rig) ? (rig ≥ ric) : (zeta ≥ ric)
    return stable_strong ? :strongly_stable : :weakly_stable
end

assign_regime(zeta, rig = NaN; kwargs...) =
    assign_regime(Float64(zeta), isnan(rig) ? NaN : Float64(rig); kwargs...)

"""
Apply `assign_regime` to whole vectors.  Returns a `Vector{Symbol}`.
"""
function assign_regimes(zeta::AbstractVector, rig::AbstractVector = fill(NaN, length(zeta));
                        ric::Float64 = DEFAULT_RIC,
                        zeta_neutral::Float64 = DEFAULT_ZETA_NEUTRAL)
    return [assign_regime(Float64(zeta[i]), Float64(rig[i]); ric, zeta_neutral)
            for i in eachindex(zeta)]
end

const REGIME_ORDER = [:unstable, :near_neutral, :weakly_stable, :strongly_stable]

const REGIME_DISPLAY = Dict{Symbol, String}(
    :unstable        => "Unstable  (ζ < 0)",
    :near_neutral    => "Near-neutral  (|ζ| ≤ $(DEFAULT_ZETA_NEUTRAL))",
    :weakly_stable   => "Weakly stable  (0 < ζ, Ri < Ri_c)",
    :strongly_stable => "Strongly stable  (Ri ≥ Ri_c)",
    :invalid         => "Invalid / missing",
)

const REGIME_COLOR = Dict{Symbol, Symbol}(
    :unstable        => :royalblue,
    :near_neutral    => :forestgreen,
    :weakly_stable   => :darkorange,
    :strongly_stable => :firebrick,
)

# ────────────────────────────── Tracer definition ─────────────────────────────

"""
Full specification of a MOST scalar tracer.

Fields
  id                   Canonical identifier (e.g. :momentum, :heat, :q1).
  display              Human-readable label.
  phi_col              Column name for this tracer's φ in the multi-tracer CSV.
  scale_var            Name of the scale variable (u_*, θ_*, q_*).
  sign_note            Warning about sign conventions to check for this tracer.
  lambda_unstable      Exponent in the Businger-Dyer unstable baseline:
                         φ_u(ζ) = (1 − b·ζ)^{−1/λ}
                       λ = 4 → momentum  (dyer 1974, Businger 1971)
                       λ = 2 → heat/scalar
  b_unstable_default   Canonical b for the unstable baseline (typical: 16).
  a_stable_default     Grachev linear slope default (neutral slope tie = a_s = b_u/λ).
  b_stable_default     Grachev curvature parameter default.
  phi_lo, phi_hi       Plausible physical bounds for QC (values outside are flagged).
  wflux_eps            Minimum absolute turbulent flux below which phi is unreliable.
"""
struct TracerDef
    id                  :: Symbol
    display             :: String
    phi_col             :: Symbol
    scale_var           :: String
    sign_note           :: String
    lambda_unstable     :: Float64
    b_unstable_default  :: Float64
    a_stable_default    :: Float64
    b_stable_default    :: Float64
    phi_lo              :: Float64
    phi_hi              :: Float64
    wflux_eps           :: Float64
end

const TRACER_REGISTRY = Dict{Symbol, TracerDef}(

    :momentum => TracerDef(
        :momentum,
        "Momentum  φ_m",
        :phi_m,
        "u_*",
        "phi_m is always positive; u_* is always positive — no sign ambiguity.",
        4.0, 16.0,     # λ=4 → (1-16ζ)^{-1/4}  Businger 1971 / Dyer 1974
        5.0, 5.0,      # Grachev stable defaults
        0.5, 100.0, 1e-12,
    ),

    :heat => TracerDef(
        :heat,
        "Heat  φ_h",
        :phi_h,
        "θ_*",
        "θ_* = −w′θ_v′/u_* (positive in stable). " *
        "Check that your sonic has the correct sign for w′θ_v′.",
        2.0, 16.0,     # λ=2 → (1-16ζ)^{-1/2}  Businger 1971
        5.0, 5.0,
        0.5, 100.0, 1e-12,
    ),

)

"""
    generic_tracer(id; kwargs...) → TracerDef

Construct a TracerDef for an arbitrary tracer q_k not in the built-in registry.
Defaults to heat-like behaviour (λ = 2) — override with `lambda_unstable`.
"""
function generic_tracer(id::Symbol;
                        display::String          = "Tracer $(id)",
                        phi_col::Symbol          = Symbol("phi_$(id)"),
                        scale_var::String        = "$(id)_*",
                        sign_note::String        = "Verify sign convention: both the " *
                                                   "turbulent flux w′$(id)′ and the " *
                                                   "mean gradient d$(id)/dz must be checked.",
                        lambda_unstable::Float64 = 2.0,
                        b_unstable_default::Float64 = 16.0,
                        a_stable_default::Float64   = 5.0,
                        b_stable_default::Float64   = 5.0,
                        phi_lo::Float64   = 0.1,
                        phi_hi::Float64   = 200.0,
                        wflux_eps::Float64 = 1e-6)
    return TracerDef(id, display, phi_col, scale_var, sign_note,
                     lambda_unstable, b_unstable_default,
                     a_stable_default, b_stable_default,
                     phi_lo, phi_hi, wflux_eps)
end

"""
    get_tracer(id; kwargs...) → TracerDef

Look up a built-in tracer or fall back to `generic_tracer`.
"""
get_tracer(id::Symbol; kwargs...) =
    haskey(TRACER_REGISTRY, id) ? TRACER_REGISTRY[id] : generic_tracer(id; kwargs...)

# ──────────────────────────── φ physics helpers ───────────────────────────────

"""
    phi_unstable_baseline(ζ, b, λ) → Float64

Businger-Dyer unstable baseline:  φ_u(ζ) = (1 − b·ζ)^{−1/λ}

Valid for ζ < 0 (argument 1−b·ζ > 1 since b > 0, ζ < 0).
"""
phi_unstable_baseline(zeta, b, lambda) =
    max(1.0 - b * zeta, 1e-8)^(-1.0 / lambda)

"""
    phi_stable_baseline(ζ, a_s, b_s) → Float64

Grachev et al. (2007) stable baseline:
  φ_s(ζ) = 1 + a_s·ζ·(1+ζ)^{1/3} / (1 + b_s·ζ)

Neutral slope at ζ=0: dφ_s/dζ|₀ = a_s.
C¹ tie to unstable baseline: a_s = b_u / λ_u.
"""
phi_stable_baseline(zeta, a_s, b_s) =
    1.0 + a_s * zeta * max(1.0 + zeta, 1e-8)^(1.0/3.0) / max(1.0 + b_s * zeta, 1e-8)

"""
    phi_baseline(ζ, tracer::TracerDef) → Float64

Evaluate the canonical blended baseline for a tracer at stability ζ,
using the registry default parameters and a sigmoid blend at ζ = 0.
"""
function phi_baseline(zeta::Float64, t::TracerDef; delta::Float64 = 0.1)
    s  = 0.5 * (1.0 + tanh(zeta / delta))
    pu = phi_unstable_baseline(zeta, t.b_unstable_default, t.lambda_unstable)
    # Clip the stable formula to ζ ≥ 0 to avoid its singularity on the
    # negative-ζ side (Grachev denominator 1 + b_s·ζ → 0 at ζ = −1/b_s ≈ −0.2).
    ps = phi_stable_baseline(max(zeta, 0.0), t.a_stable_default, t.b_stable_default)
    return (1.0 - s) * pu + s * ps
end

# ──────────────────────────── Regime stats helper ─────────────────────────────

"""
    regime_stats(zeta, phi, rig=nothing; ric, zeta_neutral) → DataFrame

Compute per-regime summary statistics for a single tracer's (ζ, φ_obs) pairs.
Returns a DataFrame with one row per regime.
"""
function regime_stats(zeta::AbstractVector{Float64},
                      phi::AbstractVector{Float64},
                      rig::Union{Nothing, AbstractVector{Float64}} = nothing;
                      ric::Float64 = DEFAULT_RIC,
                      zeta_neutral::Float64 = DEFAULT_ZETA_NEUTRAL,
                      tracer_id::String = "unknown")
    using_rig = rig !== nothing
    rig_vec   = using_rig ? rig : fill(NaN, length(zeta))
    regimes   = assign_regimes(zeta, rig_vec; ric, zeta_neutral)

    rows = []
    for lab in REGIME_ORDER
        mask = findall(r -> r == lab, regimes)
        n    = length(mask)
        if n == 0
            push!(rows, (tracer=tracer_id, regime=String(lab),
                         n_obs=0,
                         zeta_q05=NaN, zeta_q50=NaN, zeta_q95=NaN,
                         phi_mean=NaN, phi_std=NaN,
                         phi_q05=NaN, phi_q50=NaN, phi_q95=NaN, phi_iqr=NaN,
                         rig_q50=NaN))
            continue
        end
        zv  = zeta[mask];  pv = phi[mask]
        rv  = using_rig ? rig_vec[mask] : fill(NaN, n)
        push!(rows, (
            tracer   = tracer_id,
            regime   = String(lab),
            n_obs    = n,
            zeta_q05 = quantile(zv, 0.05),
            zeta_q50 = quantile(zv, 0.50),
            zeta_q95 = quantile(zv, 0.95),
            phi_mean = mean(pv),
            phi_std  = std(pv),
            phi_q05  = quantile(pv, 0.05),
            phi_q50  = quantile(pv, 0.50),
            phi_q95  = quantile(pv, 0.95),
            phi_iqr  = quantile(pv, 0.75) - quantile(pv, 0.25),
            rig_q50  = all(isnan.(rv)) ? NaN : quantile(filter(isfinite, rv), 0.50),
        ))
    end
    return DataFrame(rows)
end
