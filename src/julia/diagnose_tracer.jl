#!/usr/bin/env julia

# diagnose_tracer.jl
#
# Visual inspection and regime-stratified statistics for multi-tracer
# preprocessed data.  Intended to run after preprocess_multi_tracer.jl.
#
# Usage:
#   julia diagnose_tracer.jl <input_csv> <output_prefix> [dataset_label] [FLAGS]
#
# FLAGS:
#   --tracers=momentum,heat            (which phi columns to diagnose; default: all phi_* cols)
#   --ric=0.25                         (Ri_c for regime bins)
#   --zeta-neutral=0.1
#   --zeta-min=<float>                 (clip plot range)
#   --zeta-max=<float>
#
# Outputs per tracer:
#   <prefix>_<tracer>_by_regime.png        (scatter by regime, 4 panels)
#   <prefix>_<tracer>_phi_distribution.png (phi histograms by regime)
#   <prefix>_<tracer>_regime_stats.csv     (per-regime statistics)
#   <prefix>_<tracer>_baseline_overlay.png (data + registry canonical baseline)
# Summary (all tracers):
#   <prefix>_modeling_summary.md           (regime analysis for next-step decisions)

using CSV, DataFrames, Statistics

include(joinpath(@__DIR__, "tracer_registry.jl"))

const HAVE_MAKIE = try
    @eval using CairoMakie
    true
catch
    false
end

# ──────────────────────────── Helpers ────────────────────────────────────────

function parse_flag(args, key, default)
    for a in args
        startswith(a, key) || continue
        parts = split(a, "=", limit=2)
        length(parts) == 2 || return default
        return parts[2]
    end
    return default
end

parse_float_flag(args, key) = begin
    v = parse_flag(args, key, "")
    isempty(v) ? nothing : tryparse(Float64, v)
end

has_flag(args, f) = any(x -> x == f, args)

output_base(p) = endswith(lowercase(p), ".csv") ? p[1:end-4] : p

# ─────────────────────────── Plot helpers ────────────────────────────────────

const REGIME_MAKIE_COLOR = Dict(
    "unstable"        => :royalblue,
    "near_neutral"    => :forestgreen,
    "weakly_stable"   => :darkorange,
    "strongly_stable" => :firebrick,
)

const REGIME_ORDER_STR = ["unstable", "near_neutral", "weakly_stable", "strongly_stable"]

const REGIME_TITLE = Dict(
    "unstable"        => "Unstable  (ζ < 0)",
    "near_neutral"    => "Near-neutral  (|ζ| ≤ 0.1)",
    "weakly_stable"   => "Weakly stable  (Ri < Ri_c)",
    "strongly_stable" => "Strongly stable  (Ri ≥ Ri_c)",
)

"""
4-panel regime plot for a single tracer.
Each panel: scatter of (ζ, φ_obs) for that regime + registry canonical baseline.
"""
function plot_by_regime(zeta, phi, regimes, tracer::TracerDef, out_path::String;
                         zeta_min=nothing, zeta_max=nothing)
    HAVE_MAKIE || begin
        @warn "CairoMakie not available; skipping $(out_path)"
        return
    end

    fig = Figure(size=(1200, 900))
    for (panel_idx, reg_str) in enumerate(REGIME_ORDER_STR)
        row = (panel_idx - 1) ÷ 2 + 1
        col = (panel_idx - 1) % 2 + 1
        ax  = Axis(fig[row, col],
                   xlabel = "ζ = z/L",
                   ylabel = "$(tracer.phi_col)",
                   title  = "$(tracer.display)\n$(REGIME_TITLE[reg_str])")

        mask = findall(r -> r == reg_str, regimes)
        if !isempty(mask)
            scatter!(ax, zeta[mask], phi[mask];
                     markersize=4,
                     color=(REGIME_MAKIE_COLOR[reg_str], 0.5),
                     label="observed (n=$(length(mask)))")
        else
            text!(ax, "no data", position=(0.5, 0.5), align=(:center, :center))
        end

        # Canonical baseline overlay
        zlo = isnothing(zeta_min) ? (isempty(mask) ? -2.0 : min(minimum(zeta[mask]), -0.1)) : zeta_min
        zhi = isnothing(zeta_max) ? (isempty(mask) ? 5.0  : max(maximum(zeta[mask]),  1.0)) : zeta_max
        zline = collect(range(zlo, zhi, length=300))
        phi_base = [phi_baseline(z, tracer) for z in zline]
        lines!(ax, zline, phi_base; linewidth=2.0, color=:black, linestyle=:dash,
               label="registry baseline")

        hlines!(ax, [1.0]; color=(:gray, 0.5), linestyle=:dot, linewidth=1)
        vlines!(ax, [0.0]; color=(:gray, 0.5), linestyle=:dot, linewidth=1)
        axislegend(ax; position=:lt, labelsize=10)
    end
    save(out_path, fig)
end

"""
4-panel histogram of φ by regime.
"""
function plot_phi_distribution(phi, regimes, tracer::TracerDef, out_path::String)
    HAVE_MAKIE || begin
        @warn "CairoMakie not available; skipping $(out_path)"
        return
    end

    fig = Figure(size=(1200, 900))
    for (panel_idx, reg_str) in enumerate(REGIME_ORDER_STR)
        row = (panel_idx - 1) ÷ 2 + 1
        col = (panel_idx - 1) % 2 + 1
        ax  = Axis(fig[row, col],
                   xlabel = "$(tracer.phi_col)",
                   ylabel = "count",
                   title  = "$(tracer.display)\n$(REGIME_TITLE[reg_str])")

        mask = findall(r -> r == reg_str, regimes)
        pv   = filter(isfinite, phi[mask])
        if length(pv) >= 5
            hist!(ax, pv; bins=30,
                  color=(REGIME_MAKIE_COLOR[reg_str], 0.7),
                  strokewidth=0.5, strokecolor=:black)
            vlines!(ax, [median(pv)]; color=:black, linestyle=:dash,
                    linewidth=1.5, label="median=$(round(median(pv),digits=2))")
            axislegend(ax; position=:rt, labelsize=10)
        else
            text!(ax, "n < 5", position=(0.5, 0.5), align=(:center, :center))
        end
    end
    save(out_path, fig)
end

"""
Single-panel full-ζ plot with regime colour coding + canonical baseline.
"""
function plot_baseline_overlay(zeta, phi, regimes, tracer::TracerDef, out_path::String;
                                zeta_min=nothing, zeta_max=nothing)
    HAVE_MAKIE || begin
        @warn "CairoMakie not available; skipping $(out_path)"
        return
    end

    fig = Figure(size=(960, 560))
    ax  = Axis(fig[1, 1],
               xlabel = "ζ = z/L",
               ylabel = "$(tracer.phi_col)",
               title  = "$(tracer.display) — All regimes + canonical baseline")

    for reg_str in REGIME_ORDER_STR
        mask = findall(r -> r == reg_str, regimes)
        isempty(mask) && continue
        scatter!(ax, zeta[mask], phi[mask];
                 markersize=4,
                 color=(REGIME_MAKIE_COLOR[reg_str], 0.5),
                 label="$(REGIME_TITLE[reg_str]) (n=$(length(mask)))")
    end

    zlo = isnothing(zeta_min) ? min(minimum(zeta[isfinite.(zeta)]), -2.0) : zeta_min
    zhi = isnothing(zeta_max) ? max(maximum(zeta[isfinite.(zeta)]),  5.0) : zeta_max
    zline     = collect(range(zlo, zhi, length=500))
    phi_base  = [phi_baseline(z, tracer) for z in zline]
    lines!(ax, zline, phi_base; linewidth=2.5, color=:black, linestyle=:dash,
           label="registry baseline")

    hlines!(ax, [1.0]; color=(:gray, 0.4), linestyle=:dot, linewidth=1)
    vlines!(ax, [0.0]; color=(:gray, 0.4), linestyle=:dot, linewidth=1)
    axislegend(ax; position=:lt, labelsize=10, nbanks=2)
    save(out_path, fig)
end

# ─────────────────────────── Residual diagnostics ────────────────────────────

"""
Residuals of observed φ against registry baseline, by regime.
2-panel: (a) residuals vs ζ, (b) residual histograms.
"""
function plot_residual_diagnostics(zeta, phi, regimes, tracer::TracerDef, out_path::String)
    HAVE_MAKIE || begin
        @warn "CairoMakie not available; skipping $(out_path)"
        return
    end

    residuals = [isfinite(p) ? p - phi_baseline(z, tracer) : NaN
                 for (z, p) in zip(zeta, phi)]

    fig = Figure(size=(1200, 500))
    ax1 = Axis(fig[1, 1],
               xlabel="ζ", ylabel="φ_obs − φ_baseline",
               title="$(tracer.display) — Residuals vs ζ")
    ax2 = Axis(fig[1, 2],
               xlabel="φ_obs − φ_baseline", ylabel="count",
               title="$(tracer.display) — Residual distribution by regime")

    for reg_str in REGIME_ORDER_STR
        mask = findall(r -> r == reg_str, regimes)
        isempty(mask) && continue
        rv   = filter(isfinite, residuals[mask])
        isempty(rv) && continue
        col  = REGIME_MAKIE_COLOR[reg_str]
        label_str = "$(reg_str) (n=$(length(rv)))"

        scatter!(ax1, zeta[mask], residuals[mask];
                 markersize=3, color=(col, 0.4), label=label_str)
        hist!(ax2, rv; bins=25, color=(col, 0.5),
              strokewidth=0.3, strokecolor=:black, label=label_str)
    end

    hlines!(ax1, [0.0]; color=:black, linestyle=:dash, linewidth=1)
    vlines!(ax1, [0.0]; color=(:gray,0.4), linestyle=:dot, linewidth=1)
    axislegend(ax1; position=:lt, labelsize=9, nbanks=2)
    axislegend(ax2; position=:rt, labelsize=9)
    save(out_path, fig)
end

# ──────────────────────────── Stats helpers ───────────────────────────────────

"""
Extended per-regime statistics including residuals against the registry baseline.
"""
function extended_regime_stats(zeta, phi, regimes, tracer::TracerDef;
                                 ric::Float64 = DEFAULT_RIC)
    rows = []
    for reg_str in REGIME_ORDER_STR
        mask = findall(r -> r == reg_str, regimes)
        n    = length(mask)
        pv   = filter(isfinite, phi[mask])
        zv   = filter(isfinite, zeta[mask])
        res  = filter(isfinite,
                      [isfinite(phi[i]) ? phi[i] - phi_baseline(zeta[i], tracer) : NaN
                       for i in mask])
        push!(rows, (
            tracer          = String(tracer.id),
            regime          = reg_str,
            regime_display  = REGIME_TITLE[reg_str],
            n_total         = n,
            n_finite_phi    = length(pv),
            zeta_q05        = isempty(zv) ? NaN : quantile(zv, 0.05),
            zeta_q50        = isempty(zv) ? NaN : quantile(zv, 0.50),
            zeta_q95        = isempty(zv) ? NaN : quantile(zv, 0.95),
            phi_mean        = isempty(pv) ? NaN : mean(pv),
            phi_std         = isempty(pv) ? NaN : std(pv),
            phi_q05         = isempty(pv) ? NaN : quantile(pv, 0.05),
            phi_q25         = isempty(pv) ? NaN : quantile(pv, 0.25),
            phi_q50         = isempty(pv) ? NaN : quantile(pv, 0.50),
            phi_q75         = isempty(pv) ? NaN : quantile(pv, 0.75),
            phi_q95         = isempty(pv) ? NaN : quantile(pv, 0.95),
            phi_iqr         = isempty(pv) ? NaN : quantile(pv, 0.75) - quantile(pv, 0.25),
            resid_mean      = isempty(res) ? NaN : mean(res),
            resid_std       = isempty(res) ? NaN : std(res),
            resid_rmse      = isempty(res) ? NaN : sqrt(mean(res.^2)),
            heteroscedastic_flag = length(res) ≥ 10 &&
                                   std(res) / (abs(mean(res)) + 1e-9) > 2.0,
        ))
    end
    return DataFrame(rows)
end

# ──────────────────────────── Markdown summary ───────────────────────────────

function write_modeling_summary(out_prefix, dataset_label, all_stats, tracer_defs,
                                  ric, have_plot)
    rn = basename(out_prefix)
    lines = [
        "# Multi-Tracer Regime Analysis — Modeling Summary",
        "",
        "**Dataset:** $(dataset_label)",
        "**Ri_c (regime boundary):** $(ric)",
        "",
        "---",
        "",
    ]

    for (stats_df, t) in zip(all_stats, tracer_defs)
        push!(lines, "## $(t.display)")
        push!(lines, "")
        push!(lines, "**Sign convention note:** $(t.sign_note)")
        push!(lines, "")
        push!(lines, "**Baseline family:** unstable λ=$(t.lambda_unstable) " *
                     "(b=$(t.b_unstable_default) → (1−$(t.b_unstable_default)ζ)^{−1/$(t.lambda_unstable)}); " *
                     "stable Grachev a=$(t.a_stable_default), b=$(t.b_stable_default)")
        push!(lines, "")
        push!(lines, "| Regime | n | ζ q50 | φ q50 | φ IQR | Residual RMSE | Heteroscedastic |")
        push!(lines, "|---|---|---|---|---|---|---|")
        for r in eachrow(stats_df)
            push!(lines, "| $(r.regime_display) | $(r.n_finite_phi) " *
                         "| $(round(r.zeta_q50, digits=3)) | $(round(r.phi_q50, digits=3)) " *
                         "| $(round(r.phi_iqr, digits=3)) | $(round(r.resid_rmse, digits=4)) " *
                         "| $(r.heteroscedastic_flag) |")
        end
        push!(lines, "")

        # Identify regime with largest residual RMSE
        valid_rows = filter(r -> isfinite(r.resid_rmse) && r.n_finite_phi > 0, eachrow(stats_df))
        if !isempty(valid_rows)
            worst = valid_rows[argmax([r.resid_rmse for r in valid_rows])]
            push!(lines, "**Priority for baseline refinement:** $(worst.regime_display) " *
                         "(residual RMSE=$(round(worst.resid_rmse,digits=4)))")
        end

        push!(lines, "")
        if have_plot
            push!(lines, "**Plots:**")
            push!(lines, "- ![by_regime]($(rn)_$(t.id)_by_regime.png)")
            push!(lines, "- ![distribution]($(rn)_$(t.id)_phi_distribution.png)")
            push!(lines, "- ![baseline overlay]($(rn)_$(t.id)_baseline_overlay.png)")
            push!(lines, "- ![residuals]($(rn)_$(t.id)_residuals.png)")
            push!(lines, "")
        end

        push!(lines, "---")
        push!(lines, "")
    end

    push!(lines, "## Next Steps")
    push!(lines, "")
    push!(lines, "1. For regimes with high residual RMSE: run `unified_ultra.jl --regime=<regime>` " *
                 "with the corresponding tracer's preprocessed CSV.")
    push!(lines, "2. For heteroscedastic regimes: consider regime-specific ridge regularisation " *
                 "or variance-weighted fitting.")
    push!(lines, "3. Review sign convention notes above for each tracer before fitting.")
    push!(lines, "4. Near-neutral rows are bridging between stable and unstable baselines — " *
                 "inspect the C¹ tie quality before using blended fits.")
    push!(lines, "")
    push!(lines, "## Artifacts")
    push!(lines, "")
    for t in tracer_defs
        push!(lines, "- $(rn)_$(t.id)_regime_stats.csv")
        have_plot && push!(lines, "- $(rn)_$(t.id)_by_regime.png")
        have_plot && push!(lines, "- $(rn)_$(t.id)_phi_distribution.png")
        have_plot && push!(lines, "- $(rn)_$(t.id)_baseline_overlay.png")
        have_plot && push!(lines, "- $(rn)_$(t.id)_residuals.png")
    end
    write("$(out_prefix)_modeling_summary.md", join(lines, "\n") * "\n")
end

# ─────────────────────────────── Main ────────────────────────────────────────

function main()
    if length(ARGS) < 2 || has_flag(ARGS, "--help")
        println("""
Usage:
  julia diagnose_tracer.jl <input_csv> <output_prefix> [dataset_label] [FLAGS]

FLAGS:
  --tracers=momentum,heat     (default: auto-detect all phi_* columns)
  --ric=0.25
  --zeta-neutral=0.1
  --zeta-min=<float>
  --zeta-max=<float>
""")
        return
    end

    input_csv     = ARGS[1]
    out_prefix    = ARGS[2]
    has_label     = length(ARGS) >= 3 && !startswith(ARGS[3], "--")
    dataset_label = has_label ? ARGS[3] : "unknown"
    extra_start   = has_label ? 4 : 3
    extra         = length(ARGS) >= extra_start ? collect(ARGS[extra_start:end]) : String[]

    ric       = something(parse_float_flag(extra, "--ric"),           DEFAULT_RIC)
    zeta_neut = something(parse_float_flag(extra, "--zeta-neutral"),  DEFAULT_ZETA_NEUTRAL)
    zeta_min  = parse_float_flag(extra, "--zeta-min")
    zeta_max  = parse_float_flag(extra, "--zeta-max")

    mkpath(dirname(out_prefix) == "" ? "." : dirname(out_prefix))

    df = CSV.read(input_csv, DataFrame)
    n  = nrow(df)
    println("Loaded $(n) rows from $(input_csv)")

    # ── Determine which tracers to diagnose ──
    tracer_str = parse_flag(extra, "--tracers", "")
    selected_ids = if !isempty(tracer_str)
        [Symbol(strip(s)) for s in split(tracer_str, ',') if !isempty(strip(s))]
    else
        # Auto-detect: any column named phi_<something> or matching registry phi_col
        phi_cols = filter(c -> startswith(String(c), "phi_") && c != :phi_obs, Symbol.(names(df)))
        [Symbol(String(c)[5:end]) for c in phi_cols]   # strip "phi_"
    end
    isempty(selected_ids) && push!(selected_ids, :momentum)

    tracers = [get_tracer(id) for id in selected_ids]
    println("Diagnosing tracers: $(join([t.display for t in tracers], ", "))")

    # ── Base arrays ──
    zeta_vec = Float64[isfinite(to_float(v)) ? to_float(v) : NaN for v in df.zeta]

    # Ri_g: prefer pre-computed column; else NaN
    rig_vec = :Ri_g in names(df) ?
        Float64[to_float(v) for v in df.Ri_g] :
        fill(NaN, n)

    regimes = assign_regimes(zeta_vec, rig_vec; ric, zeta_neutral=zeta_neut)
    regime_strs = string.(regimes)

    # Apply zeta window for plots (stats use full data)
    plot_mask = trues(n)
    isnothing(zeta_min) || (plot_mask .&= zeta_vec .>= zeta_min)
    isnothing(zeta_max) || (plot_mask .&= zeta_vec .<= zeta_max)

    all_stats = DataFrame[]
    for t in tracers
        phi_col = t.phi_col
        # Fallback: accept phi_obs as legacy single-tracer column
        actual_col = if phi_col in names(df)
            phi_col
        elseif "phi_obs" in names(df)
            @warn "Column $(phi_col) not found; using phi_obs as fallback for tracer $(t.id)"
            "phi_obs"
        else
            @warn "Column $(phi_col) not found in $(input_csv) — skipping tracer $(t.id)"
            continue
        end
        phi_vec = Float64[to_float(v) for v in df[!, actual_col]]

        # Filter: physical plausibility bounds
        valid_mask = isfinite.(zeta_vec) .& isfinite.(phi_vec) .&
                     (phi_vec .>= t.phi_lo) .& (phi_vec .<= t.phi_hi)
        n_valid = count(valid_mask)
        println("  $(t.display): $(n_valid)/$(n) rows pass bounds [$(t.phi_lo), $(t.phi_hi)]")

        zv = zeta_vec[valid_mask]
        pv = phi_vec[valid_mask]
        rv = regime_strs[valid_mask]

        # Stats
        stats = extended_regime_stats(zv, pv, rv, t; ric)
        push!(all_stats, stats)
        CSV.write("$(out_prefix)_$(t.id)_regime_stats.csv", stats)
        println("    → regime_stats: $(out_prefix)_$(t.id)_regime_stats.csv")

        # Plots
        pmask = plot_mask[valid_mask]   # subset to plot window
        zp = zv[pmask];  pp = pv[pmask];  rp = rv[pmask]

        plot_by_regime(zp, pp, rp, t,
                       "$(out_prefix)_$(t.id)_by_regime.png";
                       zeta_min, zeta_max)

        plot_phi_distribution(pp, rp, t,
                              "$(out_prefix)_$(t.id)_phi_distribution.png")

        plot_baseline_overlay(zp, pp, rp, t,
                              "$(out_prefix)_$(t.id)_baseline_overlay.png";
                              zeta_min, zeta_max)

        plot_residual_diagnostics(zp, pp, rp, t,
                                  "$(out_prefix)_$(t.id)_residuals.png")

        HAVE_MAKIE && println("    → plots written for $(t.id)")
    end

    # ── Modeling summary ──
    write_modeling_summary(out_prefix, dataset_label, all_stats, tracers, ric, HAVE_MAKIE)
    println("Wrote modeling summary: $(out_prefix)_modeling_summary.md")

    # ── Regime overview print ──
    println("\nRegime counts (all rows, Ri_c=$(ric)):")
    for reg in REGIME_ORDER_STR
        n_reg = count(==(reg), regime_strs)
        println("  $(REGIME_DISPLAY[Symbol(reg)]): $(n_reg)")
    end
    println()
    HAVE_MAKIE || println("Note: CairoMakie not installed — plots skipped.  " *
                           "Install with: using Pkg; Pkg.add(\"CairoMakie\")")
end

function to_float(x)
    x isa Missing && return NaN
    x isa Number  && return Float64(x)
    something(tryparse(Float64, strip(String(x))), NaN)
end

try
    main()
catch err
    println(stderr, "Error: ", err)
    for (exc, bt) in Base.catch_stack()
        showerror(stderr, exc, bt)
        println(stderr)
    end
    exit(1)
end
