include(joinpath(@__DIR__, "SmearPipeline.jl"))
include(joinpath(@__DIR__, "SMEARVarLookup.jl"))
using .SmearPipeline
using .SMEARVarLookup
using CSV
using DataFrames
using Dates
using Plots
using Printf
using Statistics
include(joinpath(@__DIR__, "compute_bulk_richardson.jl"))

const START_DT = DateTime(2025, 5, 1)
const END_DT   = DateTime(2025, 6, 1)
const DEFAULT_OUT_DIR = joinpath(@__DIR__, "..", "..", "runs", "dct_smear_20250501_20250601")
const OUT_DIR  = get(ENV, "DCT_SMEAR_OUT_DIR", DEFAULT_OUT_DIR)
const STATUS_PATH = joinpath(OUT_DIR, "run_status.txt")
const ROLLING_WINDOW = parse(Int, get(ENV, "DCT_SMEAR_ROLLING_WINDOW", "6"))
const QC_MAX = parse(Int, get(ENV, "DCT_SMEAR_QC_MAX", "1"))
const FETCH_INTERACTION_FLUX = lowercase(get(ENV, "DCT_SMEAR_FETCH_INTERACTION_FLUX", "true")) == "true"
mkpath(OUT_DIR)

write_status(lines::Vector{String}) = open(STATUS_PATH, "w") do io
	for line in lines
		write(io, line * "\n")
	end
end

function remove_stale_plots()
	for path in [
		joinpath(OUT_DIR, "plot_stability_counts.png"),
		joinpath(OUT_DIR, "plot_shape_ratio_vs_zeta.png"),
		joinpath(OUT_DIR, "plot_coeff_distributions.png"),
		joinpath(OUT_DIR, "plot_c3_c1_hist.png"),
		joinpath(OUT_DIR, "plot_phase_c1_c3.png"),
		joinpath(OUT_DIR, "plot_c3_vs_co2_storage_flux.png"),
		joinpath(OUT_DIR, "plot_c3_vs_f_c.png"),
		joinpath(OUT_DIR, "plot_rolling_corr_H_tau.png"),
		joinpath(OUT_DIR, "plot_rib_vs_c3.png"),
	]
		isfile(path) && rm(path; force=true)
	end
end

function _safe_float(x)
	if x isa Number
		return Float64(x)
	elseif x isa AbstractString
		y = tryparse(Float64, strip(x))
		return isnothing(y) ? NaN : y
	end
	return NaN
end

function _normalize_datetime!(df::DataFrame)
	:datetime in propertynames(df) || error("DataFrame must contain datetime")
	if eltype(df.datetime) <: AbstractString
		df.datetime = DateTime.(df.datetime)
	elseif !(eltype(df.datetime) <: DateTime)
		df.datetime = DateTime.(string.(df.datetime))
	end
	return df
end

function _rolling_corr(x::Vector{Float64}, y::Vector{Float64}, window::Int)
	n = length(x)
	n <= window && return Float64[]
	out = Vector{Float64}(undef, n - window)
	for i in 1:(n - window)
		xw = x[i:(i + window)]
		yw = y[i:(i + window)]
		ok = .!isnan.(xw) .& .!isnan.(yw)
		if sum(ok) < 4
			out[i] = NaN
		else
			out[i] = cor(xw[ok], yw[ok])
		end
	end
	return out
end

function infer_station_label(raw_df::DataFrame, input_csv::String)
	name_vec = String.(names(raw_df))
	path_lc = lowercase(input_csv)

	if any(c -> startswith(c, "HYY_"), name_vec) || occursin("hyy", path_lc) || occursin("hyyti", path_lc)
		return "Hyytiälä"
	end
	if any(c -> startswith(c, "VAR_"), name_vec) || occursin("varrio", path_lc) || occursin("vrr", path_lc)
		return "Värriö"
	end
	return "SMEAR"
end

function fetch_interaction_flux(start_dt::DateTime, end_dt::DateTime)
	# Tier-3 covariance variables for dynamic coupling diagnostics.
	vars = unique(vcat(
		SMEARVarLookup.varrio_dct_vars(:flux_core),
		SMEARVarLookup.varrio_dct_vars(:flux_quality),
		SMEARVarLookup.varrio_dct_vars(:flux_storage),
	))
	try
		return fetch_smear_tiled(vars, start_dt, end_dt)
	catch err
		@warn "Interaction flux fetch failed; continuing without extra flux vars" exception=(err, catch_backtrace())
		return DataFrame()
	end
end

function ensure_interaction_columns(raw_df::DataFrame, input_csv::String)
	required_any = ["VAR_EDDY.H", "VAR_EDDY.tau", "VAR_EDDY.F_c", "VAR_EDDY.CO2_storage_flux"]
	if any(c -> c in names(raw_df), required_any)
		return raw_df, "embedded"
	end
	if !FETCH_INTERACTION_FLUX
		return raw_df, "disabled"
	end

	# In CSV mode, infer date bounds from provided data; in API mode use run bounds.
	start_dt = isempty(input_csv) ? START_DT : minimum(raw_df.datetime)
	end_dt = isempty(input_csv) ? END_DT : maximum(raw_df.datetime)
	flux_df = fetch_interaction_flux(start_dt, end_dt)
	if isempty(flux_df) || !(:datetime in propertynames(flux_df))
		return raw_df, "missing"
	end

	_normalize_datetime!(flux_df)
	merged = leftjoin(raw_df, flux_df; on=:datetime, makeunique=true)
	return merged, "fetched"
end

function interaction_diagnostics(raw_df::DataFrame, fingerprints::DataFrame)
	interaction_vars = [
		"VAR_EDDY.H",
		"VAR_EDDY.tau",
		"VAR_EDDY.F_c",
		"VAR_EDDY.CO2_storage_flux",
		"VAR_EDDY.U",
		"VAR_EDDY.Qc_H",
		"VAR_EDDY.Qc_tau",
		"VAR_EDDY.Qc_F_c",
	]
	avail = [c for c in interaction_vars if c in names(raw_df)]
	if isempty(avail)
		return DataFrame(), DataFrame(), DataFrame()
	end

	df = select(raw_df, :datetime, avail)
	df.datetime = floor.(df.datetime, Minute(30))

	# Apply flux quality masks when quality columns are present.
	if all(c -> c in names(df), ["VAR_EDDY.H", "VAR_EDDY.Qc_H"])
		for i in 1:nrow(df)
			q = _safe_float(df[i, "VAR_EDDY.Qc_H"])
			if !isnan(q) && q > QC_MAX
				df[i, "VAR_EDDY.H"] = missing
			end
		end
	end
	if all(c -> c in names(df), ["VAR_EDDY.tau", "VAR_EDDY.Qc_tau"])
		for i in 1:nrow(df)
			q = _safe_float(df[i, "VAR_EDDY.Qc_tau"])
			if !isnan(q) && q > QC_MAX
				df[i, "VAR_EDDY.tau"] = missing
			end
		end
	end
	if all(c -> c in names(df), ["VAR_EDDY.F_c", "VAR_EDDY.Qc_F_c"])
		for i in 1:nrow(df)
			q = _safe_float(df[i, "VAR_EDDY.Qc_F_c"])
			if !isnan(q) && q > QC_MAX
				df[i, "VAR_EDDY.F_c"] = missing
			end
		end
	end

	agg = combine(groupby(df, :datetime), names(df, Not(:datetime)) .=> (v -> begin
		x = filter(!isnan, _safe_float.(v))
		isempty(x) ? NaN : median(x)
	end) .=> names(df, Not(:datetime)))

	fp_cols = [c for c in [:datetime, :c1, :c2, :c3, :shape_ratio] if c in propertynames(fingerprints)]
	fp = select(fingerprints, fp_cols)
	fp.datetime = floor.(fp.datetime, Minute(30))
	fp = combine(groupby(fp, :datetime), names(fp, Not(:datetime)) .=> (v -> begin
		x = filter(!isnan, _safe_float.(v))
		isempty(x) ? NaN : median(x)
	end) .=> names(fp, Not(:datetime)))

	joined = innerjoin(fp, agg; on=:datetime)
	if isempty(joined)
		return DataFrame(), DataFrame(), DataFrame()
	end

	CSV.write(joinpath(OUT_DIR, "interaction_joined.csv"), joined)

	# Rolling H-tau correlation as coupling proxy.
	rolling = DataFrame()
	if all(c -> c in names(joined), ["VAR_EDDY.H", "VAR_EDDY.tau"])
		x = _safe_float.(joined[!, "VAR_EDDY.H"])
		y = _safe_float.(joined[!, "VAR_EDDY.tau"])
		rc = _rolling_corr(x, y, ROLLING_WINDOW)
		if !isempty(rc)
			rolling = DataFrame(
				datetime = joined.datetime[1:length(rc)],
				corr_H_tau = rc,
			)
			CSV.write(joinpath(OUT_DIR, "interaction_rolling_corr.csv"), rolling)
		end
	end

	rib_summary = DataFrame()
	if all(c -> c in names(joined), ["VAR_META.TDRY4", "VAR_META.TDRY0"]) && ("VAR_META.WS0" in names(joined) || "VAR_EDDY.U" in names(joined))
		ws_col = "VAR_META.WS0" in names(joined) ? Symbol("VAR_META.WS0") : Symbol("VAR_EDDY.U")
		rib_vals = compute_bulk_richardson(
			joined,
			2.2,
			15.0,
			Symbol("VAR_META.TDRY4"),
			Symbol("VAR_META.TDRY0"),
			ws_col,
		)
		joined.rib = _safe_float.(rib_vals)
		lam = joined.rib .> 0.25
		valid_c3 = .!isnan.(joined.c3)
		c3_lam = joined.c3[lam .& valid_c3]
		c3_mix = joined.c3[.!lam .& valid_c3]
		rib_summary = DataFrame(
			metric=["rib_window_count", "rib_laminar_count", "rib_laminar_fraction", "c3_median_laminar", "c3_median_non_laminar"],
			value=[nrow(joined), sum(lam), sum(lam) / max(nrow(joined), 1), isempty(c3_lam) ? NaN : median(c3_lam), isempty(c3_mix) ? NaN : median(c3_mix)],
		)
		CSV.write(joinpath(OUT_DIR, "rib_diagnostics_summary.csv"), rib_summary)
		CSV.write(joinpath(OUT_DIR, "rib_laminar_events.csv"), filter(:rib => r -> !isnan(r) && r > 0.25, joined))
	end

	return joined, rolling, rib_summary
end

function fetch_temperature_with_fallback(start_dt::DateTime, end_dt::DateTime)
	candidates = [
		(
			name = "legacy_aliases",
			cols = [
				SmearPipeline.VAR_VARS[:T_2m],
				SmearPipeline.VAR_VARS[:T_4m],
				SmearPipeline.VAR_VARS[:T_6_6m],
				SmearPipeline.VAR_VARS[:T_9m],
				SmearPipeline.VAR_VARS[:T_15m],
			],
			heights = SmearPipeline.VAR_HEIGHTS[:T],
		),
		(
			name = "metadata_tdry",
			cols = ["VAR_META.TDRY4", "VAR_META.TDRY3", "VAR_META.TDRY2", "VAR_META.TDRY1", "VAR_META.TDRY0"],
			heights = [2.2, 4.4, 6.6, 9.0, 15.0],
		),
	]

	last_err = nothing
	for candidate in candidates
		try
			df = fetch_smear_tiled(candidate.cols, start_dt, end_dt)
			if nrow(df) > 0
				return df, candidate.cols, candidate.heights, candidate.name
			end
			@warn "Candidate returned no rows" candidate=candidate.name
		catch err
			last_err = err
			@warn "Candidate fetch failed" candidate=candidate.name exception=(err, catch_backtrace())
		end
	end

	error("All temperature-variable candidates failed. Last error: $(last_err)")
end

function load_temperature_input_csv(path::AbstractString)
	df = CSV.read(path, DataFrame; missingstring=["", "NaN", "NA"])
	:datetime in propertynames(df) || error("Input CSV must contain a datetime column: $(path)")

	# Normalize datetime type for downstream windowing in build_vertical_profiles.
	if eltype(df.datetime) <: AbstractString
		df.datetime = DateTime.(df.datetime)
	elseif !(eltype(df.datetime) <: DateTime)
		df.datetime = DateTime.(string.(df.datetime))
	end

	if Symbol("VAR_EDDY.MO_length") in names(df) && !( :L_obukhov in propertynames(df) )
		df.L_obukhov = df[!, Symbol("VAR_EDDY.MO_length")]
	end
	if Symbol("VAR_EDDY.u_star") in names(df) && !( :ustar in propertynames(df) )
		df.ustar = df[!, Symbol("VAR_EDDY.u_star")]
	end

	metadata_cols = ["VAR_META.TDRY4", "VAR_META.TDRY3", "VAR_META.TDRY2", "VAR_META.TDRY1", "VAR_META.TDRY0"]
	metadata_heights = [2.2, 4.4, 6.6, 9.0, 15.0]
	legacy_cols = [
		SmearPipeline.VAR_VARS[:T_2m],
		SmearPipeline.VAR_VARS[:T_4m],
		SmearPipeline.VAR_VARS[:T_6_6m],
		SmearPipeline.VAR_VARS[:T_9m],
		SmearPipeline.VAR_VARS[:T_15m],
	]
	legacy_heights = SmearPipeline.VAR_HEIGHTS[:T]

	function _keep_available(cols::Vector{String}, heights::Vector{Float64})
		kept_cols = String[]
		kept_heights = Float64[]
		for (c, h) in zip(cols, heights)
			c in names(df) || continue
			vals = _safe_float.(df[!, c])
			any(v -> !isnan(v), vals) || continue
			push!(kept_cols, c)
			push!(kept_heights, h)
		end
		return kept_cols, kept_heights
	end

	meta_cols, meta_heights = _keep_available(metadata_cols, metadata_heights)
	legacy_cols_kept, legacy_heights_kept = _keep_available(legacy_cols, legacy_heights)

	if length(meta_cols) >= 3
		return df, meta_cols, meta_heights, "preprocessed_csv:metadata_tdry_dynamic"
	elseif length(legacy_cols_kept) >= 3
		return df, legacy_cols_kept, legacy_heights_kept, "preprocessed_csv:legacy_aliases_dynamic"
	end

	error("Input CSV missing sufficient usable temperature profile columns for DCT_SMEAR (need >=3 with non-missing values): $(path)")
end


# --- VÄRRIÖ (STATION 1) ---
run_started = now()
write_status([
	"status=running",
	"started=$(run_started)",
	"out_dir=$(OUT_DIR)",
	"time_range=$(START_DT) to $(END_DT)",
])

# 1. Pull Temperature data with fallback variable sets (or load preprocessed seasonal CSV)
input_csv = get(ENV, "DCT_SMEAR_INPUT_CSV", "")
raw_df, t_cols, t_heights, fetch_source = if isempty(input_csv)
	fetch_temperature_with_fallback(START_DT, END_DT)
else
	load_temperature_input_csv(input_csv)
end
_normalize_datetime!(raw_df)
raw_df, flux_source = ensure_interaction_columns(raw_df, input_csv)
station_label = infer_station_label(raw_df, input_csv)

# 2. Build 30-min median profiles (Värriö mast temperature profile)
profiles = build_vertical_profiles(raw_df, :T; col_names=t_cols, heights=t_heights)

# 3. Transform to Spectral Space
fingerprints = batch_fingerprint(profiles, :T)

if isempty(fingerprints)
	report_path = joinpath(OUT_DIR, "report.md")
	CSV.write(joinpath(OUT_DIR, "fingerprints.csv"), DataFrame())
	CSV.write(joinpath(OUT_DIR, "stable_events.csv"), DataFrame())
	CSV.write(joinpath(OUT_DIR, "stability_counts.csv"), DataFrame(stability=String[], count=Int[]))
	CSV.write(joinpath(OUT_DIR, "diagnostics_summary.csv"), DataFrame(metric=["n_profiles", "fetch_source"], value=[0.0, NaN]))
	remove_stale_plots()

	open(report_path, "w") do io
		write(io, "# DCT-SMEAR Results\n\n")
		write(io, "No fingerprints were generated for the requested window.\n\n")
		write(io, "- Time range: $(START_DT) to $(END_DT)\n")
		write(io, "- Fetch source: $(fetch_source)\n")
		write(io, "- Raw rows fetched: $(nrow(raw_df))\n")
		write(io, "- Profiles fingerprinted: 0\n")
		write(io, "\nTry a different date range or verify variable availability for this station/time period.\n")
	end

	write_status([
		"status=no_fingerprints",
		"started=$(run_started)",
		"finished=$(now())",
		"fetch_source=$(fetch_source)",
		"flux_source=$(flux_source)",
		"raw_rows=$(nrow(raw_df))",
		"profiles=0",
		"fingerprints=0",
		"report=$(report_path)",
	])

	println("No fingerprints generated. Wrote status: $(STATUS_PATH)")
	println("Report: $(report_path)")

else

# 4. Classify and Analyze
SmearPipeline.add_stability_class!(fingerprints)

# Look for the "Fractal" signature in Stable regimes
stable_events = filter(r -> r.stability == :stable, fingerprints)

# 5. Persist data products
CSV.write(joinpath(OUT_DIR, "fingerprints.csv"), fingerprints)
CSV.write(joinpath(OUT_DIR, "stable_events.csv"), stable_events)

counts = combine(groupby(fingerprints, :stability), nrow => :count)
sort!(counts, :count, rev=true)
CSV.write(joinpath(OUT_DIR, "stability_counts.csv"), counts)

coef_stats = DataFrame(
	metric = ["n_profiles", "n_stable", "stable_fraction", "mean_c2", "mean_c3", "mean_shape_ratio", "median_ustar", "fetch_source", "flux_source"],
	value = [
		nrow(fingerprints),
		nrow(stable_events),
		nrow(stable_events) / nrow(fingerprints),
		mean(skipmissing(fingerprints.c2)),
		mean(skipmissing(fingerprints.c3)),
		mean(skipmissing(fingerprints.shape_ratio)),
		median(skipmissing(fingerprints.ustar)),
		NaN,
		NaN,
	],
)
CSV.write(joinpath(OUT_DIR, "diagnostics_summary.csv"), coef_stats)

interaction_df, rolling_df, rib_summary = interaction_diagnostics(raw_df, fingerprints)

# 6. Plots
default(size=(1100, 700), dpi=140)

p_counts = bar(
	string.(counts.stability),
	counts.count;
	xlabel="Stability class",
	ylabel="Count",
	title="DCT-SMEAR Stability Regime Counts (May 2025)",
	legend=false,
)
savefig(p_counts, joinpath(OUT_DIR, "plot_stability_counts.png"))

valid_shape = .!isnan.(fingerprints.zeta) .& .!isnan.(fingerprints.shape_ratio)
p_shape = scatter(
	fingerprints.zeta[valid_shape],
	fingerprints.shape_ratio[valid_shape];
	markersize=2.0,
	alpha=0.35,
	xlabel="zeta",
	ylabel="shape_ratio = |c3| / |c2|",
	title="Curvature-to-Gradient Ratio vs Stability",
	legend=false,
)
savefig(p_shape, joinpath(OUT_DIR, "plot_shape_ratio_vs_zeta.png"))


# Histogram of c2 and c3
p_coeff = histogram(
	[fingerprints.c2 fingerprints.c3];
	bins=50,
	alpha=0.6,
	normalize=:pdf,
	label=["c2" "c3"],
	xlabel="Coefficient value",
	ylabel="Density",
	title="Spectral Coefficient Distributions",
)
savefig(p_coeff, joinpath(OUT_DIR, "plot_coeff_distributions.png"))

# --- Plot c3/c1 ratio ---
if hasproperty(fingerprints, :c1) && hasproperty(fingerprints, :c3)
	valid_c1 = .!isnan.(fingerprints.c1) .& (abs.(fingerprints.c1) .> 1e-8)
	c3_c1 = fingerprints.c3[valid_c1] ./ fingerprints.c1[valid_c1]
	p_c3c1 = histogram(
		c3_c1;
		bins=50,
		alpha=0.7,
		xlabel="c3 / c1",
		ylabel="Density",
		title="Distribution of c3/c1 ($(station_label))",
		legend=false,
	)
	savefig(p_c3c1, joinpath(OUT_DIR, "plot_c3_c1_hist.png"))
end

# --- Phase portrait: c1 vs c3 ---
if hasproperty(fingerprints, :c1) && hasproperty(fingerprints, :c3)
	valid_phase = .!isnan.(fingerprints.c1) .& .!isnan.(fingerprints.c3)
	p_phase = scatter(
		fingerprints.c1[valid_phase],
		fingerprints.c3[valid_phase];
		alpha=0.5,
		markersize=2.5,
		xlabel="c1",
		ylabel="c3",
		title="Phase Portrait: c1 vs c3 ($(station_label))",
		legend=false,
	)
	savefig(p_phase, joinpath(OUT_DIR, "plot_phase_c1_c3.png"))
end

# --- Interaction plots: c3 vs tracer flux and rolling H-tau coupling ---
if !isempty(interaction_df) && all(c -> c in names(interaction_df), ["c3", "VAR_EDDY.CO2_storage_flux"])
	valid_storage = .!isnan.(_safe_float.(interaction_df.c3)) .& .!isnan.(_safe_float.(interaction_df[!, "VAR_EDDY.CO2_storage_flux"]))
	if any(valid_storage)
		p_c3_storage = scatter(
			interaction_df.c3[valid_storage],
			interaction_df[valid_storage, "VAR_EDDY.CO2_storage_flux"];
			alpha=0.5,
			markersize=2.8,
			xlabel="c3",
			ylabel="CO2 storage flux",
			title="Curvature c3 vs CO2 storage flux",
			legend=false,
		)
		savefig(p_c3_storage, joinpath(OUT_DIR, "plot_c3_vs_co2_storage_flux.png"))
	end
elseif !isempty(interaction_df) && all(c -> c in names(interaction_df), ["c3", "VAR_EDDY.F_c"])
	valid_fc = .!isnan.(_safe_float.(interaction_df.c3)) .& .!isnan.(_safe_float.(interaction_df[!, "VAR_EDDY.F_c"]))
	if any(valid_fc)
		p_c3_fc = scatter(
			interaction_df.c3[valid_fc],
			interaction_df[valid_fc, "VAR_EDDY.F_c"];
			alpha=0.5,
			markersize=2.8,
			xlabel="c3",
			ylabel="CO2 flux F_c",
			title="Curvature c3 vs CO2 flux",
			legend=false,
		)
		savefig(p_c3_fc, joinpath(OUT_DIR, "plot_c3_vs_f_c.png"))
	end
end

if !isempty(rolling_df)
	valid_rc = .!isnan.(_safe_float.(rolling_df.corr_H_tau))
	if any(valid_rc)
		p_roll = plot(
			rolling_df.datetime[valid_rc],
			rolling_df.corr_H_tau[valid_rc];
			lw=1.8,
			xlabel="datetime",
			ylabel="corr(H, tau)",
			title="Rolling interaction: Heat vs Momentum (window=$(ROLLING_WINDOW + 1) samples)",
			legend=false,
		)
		hline!(p_roll, [0.0]; color=:black, linestyle=:dash, label="")
		savefig(p_roll, joinpath(OUT_DIR, "plot_rolling_corr_H_tau.png"))
	end
end

if !isempty(interaction_df) && all(c -> c in names(interaction_df), ["rib", "c3"])
	valid_rib = .!isnan.(_safe_float.(interaction_df.rib)) .& .!isnan.(_safe_float.(interaction_df.c3))
	if any(valid_rib)
		p_rib = scatter(
			interaction_df.rib[valid_rib],
			interaction_df.c3[valid_rib];
			alpha=0.45,
			markersize=2.8,
			xlabel="Ri_b",
			ylabel="c3",
			title="Bulk Richardson vs DCT curvature c3",
			legend=false,
		)
		vline!(p_rib, [0.25]; color=:red, linestyle=:dash, label="")
		savefig(p_rib, joinpath(OUT_DIR, "plot_rib_vs_c3.png"))
	end
end

# 7. Markdown report
stable_frac_pct = 100 * nrow(stable_events) / nrow(fingerprints)
report_path = joinpath(OUT_DIR, "report.md")
open(report_path, "w") do io
	write(io, "# DCT-SMEAR Results\n\n")
	write(io, "- Time range: $(START_DT) to $(END_DT)\n")
	write(io, "- Temperature fetch source: $(fetch_source)\n")
	write(io, "- Interaction flux source: $(flux_source)\n")
	write(io, "- Raw rows fetched: $(nrow(raw_df))\n")
	write(io, "- Profiles fingerprinted: $(nrow(fingerprints))\n")
	write(io, @sprintf("- Stable events: %d (%.1f%%)\n\n", nrow(stable_events), stable_frac_pct))

	write(io, "## Stability Counts\n\n")
	for row in eachrow(counts)
		write(io, "- $(row.stability): $(row.count)\n")
	end

	write(io, "\n## Key Diagnostics\n\n")
	for row in eachrow(coef_stats)
		write(io, @sprintf("- %s: %.6g\n", row.metric, row.value))
	end

	write(io, "\n## Output Files\n\n")
	write(io, "- fingerprints.csv\n")
	write(io, "- stable_events.csv\n")
	write(io, "- stability_counts.csv\n")
	write(io, "- diagnostics_summary.csv\n")
	write(io, "- plot_stability_counts.png\n")
	write(io, "- plot_shape_ratio_vs_zeta.png\n")
	write(io, "- plot_coeff_distributions.png\n")
	if !isempty(interaction_df)
		write(io, "- interaction_joined.csv\n")
		if isfile(joinpath(OUT_DIR, "interaction_rolling_corr.csv"))
			write(io, "- interaction_rolling_corr.csv\n")
			write(io, "- plot_rolling_corr_H_tau.png\n")
		end
		if isfile(joinpath(OUT_DIR, "plot_c3_vs_co2_storage_flux.png"))
			write(io, "- plot_c3_vs_co2_storage_flux.png\n")
		elseif isfile(joinpath(OUT_DIR, "plot_c3_vs_f_c.png"))
			write(io, "- plot_c3_vs_f_c.png\n")
		end
		if !isempty(rib_summary)
			write(io, "- rib_diagnostics_summary.csv\n")
			write(io, "- rib_laminar_events.csv\n")
			if isfile(joinpath(OUT_DIR, "plot_rib_vs_c3.png"))
				write(io, "- plot_rib_vs_c3.png\n")
			end
		end
	end
end

write_status([
	"status=ok",
	"started=$(run_started)",
	"finished=$(now())",
	"fetch_source=$(fetch_source)",
	"flux_source=$(flux_source)",
	"raw_rows=$(nrow(raw_df))",
	"profiles=$(nrow(profiles))",
	"fingerprints=$(nrow(fingerprints))",
	"stable_events=$(nrow(stable_events))",
	"interaction_rows=$(isempty(interaction_df) ? 0 : nrow(interaction_df))",
	"rolling_corr_rows=$(isempty(rolling_df) ? 0 : nrow(rolling_df))",
	"rib_summary_rows=$(isempty(rib_summary) ? 0 : nrow(rib_summary))",
	"report=$(report_path)",
])

println("Results written to: $(OUT_DIR)")
println("Report: $(report_path)")
println("Status: $(STATUS_PATH)")

end