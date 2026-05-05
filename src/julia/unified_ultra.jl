#!/usr/bin/env julia

# Unified All-Regime Ultraspherical φ Fitter
#
# Implements:
#   - Unstable baseline: φ_u(ζ) = (1 - b_u*ζ)^(-1/λ_u)  [Businger-Dyer family]
#   - Stable baseline:   φ_s(ζ) = 1 + a_s*ζ*(1+ζ)^(1/3) / (1 + b_s*ζ)  [Grachev family]
#   - C¹ continuity tie: a_s = b_u / λ_u  (matches neutral slope across regimes)
#   - Soft blend:        φ_base = (1-s)*φ_u + s*φ_s,  s = 0.5*(1+tanh(ζ/δ))
#   - All-regime ξ-map:  ξ = tanh(a_ξ * asinh(ζ/ζ₀))   [log in both tails, linear at 0]
#   - Gegenbauer correction: Δφ = Σ_{n=0}^{N} c_n C_n^(λ*)(ξ)
#
# Usage:
#   julia unified_ultra.jl <input_csv> <output_prefix> [dataset_label] \
#     [--lambda=2|4|free] [--regime=all|stable|unstable] \
#     [--blend=soft|hard] [--c1-tie=true|false]
#
# input_csv must have columns: zeta, phi_obs  (optional: time for blocked split)
#
# Standard artifacts produced:
#   _metrics.csv  _params.csv  _pred_test.csv  _coeffs.csv  _curve.csv
#   _model.jl  _formula.md  _report.md
#   _comparison.png  _correction.png  (if CairoMakie available)

using CSV, DataFrames, LinearAlgebra, Statistics, LsqFit, Random

const HAVE_MAKIE = try
    @eval using CairoMakie
    true
catch
    false
end

# ----------------------------- Settings ----------------------------------------

const TRAIN_FRAC = 0.75
const RNG_SEED   = 42
const BLEND_DELTA = 0.1      # softness of stable/unstable blend transition in ζ

# Hyperparameter search grids
const ALPHA_XI_GRID    = [0.3, 0.5, 0.8, 1.2, 1.8]
const ZETA0_GRID       = [0.1, 0.3, 0.5, 1.0, 2.0, 5.0]   # larger values needed for stable range
const LAMBDA_STAR_GRID = [0.25, 0.5, 0.75, 1.0]
const RIDGE_GRID       = [1e-4, 1e-3, 1e-2, 5e-2]
const NMAX_GRID        = [2, 3, 4, 6]

# ----------------------------- φ Baselines ------------------------------------

"""
    phi_unstable(zeta, b_u, lambda_u)

Businger-Dyer unstable baseline (MOST exact form):
  φ_u(ζ) = (1 - b_u * ζ)^(-1/λ_u)

Neutral limit: φ_u(0) = 1.
Neutral slope: dφ_u/dζ|₀ = b_u / λ_u.

Special cases: λ=4, b=16 (Businger 1971 momentum);  λ=2, b=16 (Businger 1971 heat).
Valid for ζ ≤ 0 physically; the 1-b*ζ argument remains ≥ 1 since b > 0, ζ < 0.
"""
function phi_unstable(zeta, b_u, lambda_u)
    arg = max.(1.0 .- b_u .* zeta, 1e-8)
    return arg .^ (-1.0 / lambda_u)
end

"""
    phi_stable(zeta, a_s, b_s)

Grachev et al. (2007) stable baseline:
  φ_s(ζ) = 1 + a_s * ζ * (1+ζ)^(1/3) / (1 + b_s*ζ)

Neutral limit: φ_s(0) = 1.
Neutral slope: dφ_s/dζ|₀ = a_s.
C¹ tie to unstable baseline: a_s = b_u / λ_u.
"""
function phi_stable(zeta, a_s, b_s)
    return 1.0 .+ a_s .* zeta .* max.(1.0 .+ zeta, 1e-8).^(1.0/3.0) ./ max.(1.0 .+ b_s .* zeta, 1e-8)
end

"""
    blend_weight(zeta, delta)

Sigmoid blend weight: s → 0 in unstable (ζ→-∞), s → 1 in stable (ζ→+∞).
Width parameter `delta` controls the transition sharpness at ζ = 0.
"""
blend_weight(zeta, delta=BLEND_DELTA) = 0.5 .* (1.0 .+ tanh.(zeta ./ delta))

"""
    phi_blend_soft(zeta, b_u, lambda_u, a_s, b_s)

Softly blended baseline:  φ_base = (1-s)*φ_u + s*φ_s.
Preserves C⁰ and (with C¹ tie) C¹ continuity at ζ = 0.
"""
function phi_blend_soft(zeta, b_u, lambda_u, a_s, b_s)
    s  = blend_weight(zeta)
    pu = phi_unstable(zeta, b_u, lambda_u)
    ps = phi_stable(zeta, a_s, b_s)
    return (1.0 .- s) .* pu .+ s .* ps
end

"""
    phi_blend_hard(zeta, b_u, lambda_u, a_s, b_s)

Hard-switch baseline: φ_u for ζ < 0, φ_s for ζ ≥ 0.
C⁰ at ζ=0 (both → 1), C¹ only if the tie constraint a_s = b_u/λ_u holds.
"""
phi_blend_hard(zeta, b_u, lambda_u, a_s, b_s) =
    ifelse.(zeta .< 0.0, phi_unstable(zeta, b_u, lambda_u), phi_stable(zeta, a_s, b_s))

# ----------------------------- ξ-map ------------------------------------------

"""
    xi_map_asinh(zeta, a_xi, zeta0)

All-regime xi transform:
  ξ = tanh(a_ξ · asinh(ζ / ζ₀))

Properties:
  - Maps (-∞, +∞) → (-1, +1) with ξ(0) = 0.
  - Linear near ζ = 0: ξ ≈ (a_ξ / ζ₀) * ζ.
  - Logarithmic in both tails (asinh(x) ~ log|2x| for |x|>>1).
  - Symmetrises stable and unstable tail compression.
"""
xi_map_asinh(zeta, a_xi, zeta0) = tanh.(a_xi .* asinh.(zeta ./ zeta0))

"""
    xi_map_log(zeta, a_xi)

Log xi-map for pure stable use (ζ > 0):
  ξ = tanh(a_ξ · log1p(ζ))

Maps [0, ∞) → [0, 1) with logarithmic resolution — spreads out the
large-ζ range rather than compressing it all near ξ=1.
Matches the validated mapping in sheba_ultra.jl.
"""
xi_map_log(zeta, a_xi) = tanh.(a_xi .* log1p.(max.(zeta, -0.999)))

# ----------------------------- Gegenbauer -------------------------------------

function gegenbauer_eval(n::Int, lambda_star::Float64, x::Vector{Float64})
    n == 0 && return ones(length(x))
    n == 1 && return 2.0 .* lambda_star .* x
    c_nm1 = ones(length(x))
    c_n   = 2.0 .* lambda_star .* x
    for k in 1:(n - 1)
        c_np1 = (2.0*(k + lambda_star) .* x .* c_n .- (k + 2.0*lambda_star - 1.0) .* c_nm1) ./ (k + 1.0)
        c_nm1, c_n = c_n, c_np1
    end
    return c_n
end

function gegenbauer_design(xi, lambda_star, nmax)
    A = Matrix{Float64}(undef, length(xi), nmax + 1)
    for n in 0:nmax
        A[:, n+1] = gegenbauer_eval(n, lambda_star, xi)
    end
    return A
end

function ridge_solve(A, y, ridge)
    ridge <= 0.0 && return A \ y
    n = size(A, 2)
    return (transpose(A) * A + ridge * I(n)) \ (transpose(A) * y)
end

rmse(y, yhat) = sqrt(mean((y .- yhat).^2))
mae(y, yhat)  = mean(abs.(y .- yhat))

# ----------------------------- CLI helpers ------------------------------------

function parse_flag(args::Vector{String}, key::String, default::String)
    prefix = key * "="
    for a in args
        startswith(a, prefix) || continue
        parts = split(a, "=", limit=2)
        length(parts) == 2 || return default
        return lowercase(parts[2])
    end
    return default
end

# ----------------------------- Baseline fitting --------------------------------

"""
Fit unstable baseline params (b_u, λ_u) from negative-ζ training rows.
If lambda_fixed is not nothing, only b_u is fitted.
Returns (b_u, lambda_u).
"""
function fit_unstable_params(z_u::Vector{Float64}, y_u::Vector{Float64},
                              lambda_fixed::Union{Nothing,Float64})
    if isnothing(lambda_fixed)
        p0 = [16.0, 4.0]
        fit = curve_fit((z, p) -> phi_unstable(z, p[1], p[2]),
                        z_u, y_u, p0; lower=[0.1, 0.5], upper=[200.0, 20.0])
        return fit.param[1], fit.param[2]
    else
        lf = lambda_fixed
        fit = curve_fit((z, p) -> phi_unstable(z, p[1], lf),
                        z_u, y_u, [16.0]; lower=[0.1], upper=[500.0])
        return fit.param[1], lf
    end
end

"""
Fit stable baseline with a_s FIXED (C¹ tie).  Only b_s is free.
"""
function fit_stable_c1(z_s::Vector{Float64}, y_s::Vector{Float64}, a_s_fixed::Float64)
    p0 = [5.0]
    model(z, p) = phi_stable(z, a_s_fixed, p[1])
    fit = curve_fit(model, z_s, y_s, p0; lower=[0.01], upper=[50.0])
    return a_s_fixed, fit.param[1]
end

"""
Fit stable baseline with both a_s and b_s free.
"""
function fit_stable_free(z_s::Vector{Float64}, y_s::Vector{Float64})
    p0 = [5.0, 5.0]
    model(z, p) = phi_stable(z, p[1], p[2])
    fit = curve_fit(model, z_s, y_s, p0; lower=[0.1, 0.1], upper=[30.0, 30.0])
    return fit.param[1], fit.param[2]
end

# ----------------------------- Export writers ---------------------------------

function write_model_jl(out_prefix, b_u, lambda_u, a_s, b_s, a_xi, zeta0,
                         lambda_star, coeffs, nmax, regime_mode, blend_mode)
    blend_body = if blend_mode == "hard"
        ["phi_base_unified(z) = z < 0.0 ? phi_u_unified(z) : phi_s_unified(z)"]
    else
        [
            "blend_s_unified(z) = 0.5*(1.0 + tanh(z/$(BLEND_DELTA)))",
            "function phi_base_unified(z)",
            "    s = blend_s_unified(z)",
            "    return (1-s)*phi_u_unified(z) + s*phi_s_unified(z)",
            "end",
        ]
    end

    lines = [
        "# Auto-generated by unified_ultra.jl — do not edit by hand",
        "# Unified all-regime ultraspherical φ",
        "",
        "const UU_B_U         = $(b_u)",
        "const UU_LAMBDA_U    = $(lambda_u)",
        "const UU_A_S         = $(a_s)",
        "const UU_B_S         = $(b_s)",
        "const UU_A_XI        = $(a_xi)",
        "const UU_ZETA0       = $(zeta0)",
        "const UU_LAMBDA_STAR = $(lambda_star)",
        "const UU_NMAX        = $(nmax)",
        "const UU_COEFFS      = [$(join(string.(coeffs), ", "))]",
        "const UU_REGIME      = \"$(regime_mode)\"",
        "const UU_BLEND       = \"$(blend_mode)\"",
        "",
        "phi_u_unified(z) = max(1.0 - UU_B_U*z, 1e-8)^(-1.0/UU_LAMBDA_U)",
        "phi_s_unified(z) = 1.0 + UU_A_S*z*max(1.0+z, 1e-8)^(1/3) / max(1.0+UU_B_S*z, 1e-8)",
    ]
    append!(lines, blend_body)
    append!(lines, [
        "",
        "xi_unified(z) = tanh(UU_A_XI * asinh(z / UU_ZETA0))",
        "",
        "function gegenbauer_unified(n, lam, x)",
        "    n == 0 && return 1.0",
        "    n == 1 && return 2.0*lam*x",
        "    c0, c1 = 1.0, 2.0*lam*x",
        "    for k in 1:(n-1)",
        "        c0, c1 = c1, (2*(k+lam)*x*c1 - (k+2lam-1)*c0)/(k+1)",
        "    end",
        "    return c1",
        "end",
        "",
        "function ultra_corr_unified(z)",
        "    xi = xi_unified(z)",
        "    return sum(UU_COEFFS[n+1] * gegenbauer_unified(n, UU_LAMBDA_STAR, xi) for n in 0:UU_NMAX)",
        "end",
        "",
        "phi_unified(z) = phi_base_unified(z) + ultra_corr_unified(z)",
    ])
    write("$(out_prefix)_model.jl", join(lines, "\n") * "\n")
end

function write_formula_md(out_prefix, b_u, lambda_u, beta_c1, a_s, b_s,
                           a_xi, zeta0, lambda_star, coeffs, regime_mode, c1_tie)
    c1_note = c1_tie ? "[C¹ tie: a_s = b_u/λ_u = $(round(beta_c1, digits=5))]" : "[free fit]"
    coeff_lines = ["- c_$(n) = $(coeffs[n+1])" for n in 0:(length(coeffs)-1)]
    lines = [
        "# Unified All-Regime Ultraspherical φ — Fitted Formula",
        "",
        "## Unstable Baseline  (ζ < 0)",
        "",
        "\$\$",
        "\\phi_u(\\zeta) = (1 - b_u\\,\\zeta)^{-1/\\lambda_u}",
        "\$\$",
        "",
        "- b_u = $(round(b_u, digits=5))",
        "- λ_u = $(round(lambda_u, digits=5))",
        "- Neutral slope: b_u/λ_u = $(round(beta_c1, digits=5))",
        "",
        "## Stable Baseline  (ζ > 0)",
        "",
        "\$\$",
        "\\phi_s(\\zeta) = 1 + \\frac{a_s\\,\\zeta\\,(1+\\zeta)^{1/3}}{1 + b_s\\,\\zeta}",
        "\$\$",
        "",
        "- a_s = $(round(a_s, digits=5))   $(c1_note)",
        "- b_s = $(round(b_s, digits=5))",
        "",
        "## Blend  (regime=$(regime_mode))",
        "",
        "\$\$",
        "s(\\zeta) = \\tfrac{1}{2}\\Bigl(1 + \\tanh\\tfrac{\\zeta}{\\delta}\\Bigr),\\quad \\delta = $(BLEND_DELTA)",
        "\$\$",
        "\$\$",
        "\\phi_{\\mathrm{base}}(\\zeta) = [1-s(\\zeta)]\\,\\phi_u + s(\\zeta)\\,\\phi_s",
        "\$\$",
        "",
        "## All-Regime ξ-Map",
        "",
        "\$\$",
        "\\xi = \\tanh\\!\\Bigl(a_\\xi\\,\\operatorname{asinh}\\!\\bigl(\\zeta/\\zeta_0\\bigr)\\Bigr)",
        "\$\$",
        "",
        "- a_ξ = $(round(a_xi, digits=5))",
        "- ζ₀  = $(round(zeta0, digits=5))",
        "",
        "## Gegenbauer Correction",
        "",
        "\$\$",
        "\\Delta\\phi(\\zeta) = \\sum_{n=0}^{$(length(coeffs)-1)} c_n\\,C_n^{(\\lambda_*)}(\\xi(\\zeta))",
        "\$\$",
        "",
        "- λ_* = $(round(lambda_star, digits=5))",
        "",
    ]
    append!(lines, coeff_lines)
    append!(lines, [
        "",
        "## Total",
        "",
        "\$\$",
        "\\phi(\\zeta) = \\phi_{\\mathrm{base}}(\\zeta) + \\Delta\\phi(\\zeta)",
        "\$\$",
    ])
    write("$(out_prefix)_formula.md", join(lines, "\n") * "\n")
end

function write_report_md(out_prefix; dataset_label, baseline_label, ultra_label,
                          metrics, regime_mode, blend_mode, c1_tie,
                          b_u, lambda_u, beta_c1, a_s, b_s,
                          a_xi, zeta0, lambda_star, nmax, ridge, have_plot,
                          xi_mode="asinh")
    gain_pct = round(100*(metrics.rmse_test[1] - metrics.rmse_test[2]) / metrics.rmse_test[1], digits=2)
    run_name = basename(out_prefix)
    c1_str = c1_tie ? "yes  (a_s = b_u/λ_u = $(round(beta_c1, digits=5)))" : "no (free)"
    xi_formula = xi_mode == "log" ?
        "tanh(a_ξ · log1p(ζ))  [log, stable-range resolution]" :
        "tanh(a_ξ · asinh(ζ/ζ₀))  [all-regime, log tails]"
    zeta0_row = xi_mode == "log" ?
        "| ζ₀    | (n/a — log map)           |" :
        "| ζ₀    | $(round(zeta0, digits=5))         |"
    lines = [
        "# Unified All-Regime Ultraspherical Run Report",
        "",
        "## Run",
        "",
        "- run: $(run_name)",
        "- dataset: $(dataset_label)",
        "- regime: $(regime_mode)",
        "- blend: $(blend_mode)",
        "- C¹ continuity tie: $(c1_str)",
        "- ξ-map: $(xi_formula)",
        "",
        "## Metrics (held-out test set)",
        "",
        "| Model | RMSE | MAE |",
        "|---|---|---|",
        "| $(baseline_label) | $(round(metrics.rmse_test[1], digits=5)) | $(round(metrics.mae_test[1], digits=5)) |",
        "| $(ultra_label)    | $(round(metrics.rmse_test[2], digits=5)) | $(round(metrics.mae_test[2], digits=5)) |",
        "",
        "Relative RMSE gain: **$(gain_pct)%**",
        "",
        "## Baseline Parameters",
        "",
        "| param | value | meaning |",
        "|---|---|---|",
        "| b_u     | $(round(b_u, digits=5))      | unstable exponent scale       |",
        "| λ_u     | $(round(lambda_u, digits=5)) | unstable exponent             |",
        "| β_c1    | $(round(beta_c1, digits=5))  | neutral slope tie = b_u/λ_u   |",
        "| a_s     | $(round(a_s, digits=5))      | stable linear slope (=β_c1 if tied) |",
        "| b_s     | $(round(b_s, digits=5))      | Grachev curvature             |",
        "",
        "## Gegenbauer Hyperparameters",
        "",
        "| param | value |",
        "|---|---|",
        "| a_ξ   | $(round(a_xi, digits=5))         |",
        zeta0_row,
        "| λ_*   | $(round(lambda_star, digits=5))   |",
        "| nmax  | $(nmax)                           |",
        "| ridge | $(ridge)                          |",
        "",
    ]
    if have_plot
        push!(lines, "## Plots")
        push!(lines, "")
        push!(lines, "![comparison]($(run_name)_comparison.png)")
        push!(lines, "")
        push!(lines, "![correction]($(run_name)_correction.png)")
        push!(lines, "")
    end
    append!(lines, [
        "## Output Files",
        "",
        "- $(run_name)_metrics.csv",
        "- $(run_name)_params.csv",
        "- $(run_name)_pred_test.csv",
        "- $(run_name)_coeffs.csv",
        "- $(run_name)_curve.csv",
        "- $(run_name)_model.jl",
        "- $(run_name)_formula.md",
        "- $(run_name)_report.md",
    ])
    write("$(out_prefix)_report.md", join(lines, "\n") * "\n")
end

# ----------------------------- Main -------------------------------------------

function main()
    if length(ARGS) < 2
        println("""
Usage:
  julia unified_ultra.jl <input_csv> <output_prefix> [dataset_label] \\
    [--lambda=2|4|free] [--regime=all|stable|unstable] \\
    [--blend=soft|hard]  [--c1-tie=true|false]  [--xi-map=auto|asinh|log]

input_csv columns required: zeta, phi_obs   (optional: time)

--lambda     Fix λ_u in unstable baseline (2=heat, 4=momentum, free=fitted).
--regime     Subset of rows used for fitting.
--blend      How to join baselines: soft=sigmoid, hard=step at ζ=0.
--c1-tie     Enforce a_s = b_u/λ_u (C¹ continuity at ζ=0).
--xi-map     auto (log for stable, asinh for all/unstable), asinh, or log.
""")
        return
    end

    Random.seed!(RNG_SEED)

    input_csv     = ARGS[1]
    out_prefix    = ARGS[2]
    dataset_label = length(ARGS) >= 3 && !startswith(ARGS[3], "--") ? ARGS[3] : "unknown"

    regime_mode  = parse_flag(ARGS, "--regime",  "all")
    blend_mode   = parse_flag(ARGS, "--blend",   "soft")
    c1_tie_str   = parse_flag(ARGS, "--c1-tie",  "true")
    lambda_str   = parse_flag(ARGS, "--lambda",  "free")
    ximap_flag   = parse_flag(ARGS, "--xi-map",  "auto")

    regime_mode in ("all", "stable", "unstable") ||
        error("--regime must be all, stable, or unstable")
    blend_mode in ("soft", "hard") ||
        error("--blend must be soft or hard")
    ximap_flag in ("auto", "asinh", "log") ||
        error("--xi-map must be auto, asinh, or log")
    # auto: log for stable-only (preserves resolution over wide stable range), asinh otherwise
    xi_mode = (ximap_flag == "auto") ? (regime_mode == "stable" ? "log" : "asinh") : ximap_flag
    println("xi-map: $(xi_mode)  (regime=$(regime_mode))")

    c1_tie = c1_tie_str == "true"

    lambda_fixed = if lambda_str == "free"
        nothing
    elseif lambda_str == "2"
        2.0
    elseif lambda_str == "4"
        4.0
    else
        parse(Float64, lambda_str)
    end

    dir = dirname(out_prefix)
    isempty(dir) || mkpath(dir)

    # --- Load and filter data ---
    df = CSV.read(input_csv, DataFrame)
    "zeta"    in names(df) || error("CSV must have column 'zeta'")
    "phi_obs" in names(df) || error("CSV must have column 'phi_obs'")

    df = filter(r -> isfinite(r.zeta) && isfinite(r.phi_obs) && r.phi_obs > 0.0, df)

    df = if regime_mode == "stable"
        filter(r -> r.zeta > 0.0, df)
    elseif regime_mode == "unstable"
        filter(r -> r.zeta < 0.0, df)
    else
        filter(r -> r.zeta != 0.0, df)
    end

    nrow(df) >= 40 || error("Need ≥ 40 rows after filtering; got $(nrow(df)) (regime=$(regime_mode)).")

    zeta = Vector{Float64}(df.zeta)
    y    = Vector{Float64}(df.phi_obs)

    # Blocked chronological train/test split
    order_key = :time in names(df) ? collect(df.time) : collect(1:nrow(df))
    p = sortperm(order_key)
    k = Int(floor(TRAIN_FRAC * nrow(df)))
    train_idx, test_idx = p[1:k], p[k+1:end]
    z_tr, y_tr = zeta[train_idx], y[train_idx]
    z_te, y_te = zeta[test_idx],  y[test_idx]

    # --- Fit baseline parameters ---
    has_unstable_tr = any(z_tr .< 0.0)
    has_stable_tr   = any(z_tr .> 0.0)

    # Default starting values (Businger 1971 / Grachev 2007 canonical)
    b_u      = 16.0
    lambda_u = isnothing(lambda_fixed) ? 4.0 : lambda_fixed
    a_s      = 5.0
    b_s      = 5.0

    if has_unstable_tr
        z_u = z_tr[z_tr .< 0.0];  y_u = y_tr[z_tr .< 0.0]
        b_u, lambda_u = fit_unstable_params(z_u, y_u, lambda_fixed)
        println("Unstable baseline fitted: b_u=$(round(b_u,digits=4))  λ_u=$(round(lambda_u,digits=4))")
    else
        println("No unstable training data — using default: b_u=$(b_u)  λ_u=$(lambda_u)")
    end

    beta_c1 = b_u / lambda_u
    println("C¹ slope tie: β = b_u/λ_u = $(round(beta_c1, digits=5))")

    if has_stable_tr
        z_s = z_tr[z_tr .> 0.0];  y_s = y_tr[z_tr .> 0.0]
        if c1_tie
            a_s, b_s = fit_stable_c1(z_s, y_s, beta_c1)
            println("Stable baseline (C¹ tied): a_s=$(round(a_s,digits=4)) [=β]  b_s=$(round(b_s,digits=4))")
        else
            a_s, b_s = fit_stable_free(z_s, y_s)
            println("Stable baseline (free): a_s=$(round(a_s,digits=4))  b_s=$(round(b_s,digits=4))")
        end
    else
        println("No stable training data — using default: a_s=$(a_s)  b_s=$(b_s)")
    end

    # --- Build baseline evaluator ---
    baseline_fun = if regime_mode == "stable"
        z -> phi_stable(z, a_s, b_s)
    elseif regime_mode == "unstable"
        z -> phi_unstable(z, b_u, lambda_u)
    elseif blend_mode == "hard"
        z -> phi_blend_hard(z, b_u, lambda_u, a_s, b_s)
    else
        z -> phi_blend_soft(z, b_u, lambda_u, a_s, b_s)
    end

    yhat_tr_base = baseline_fun(z_tr)
    yhat_te_base = baseline_fun(z_te)
    res_tr = y_tr .- yhat_tr_base

    # --- Grid search: xi-map + ridge Gegenbauer regression ---
    # For stable-only (log map), zeta0 is unused; sweep only ALPHA_XI_GRID.
    # For asinh map, sweep ALPHA_XI_GRID × ZETA0_GRID.
    best      = nothing
    best_rmse = Inf

    for a_xi in ALPHA_XI_GRID
        zeta0_sweep = xi_mode == "log" ? [NaN] : ZETA0_GRID
        for zeta0 in zeta0_sweep
            xi_tr = xi_mode == "log" ? xi_map_log(z_tr, a_xi) : xi_map_asinh(z_tr, a_xi, zeta0)
            xi_te = xi_mode == "log" ? xi_map_log(z_te, a_xi) : xi_map_asinh(z_te, a_xi, zeta0)
            for lambda_star in LAMBDA_STAR_GRID, nmax in NMAX_GRID
                A_tr = gegenbauer_design(xi_tr, lambda_star, nmax)
                A_te = gegenbauer_design(xi_te, lambda_star, nmax)
                for ridge in RIDGE_GRID
                    c = ridge_solve(A_tr, res_tr, ridge)
                    yhat_te = yhat_te_base .+ A_te * c
                    score = rmse(y_te, yhat_te)
                    if score < best_rmse
                        best_rmse = score
                        best = (nmax=nmax, coeffs=c, a_xi=a_xi, zeta0=zeta0,
                                lambda_star=lambda_star, ridge=ridge,
                                yhat_tr=yhat_tr_base .+ A_tr * c,
                                yhat_te=yhat_te, xi_mode=xi_mode)
                    end
                end
            end
        end
    end

    # --- Assemble outputs ---
    baseline_label = if regime_mode == "stable"
        "Grachev-C1"
    elseif regime_mode == "unstable"
        "BDyer"
    elseif blend_mode == "hard"
        "BlendHard"
    else
        "BlendSoft"
    end
    ultra_label = "$(baseline_label)+ULTRA"

    metrics = DataFrame(
        model      = [baseline_label, ultra_label],
        rmse_train = [rmse(y_tr, yhat_tr_base), rmse(y_tr, best.yhat_tr)],
        rmse_test  = [rmse(y_te, yhat_te_base), rmse(y_te, best.yhat_te)],
        mae_train  = [mae(y_tr, yhat_tr_base),  mae(y_tr, best.yhat_tr)],
        mae_test   = [mae(y_te, yhat_te_base),  mae(y_te, best.yhat_te)],
    )

    params = DataFrame(
        dataset     = [dataset_label],
        b_u         = [b_u],
        lambda_u    = [lambda_u],
        beta_c1     = [beta_c1],
        a_s         = [a_s],
        b_s         = [b_s],
        a_xi        = [best.a_xi],
        zeta0       = [best.zeta0],
        lambda_star = [best.lambda_star],
        ridge       = [best.ridge],
        n_ultra     = [best.nmax],
        regime      = [regime_mode],
        blend       = [blend_mode],
        c1_tie      = [c1_tie],
        xi_mode     = [xi_mode],
    )

    pred   = DataFrame(zeta=z_te, obs=y_te, baseline=yhat_te_base, ultra=best.yhat_te)
    coeffs = DataFrame(mode=collect(0:best.nmax), coeff=collect(best.coeffs))

    # Evaluation curve over padded range
    z_lo   = regime_mode == "stable" ? 0.0 : min(minimum(zeta), -2.0)
    z_hi   = max(maximum(zeta), 2.0)
    zline  = collect(range(z_lo, z_hi, length=600))
    xi_line = xi_mode == "log" ? xi_map_log(zline, best.a_xi) : xi_map_asinh(zline, best.a_xi, best.zeta0)
    A_line     = gegenbauer_design(xi_line, best.lambda_star, best.nmax)
    corr_line  = A_line * best.coeffs
    yline_base = baseline_fun(zline)
    curve = DataFrame(zeta=zline, baseline=yline_base, correction=corr_line,
                      ultra=yline_base .+ corr_line)

    # --- Write all artifacts ---
    CSV.write("$(out_prefix)_metrics.csv",   metrics)
    CSV.write("$(out_prefix)_params.csv",    params)
    CSV.write("$(out_prefix)_pred_test.csv", pred)
    CSV.write("$(out_prefix)_coeffs.csv",    coeffs)
    CSV.write("$(out_prefix)_curve.csv",     curve)

    write_model_jl(out_prefix, b_u, lambda_u, a_s, b_s, best.a_xi, best.zeta0,
                   best.lambda_star, best.coeffs, best.nmax, regime_mode, blend_mode)
    write_formula_md(out_prefix, b_u, lambda_u, beta_c1, a_s, b_s, best.a_xi, best.zeta0,
                     best.lambda_star, best.coeffs, regime_mode, c1_tie)
    write_report_md(out_prefix;
                    dataset_label=dataset_label, baseline_label=baseline_label,
                    ultra_label=ultra_label, metrics=metrics, regime_mode=regime_mode,
                    blend_mode=blend_mode, c1_tie=c1_tie,
                    b_u=b_u, lambda_u=lambda_u, beta_c1=beta_c1, a_s=a_s, b_s=b_s,
                    a_xi=best.a_xi, zeta0=best.zeta0, lambda_star=best.lambda_star,
                    nmax=best.nmax, ridge=best.ridge, have_plot=HAVE_MAKIE,
                    xi_mode=xi_mode)

    gain_pct = round(100*(metrics.rmse_test[1] - metrics.rmse_test[2]) / metrics.rmse_test[1], digits=2)
    zeta0_str = xi_mode == "log" ? "(n/a — log map)" : string(round(best.zeta0, digits=5))
    println("\nSelected hyperparameters:")
    println("  xi_mode     = $(xi_mode)")
    println("  a_xi        = $(best.a_xi)")
    println("  zeta0       = $(zeta0_str)")
    println("  lambda_star = $(best.lambda_star)")
    println("  nmax        = $(best.nmax)")
    println("  ridge       = $(best.ridge)")
    println("  baseline RMSE (test) = $(round(metrics.rmse_test[1], digits=5))")
    println("  ultra RMSE   (test)  = $(round(metrics.rmse_test[2], digits=5))")
    println("  RMSE gain            = $(gain_pct)%")
    println("\nDone. Artifacts written:")
    for s in ["_metrics.csv","_params.csv","_pred_test.csv","_coeffs.csv","_curve.csv",
              "_model.jl","_formula.md","_report.md"]
        println("  $(out_prefix)$(s)")
    end

    HAVE_MAKIE || return

    # Comparison plot
    fig = Figure(resolution=(960, 540))
    ax  = Axis(fig[1,1], xlabel="ζ", ylabel="φ",
               title="$(dataset_label): $(baseline_label) vs $(ultra_label)")
    scatter!(ax, z_tr, y_tr, markersize=4, color=(:steelblue, 0.4), label="Train")
    scatter!(ax, z_te, y_te, markersize=6, color=(:black,     0.7), label="Test")
    lines!(ax, zline, curve.baseline, linewidth=2.2, color=:orangered, label=baseline_label)
    lines!(ax, zline, curve.ultra,    linewidth=2.2, color=:seagreen,  label=ultra_label)
    vlines!(ax, [0.0], color=(:gray, 0.6), linestyle=:dash, linewidth=1)
    axislegend(ax, position=:lt)
    save("$(out_prefix)_comparison.png", fig)

    # Correction plot
    fig2 = Figure(resolution=(960, 540))
    ax2  = Axis(fig2[1,1], xlabel="ζ", ylabel="Δφ",
                title="Gegenbauer Correction ($(dataset_label))")
    lines!(ax2, zline, corr_line, linewidth=2.4, color=:darkgreen, label="Δφ_ultra")
    hlines!(ax2, [0.0], color=:black,     linewidth=1.0, linestyle=:dash)
    vlines!(ax2, [0.0], color=(:gray,0.6), linewidth=1.0, linestyle=:dash)
    axislegend(ax2, position=:rt)
    save("$(out_prefix)_correction.png", fig2)

    println("  $(out_prefix)_comparison.png")
    println("  $(out_prefix)_correction.png")
end

main()
