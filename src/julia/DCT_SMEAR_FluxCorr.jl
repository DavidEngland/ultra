# DCT_SMEAR_FluxCorr.jl
# ──────────────────────────────────────────────────────────────────────────────
# Links DCT spectral fingerprints from a seasonal temperature-profile run
# to co-located flux measurements.  Produces:
#   flux_fingerprint_joined.csv   – inner join on 30-min datetime window
#   flux_correlation_matrix.csv   – Pearson r, Spearman ρ, N for every
#                                   (spectral_predictor × flux_target) pair
#   plot_corr_heatmap.png         – correlation heatmap
#   plot_<pred>_vs_<target>.png   – scatter (coloured by stability) for every
#                                   pair with |r| >= CORR_THRESHOLD
#   report.md                     – human-readable summary
#
# ENV controls:
#   FLUX_CORR_SEASON       season label (default "dead_of_winter")
#   FLUX_CORR_FP_DIR       directory that contains fingerprints.csv
#                          (default: dct_smear_seasonal_<SEASON>/varrio_<SEASON>_temperature_profile)
#   FLUX_CORR_FLUX_CSV     path to heat-flux seasonal CSV
#                          (default: seasonal_varrio_station1/<SEASON>/varrio_<SEASON>_heat_flux.csv)
#   FLUX_CORR_MOMENTUM_CSV path to momentum-flux seasonal CSV  (optional, "" = skip)
#   FLUX_CORR_CO2_CSV      path to co2-tracers seasonal CSV    (optional, "" = skip)
#   FLUX_CORR_OUT_DIR      output directory
#                          (default: runs/dct_smear_seasonal_<SEASON>/flux_corr)
#   FLUX_CORR_THRESHOLD    |r| cutoff for scatter plots (default 0.2)
#   FLUX_CORR_QC_MAX       maximum Qc flag value to accept (default 1, i.e. Qc ≤ 1)
# ──────────────────────────────────────────────────────────────────────────────

using CSV
using DataFrames
using Dates
using Plots
using Printf
using Statistics

const REPO_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

# ── ENV config ────────────────────────────────────────────────────────────────
const SEASON = get(ENV, "FLUX_CORR_SEASON", "dead_of_winter")

const DEFAULT_FP_DIR = joinpath(
    REPO_ROOT, "runs",
    "dct_smear_seasonal_$(SEASON)",
    "varrio_$(SEASON)_temperature_profile",
)
const DEFAULT_FLUX_CSV = joinpath(
    REPO_ROOT, "runs", "seasonal_varrio_station1", SEASON,
    "varrio_$(SEASON)_heat_flux.csv",
)
const DEFAULT_MOMENTUM_CSV = joinpath(
    REPO_ROOT, "runs", "seasonal_varrio_station1", SEASON,
    "varrio_$(SEASON)_momentum_flux.csv",
)
const DEFAULT_CO2_CSV = joinpath(
    REPO_ROOT, "runs", "seasonal_varrio_station1", SEASON,
    "varrio_$(SEASON)_co2_tracers.csv",
)
const DEFAULT_OUT_DIR = joinpath(
    REPO_ROOT, "runs",
    "dct_smear_seasonal_$(SEASON)",
    "flux_corr",
)

const FP_DIR        = get(ENV, "FLUX_CORR_FP_DIR",        DEFAULT_FP_DIR)
const FLUX_CSV      = get(ENV, "FLUX_CORR_FLUX_CSV",      DEFAULT_FLUX_CSV)
const MOMENTUM_CSV  = get(ENV, "FLUX_CORR_MOMENTUM_CSV",  DEFAULT_MOMENTUM_CSV)
const CO2_CSV       = get(ENV, "FLUX_CORR_CO2_CSV",       DEFAULT_CO2_CSV)
const OUT_DIR       = get(ENV, "FLUX_CORR_OUT_DIR",        DEFAULT_OUT_DIR)
const CORR_THRESHOLD = parse(Float64, get(ENV, "FLUX_CORR_THRESHOLD", "0.2"))
const QC_MAX         = parse(Int,     get(ENV, "FLUX_CORR_QC_MAX",     "1"))

mkpath(OUT_DIR)

# ── Spectral predictors and flux targets ──────────────────────────────────────
const SPECTRAL_PREDICTORS = ["c1", "c2", "c3", "c4", "shape_ratio"]

const FLUX_VARS_HEAT = ["VAR_EDDY.H", "VAR_EDDY.LE", "VAR_EDDY.E",
                        "VAR_EDDY.H_storage_flux", "VAR_EDDY.LE_storage_flux"]
const QC_MAP_HEAT    = Dict(
    "VAR_EDDY.H"  => "VAR_EDDY.Qc_H",
    "VAR_EDDY.LE" => "VAR_EDDY.Qc_LE",
)

const FLUX_VARS_MOMENTUM = ["VAR_EDDY.tau", "VAR_EDDY.u_star",
                             "VAR_EDDY.U",   "VAR_EDDY.MO_length"]
const QC_MAP_MOMENTUM    = Dict("VAR_EDDY.tau" => "VAR_EDDY.Qc_tau")

const FLUX_VARS_CO2 = ["VAR_EDDY.F_c", "VAR_EDDY.CO2_storage_flux"]
const QC_MAP_CO2    = Dict("VAR_EDDY.F_c" => "VAR_EDDY.Qc_F_c")

# ── Helpers ───────────────────────────────────────────────────────────────────
function _normalize_datetime!(df::DataFrame)
    :datetime in propertynames(df) || error("missing datetime column")
    if eltype(df.datetime) <: AbstractString
        df.datetime = DateTime.(df.datetime)
    elseif !(eltype(df.datetime) <: DateTime)
        df.datetime = DateTime.(string.(df.datetime))
    end
    # Snap to 30-min window so fingerprint keys align with 30-min flux averages
    df.datetime = floor.(df.datetime, Minute(30))
end

function _safe_float(x)
    ismissing(x) && return NaN
    x isa Number && return isnan(Float64(x)) ? NaN : Float64(x)
    v = tryparse(Float64, string(x))
    return isnothing(v) ? NaN : v
end

function _pearson(x::Vector{Float64}, y::Vector{Float64})
    ok = .!isnan.(x) .& .!isnan.(y)
    sum(ok) < 4 && return (r=NaN, n=sum(ok))
    r = cor(x[ok], y[ok])
    return (r=r, n=sum(ok))
end

function _spearman(x::Vector{Float64}, y::Vector{Float64})
    ok = .!isnan.(x) .& .!isnan.(y)
    sum(ok) < 4 && return NaN
    rx = invperm(sortperm(x[ok]))
    ry = invperm(sortperm(y[ok]))
    return cor(Float64.(rx), Float64.(ry))
end

"""Apply Qc mask: set flux column to NaN where paired Qc column > QC_MAX."""
function _apply_qc_mask!(df::DataFrame, var_col::String, qc_map::Dict)
    haskey(qc_map, var_col) || return
    qc_col = qc_map[var_col]
    qc_col in names(df) || return
    for i in 1:nrow(df)
        qv = _safe_float(df[i, qc_col])
        if !isnan(qv) && qv > QC_MAX
            df[i, var_col] = missing
        end
    end
end

"""Load a seasonal flux CSV, Qc-mask its flux columns, snap datetime to 30-min."""
function load_flux_csv(path::String, flux_vars::Vector{String}, qc_map::Dict)
    isfile(path) || return DataFrame()
    df = CSV.read(path, DataFrame; missingstring=["", "NaN", "NA"])
    _normalize_datetime!(df)
    for v in flux_vars
        v in names(df) || continue
        _apply_qc_mask!(df, v, qc_map)
    end
    # Keep only what's useful
    keep = ["datetime"; [v for v in flux_vars if v in names(df)]]
    select!(df, keep)
    sort!(df, :datetime)
    unique!(df, :datetime)
    return df
end

"""Collapse a fingerprints DataFrame to one row per 30-min window (median)."""
function aggregate_fingerprints(fp::DataFrame)
    fp.window = floor.(fp.datetime, Minute(30))
    agg = combine(groupby(fp, :window)) do g
        row = NamedTuple{(:c1, :c2, :c3, :c4, :shape_ratio, :zeta, :ustar, :stability)}((
            median(filter(!isnan, Float64.(g.c1))),
            median(filter(!isnan, Float64.(g.c2))),
            median(filter(!isnan, Float64.(g.c3))),
            median(filter(!isnan, Float64.(g.c4))),
            median(filter(!isnan, Float64.(g.shape_ratio))),
            median(filter(!isnan, Float64.(g.zeta))),
            median(filter(!isnan, Float64.(g.ustar))),
            # Plurality stability label
            begin
                stabs = string.(g.stability)
                mode_stab = first(sort(collect(values(countmap(stabs))); rev=true) |> _ ->
                    [k for (k, v) in countmap(stabs) if v == maximum(values(countmap(stabs)))])
                mode_stab
            end,
        ))
        DataFrame([row])
    end
    rename!(agg, :window => :datetime)
    return agg
end

function countmap(v)
    d = Dict{eltype(v), Int}()
    for x in v
        d[x] = get(d, x, 0) + 1
    end
    return d
end

# ── Load data ─────────────────────────────────────────────────────────────────
println("Loading fingerprints from: $(FP_DIR)")
fp_path = joinpath(FP_DIR, "fingerprints.csv")
isfile(fp_path) || error("fingerprints.csv not found in $(FP_DIR)")

fp_raw = CSV.read(fp_path, DataFrame; missingstring=["", "NaN", "NA"])
isempty(fp_raw) && error("fingerprints.csv is empty — run DCT_SMEAR_Seasonal.jl first")
_normalize_datetime!(fp_raw)

# Handle NaN stored as Float64 in spectral columns
for col in vcat(SPECTRAL_PREDICTORS, ["zeta", "ustar"])
    col in names(fp_raw) || continue
    fp_raw[!, col] = _safe_float.(fp_raw[!, col])
end

fp = aggregate_fingerprints(fp_raw)
println("  $(nrow(fp)) 30-min fingerprint windows loaded")

println("Loading flux CSVs…")
heat_df     = load_flux_csv(FLUX_CSV,      FLUX_VARS_HEAT,     QC_MAP_HEAT)
momentum_df = load_flux_csv(MOMENTUM_CSV,  FLUX_VARS_MOMENTUM, QC_MAP_MOMENTUM)
co2_df      = load_flux_csv(CO2_CSV,       FLUX_VARS_CO2,      QC_MAP_CO2)

println("  heat_flux rows: $(nrow(heat_df))")
println("  momentum_flux rows: $(nrow(momentum_df))")
println("  co2_tracers rows: $(nrow(co2_df))")

# ── Join ──────────────────────────────────────────────────────────────────────
joined = fp
for flux_df in (heat_df, momentum_df, co2_df)
    isempty(flux_df) && continue
    joined = leftjoin(joined, flux_df; on=:datetime, makeunique=true)
end
sort!(joined, :datetime)

all_flux_vars = [v for v in vcat(FLUX_VARS_HEAT, FLUX_VARS_MOMENTUM, FLUX_VARS_CO2)
                 if v in names(joined)]

println("Joined $(nrow(joined)) rows, $(length(all_flux_vars)) flux variables available")
CSV.write(joinpath(OUT_DIR, "flux_fingerprint_joined.csv"), joined)

# ── Correlation matrix ────────────────────────────────────────────────────────
corr_rows = NamedTuple[]
for pred in SPECTRAL_PREDICTORS
    pred in names(joined) || continue
    x = _safe_float.(joined[!, pred])
    for fv in all_flux_vars
        y_raw = joined[!, fv]
        y = _safe_float.(y_raw)
        pr = _pearson(x, y)
        rho = _spearman(x, y)
        push!(corr_rows, (
            predictor  = pred,
            flux_var   = fv,
            pearson_r  = pr.r,
            spearman_rho = rho,
            n          = pr.n,
        ))
    end
end

corr_df = DataFrame(corr_rows)
CSV.write(joinpath(OUT_DIR, "flux_correlation_matrix.csv"), corr_df)
println("Correlation matrix written: $(nrow(corr_df)) pairs")

# ── Correlation heatmap ───────────────────────────────────────────────────────
default(size=(1200, 500), dpi=140)

valid_preds = [p for p in SPECTRAL_PREDICTORS if p in names(joined)]
if !isempty(valid_preds) && !isempty(all_flux_vars)
    mat = [
        begin
            sub = filter(r -> r.predictor == p && r.flux_var == fv, corr_df)
            isempty(sub) ? NaN : sub[1, :pearson_r]
        end
        for p in valid_preds, fv in all_flux_vars
    ]

    p_heat = heatmap(
        all_flux_vars,
        valid_preds,
        mat;
        color=:RdBu,
        clim=(-1, 1),
        title="Pearson r: DCT coefficients vs Flux variables",
        xlabel="Flux variable",
        ylabel="Spectral predictor",
        xrotation=30,
        xtickfontsize=7,
    )
    savefig(p_heat, joinpath(OUT_DIR, "plot_corr_heatmap.png"))
    println("Heatmap saved")
end

# ── Per-pair scatter plots for |r| >= threshold ───────────────────────────────
default(size=(650, 550), dpi=120)

stability_colors = Dict(
    "stable"            => :blue,
    "strongly_stable"   => :darkblue,
    "near_neutral"      => :green,
    "unstable"          => :orange,
    "strongly_unstable" => :red,
    "unknown"           => :gray,
)

scatter_count = 0
for row in eachrow(corr_df)
    isnan(row.pearson_r) && continue
    abs(row.pearson_r) < CORR_THRESHOLD && continue

    pred = row.predictor
    fv   = row.flux_var
    pred in names(joined) || continue
    fv   in names(joined) || continue

    x = _safe_float.(joined[!, pred])
    y = _safe_float.(joined[!, fv])
    ok = .!isnan.(x) .& .!isnan.(y)
    sum(ok) < 4 && continue

    stab = "stability" in names(joined) ? string.(coalesce.(joined[!, :stability], "unknown")) : fill("unknown", nrow(joined))
    colors = [get(stability_colors, s, :gray) for s in stab[ok]]

    title_str = @sprintf("%s vs %s  r=%.3f  ρ=%.3f  N=%d",
        pred, fv, row.pearson_r, row.spearman_rho, row.n)

    p = scatter(
        x[ok], y[ok];
        color=colors,
        markersize=3.5,
        alpha=0.55,
        xlabel=pred,
        ylabel=fv,
        title=title_str,
        legend=false,
        titlefontsize=8,
    )

    fname = replace("plot_$(pred)_vs_$(replace(fv, "." => "_")).png", "/" => "_")
    savefig(p, joinpath(OUT_DIR, fname))
    scatter_count += 1
end
println("Scatter plots saved: $(scatter_count) pairs with |r| >= $(CORR_THRESHOLD)")

# ── Markdown report ───────────────────────────────────────────────────────────
open(joinpath(OUT_DIR, "report.md"), "w") do io
    write(io, "# DCT Fingerprint × Flux Correlation Report\n\n")
    write(io, "- Season: $(SEASON)\n")
    write(io, "- Fingerprints from: $(FP_DIR)\n")
    write(io, "- Heat flux CSV: $(FLUX_CSV)\n")
    write(io, "- Momentum flux CSV: $(MOMENTUM_CSV)\n")
    write(io, "- CO₂ tracers CSV: $(CO2_CSV)\n")
    write(io, "- Quality control: Qc ≤ $(QC_MAX)\n")
    write(io, "- Joined rows: $(nrow(joined))\n")
    write(io, "- Flux variables available: $(length(all_flux_vars))\n")
    write(io, "- Correlation threshold for scatter plots: |r| ≥ $(CORR_THRESHOLD)\n\n")

    write(io, "## Correlation Summary\n\n")
    write(io, "| Predictor | Flux variable | Pearson r | Spearman ρ | N |\n")
    write(io, "|-----------|--------------|-----------|------------|---|\n")

    sorted_corr = sort(corr_df, :pearson_r; by=abs, rev=true)
    for row in eachrow(sorted_corr)
        isnan(row.pearson_r) && continue
        write(io, @sprintf("| %s | %s | %.4f | %.4f | %d |\n",
            row.predictor, row.flux_var, row.pearson_r, row.spearman_rho, row.n))
    end

    write(io, "\n## Strongest Associations (|r| ≥ 0.3)\n\n")
    strong = filter(r -> !isnan(r.pearson_r) && abs(r.pearson_r) >= 0.3, sorted_corr)
    if isempty(strong)
        write(io, "_No pairs exceeded the 0.3 threshold._\n")
    else
        for row in eachrow(strong)
            sign = row.pearson_r > 0 ? "positive" : "negative"
            write(io, @sprintf("- **%s** × **%s**: r = %.3f (%s), N = %d\n",
                row.predictor, row.flux_var, row.pearson_r, sign, row.n))
        end
    end

    write(io, "\n## Output Files\n\n")
    write(io, "- `flux_fingerprint_joined.csv`\n")
    write(io, "- `flux_correlation_matrix.csv`\n")
    write(io, "- `plot_corr_heatmap.png`\n")
    write(io, "- $(scatter_count) scatter plot(s) for |r| ≥ $(CORR_THRESHOLD)\n")
end

println("Report: $(joinpath(OUT_DIR, "report.md"))")
println("Done.")
