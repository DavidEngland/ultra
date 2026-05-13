using CSV
using DataFrames
using Printf
using Statistics
using FFTW
using Plots

const REPO_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const IN_CSV = joinpath(REPO_ROOT, "runs", "sheba", "input", "sheba_input.csv")
const OUT_DIR = joinpath(REPO_ROOT, "runs", "sheba", "dct_main_file6")
mkpath(OUT_DIR)

const N_BINS = 48
const N_KEEP = 8

function midpoints(edges::Vector{Float64})
	return 0.5 .* (edges[1:end-1] .+ edges[2:end])
end

function clean_input(df::DataFrame)
	req = [:zeta, :phi_obs]
	for c in req
		hasproperty(df, c) || error("Missing required column: $(c)")
	end

	out = dropmissing(select(df, [:zeta, :phi_obs]))
	filter!(r -> isfinite(r.zeta) && isfinite(r.phi_obs), out)
	filter!(r -> r.zeta > 0.0 && r.phi_obs > 0.0, out)
	return out
end

function make_binned_profile(df::DataFrame; nbins::Int=N_BINS)
	z = collect(df.zeta)
	p = collect(df.phi_obs)

	qs = range(0.0, 1.0; length=nbins+1)
	edges = [quantile(z, q) for q in qs]
	for i in 2:length(edges)
		edges[i] = max(edges[i], edges[i-1] + eps(Float64))
	end

	z_mid = Float64[]
	phi_med = Float64[]
	phi_mean = Float64[]
	n = Int[]

	for b in 1:nbins
		lo, hi = edges[b], edges[b+1]
		idx = b < nbins ? findall(x -> x >= lo && x < hi, z) : findall(x -> x >= lo && x <= hi, z)
		if isempty(idx)
			continue
		end
		vals = p[idx]
		push!(z_mid, 0.5 * (lo + hi))
		push!(phi_med, median(vals))
		push!(phi_mean, mean(vals))
		push!(n, length(idx))
	end

	return DataFrame(zeta_mid=z_mid, phi_med=phi_med, phi_mean=phi_mean, n=n)
end

function dct_reconstruct(y::Vector{Float64}; nkeep::Int=N_KEEP)
	c = dct(y)
	c_trunc = zeros(length(c))
	c_trunc[1:min(nkeep, length(c))] .= c[1:min(nkeep, length(c))]
	yhat = idct(c_trunc)
	return c, c_trunc, yhat
end

function regime_stats(df::DataFrame)
	ranges = [
		("weak_stable", 0.0, 0.5),
		("moderate_stable", 0.5, 2.0),
		("very_stable", 2.0, 10.0),
	]

	out = DataFrame(
		regime=String[],
		zeta_min=Float64[],
		zeta_max=Float64[],
		n=Int[],
		zeta_median=Float64[],
		phi_median=Float64[],
		phi_mean=Float64[],
	)

	for (name, lo, hi) in ranges
		sub = filter(r -> r.zeta > lo && r.zeta <= hi, df)
		if isempty(sub)
			push!(out, (name, lo, hi, 0, NaN, NaN, NaN))
		else
			push!(out, (name, lo, hi, nrow(sub), median(sub.zeta), median(sub.phi_obs), mean(sub.phi_obs)))
		end
	end
	return out
end

df0 = CSV.read(IN_CSV, DataFrame)
df = clean_input(df0)

profile = make_binned_profile(df)
y = collect(profile.phi_med)
c_full, c_trunc, yhat = dct_reconstruct(y)

rmse = sqrt(mean((y .- yhat).^2))
mae = mean(abs.(y .- yhat))
var_keep = sum(abs2, c_trunc) / max(sum(abs2, c_full), eps(Float64))

coeff_df = DataFrame(
	mode=collect(0:length(c_full)-1),
	coeff=c_full,
	coeff_trunc=c_trunc,
	abs_coeff=abs.(c_full),
)

recon_df = DataFrame(
	zeta_mid=profile.zeta_mid,
	phi_med=profile.phi_med,
	phi_recon=yhat,
	n=profile.n,
)

reg_df = regime_stats(df)

diag_df = DataFrame(
	metric=["n_rows", "n_bins", "n_modes_kept", "rmse_binned", "mae_binned", "variance_fraction_kept"],
	value=[nrow(df), nrow(profile), N_KEEP, rmse, mae, var_keep],
)

CSV.write(joinpath(OUT_DIR, "sheba_binned_profile.csv"), profile)
CSV.write(joinpath(OUT_DIR, "sheba_dct_coeffs.csv"), coeff_df)
CSV.write(joinpath(OUT_DIR, "sheba_dct_reconstruction.csv"), recon_df)
CSV.write(joinpath(OUT_DIR, "sheba_regime_stats.csv"), reg_df)
CSV.write(joinpath(OUT_DIR, "sheba_dct_diagnostics.csv"), diag_df)

default(size=(1100, 700), dpi=140)

p_curve = scatter(
	recon_df.zeta_mid,
	recon_df.phi_med;
	markersize=3,
	alpha=0.75,
	label="Binned median phi_m",
	xlabel="zeta",
	ylabel="phi_m",
	title="SHEBA Two-Layer Stable Profile: Binned Curve and DCT Reconstruction",
)
plot!(p_curve, recon_df.zeta_mid, recon_df.phi_recon; linewidth=2.2, label="DCT reconstruction (first $(N_KEEP) modes)")
savefig(p_curve, joinpath(OUT_DIR, "plot_sheba_dct_curve.png"))

p_coeff = bar(
	coeff_df.mode[1:min(20, nrow(coeff_df))],
	coeff_df.abs_coeff[1:min(20, nrow(coeff_df))];
	xlabel="DCT mode",
	ylabel="|coefficient|",
	legend=false,
	title="SHEBA DCT Coefficient Magnitudes (first 20 modes)",
)
savefig(p_coeff, joinpath(OUT_DIR, "plot_sheba_dct_coeffs.png"))

report_path = joinpath(OUT_DIR, "report.md")
open(report_path, "w") do io
	write(io, "# SHEBA DCT Two-Layer Analysis\n\n")
	write(io, "- Input: $(IN_CSV)\n")
	write(io, "- Rows used: $(nrow(df))\n")
	write(io, "- Quantile bins: $(nrow(profile))\n")
	write(io, "- DCT modes kept: $(N_KEEP)\n")
	write(io, @sprintf("- Binned reconstruction RMSE: %.5f\n", rmse))
	write(io, @sprintf("- Binned reconstruction MAE: %.5f\n", mae))
	write(io, @sprintf("- Spectral variance kept: %.2f%%\n\n", 100 * var_keep))

	write(io, "## Regime Summary\n\n")
	for row in eachrow(reg_df)
		write(io, "- $(row.regime): n=$(row.n), median(zeta)=$(row.zeta_median), median(phi_m)=$(row.phi_median), mean(phi_m)=$(row.phi_mean)\n")
	end

	write(io, "\n## Artifacts\n\n")
	write(io, "- sheba_binned_profile.csv\n")
	write(io, "- sheba_dct_coeffs.csv\n")
	write(io, "- sheba_dct_reconstruction.csv\n")
	write(io, "- sheba_regime_stats.csv\n")
	write(io, "- sheba_dct_diagnostics.csv\n")
	write(io, "- plot_sheba_dct_curve.png\n")
	write(io, "- plot_sheba_dct_coeffs.png\n")
end

println("SHEBA DCT analysis written to: $(OUT_DIR)")
println("Report: $(report_path)")
