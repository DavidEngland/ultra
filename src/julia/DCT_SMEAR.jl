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

const START_DT = DateTime(2025, 5, 1)
const END_DT   = DateTime(2025, 6, 1)
const OUT_DIR  = joinpath(@__DIR__, "..", "..", "runs", "dct_smear_20250501_20250601")
mkpath(OUT_DIR)


# --- VÄRRIÖ (STATION 1) ---
# 1. Pull Temperature data (existing runtime mapping)
t_cols = [SmearPipeline.VAR_VARS[:T_2m], SmearPipeline.VAR_VARS[:T_4m], SmearPipeline.VAR_VARS[:T_6_6m], SmearPipeline.VAR_VARS[:T_9m], SmearPipeline.VAR_VARS[:T_15m]]
vars = t_cols

raw_df = fetch_smear_tiled(vars, DateTime(2025, 5, 1), DateTime(2025, 6, 1))

# 2. Build 30-min median profiles (Värriö mast temperature profile)
t_heights = SmearPipeline.VAR_HEIGHTS[:T]
profiles = build_vertical_profiles(raw_df, :T; col_names=t_cols, heights=t_heights)

# 3. Transform to Spectral Space
fingerprints = batch_fingerprint(profiles, :T)

isempty(fingerprints) && error("No fingerprints generated for requested range; try a different date window or fewer missing-sensitive variables.")

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
	metric = ["n_profiles", "n_stable", "stable_fraction", "mean_c2", "mean_c3", "mean_shape_ratio", "median_ustar"],
	value = [
		nrow(fingerprints),
		nrow(stable_events),
		nrow(stable_events) / nrow(fingerprints),
		mean(skipmissing(fingerprints.c2)),
		mean(skipmissing(fingerprints.c3)),
		mean(skipmissing(fingerprints.shape_ratio)),
		median(skipmissing(fingerprints.ustar)),
	],
)
CSV.write(joinpath(OUT_DIR, "diagnostics_summary.csv"), coef_stats)

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
		title="Distribution of c3/c1 (Värriö)",
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
		title="Phase Portrait: c1 vs c3 (Värriö)",
		legend=false,
	)
	savefig(p_phase, joinpath(OUT_DIR, "plot_phase_c1_c3.png"))
end

# 7. Markdown report
stable_frac_pct = 100 * nrow(stable_events) / nrow(fingerprints)
report_path = joinpath(OUT_DIR, "report.md")
open(report_path, "w") do io
	write(io, "# DCT-SMEAR Results\n\n")
	write(io, "- Time range: $(START_DT) to $(END_DT)\n")
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
end

println("Results written to: $(OUT_DIR)")
println("Report: $(report_path)")