include(joinpath(@__DIR__, "SmearPipeline.jl"))
using .SmearPipeline
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

# 1. Pull Temperature and CO2 data
t_cols = ["HYY_META.Tst33", "HYY_META.Tst88", "HYY_META.Tst168", "HYY_META.Tst270"]
vars = vcat(t_cols, [SmearPipeline.HYY_VARS[:L_obukhov], SmearPipeline.HYY_VARS[:ustar]])

raw_df = fetch_smear_tiled(vars, DateTime(2025, 5, 1), DateTime(2025, 6, 1))

# 2. Build 30-min median profiles (ICOS mast temperature profile)
t_heights = [3.3, 8.8, 16.8, 27.0]
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