using CSV
using DataFrames
using Printf
using Statistics
using FFTW
using Plots
using Dates

include(joinpath(@__DIR__, "SmearPipeline.jl"))
include(joinpath(@__DIR__, "compute_bulk_richardson.jl"))
include(joinpath(@__DIR__, "C1C3Diagnostics.jl"))
using .SmearPipeline
using .C1C3Diagnostics

const REPO_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const IN_CSV = get(ENV, "DCT_SHEBA_INPUT_CSV", joinpath(REPO_ROOT, "runs", "sheba", "input", "sheba_input.csv"))
const OUT_DIR = get(ENV, "DCT_SHEBA_OUT_DIR", joinpath(REPO_ROOT, "runs", "sheba", "dct_main_file6"))
const OBS_COL = Symbol(get(ENV, "DCT_SHEBA_OBS_COL", "phi_obs"))
mkpath(OUT_DIR)

const N_BINS = 48
const N_KEEP = 8
const ROLLING_WINDOW = parse(Int, get(ENV, "DCT_SHEBA_ROLLING_WINDOW", "12"))

function midpoints(edges::Vector{Float64})
	return 0.5 .* (edges[1:end-1] .+ edges[2:end])
end

function clean_input(df::DataFrame)
	req = [:zeta, OBS_COL]
	for c in req
		hasproperty(df, c) || error("Missing required column: $(c)")
	end

	out = dropmissing(select(df, [:zeta, OBS_COL]))
	rename!(out, OBS_COL => :phi_obs)
	filter!(r -> isfinite(r.zeta) && isfinite(r.phi_obs), out)
	filter!(r -> r.zeta > 0.0 && r.phi_obs > 0.0, out)
	return out
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

function ensure_datetime!(df::DataFrame)
	if :datetime in propertynames(df)
		if eltype(df.datetime) <: AbstractString
			df.datetime = DateTime.(df.datetime)
		elseif !(eltype(df.datetime) <: DateTime)
			df.datetime = DateTime.(string.(df.datetime))
		end
		return df
	end

	if :time in propertynames(df)
		time_vals = _safe_float.(df.time)
		finite_idx = findall(isfinite, time_vals)
		if !isempty(finite_idx)
			t0 = minimum(time_vals[finite_idx])
			minutes = round.(Int, (time_vals .- t0) .* 24 .* 60)
			df.datetime = DateTime(1998, 1, 1) .+ Minute.(minutes)
			return df
		end
	end

	df.datetime = DateTime(1998, 1, 1) .+ Minute.(30 .* (0:(nrow(df)-1)))
	return df
end

function local_fingerprint(z::Vector{Float64}, y::Vector{Float64}, i::Int; halfwin::Int=2)
	i_lo = max(1, i - halfwin)
	i_hi = min(length(z), i + halfwin)
	xw = z[i_lo:i_hi]
	yw = y[i_lo:i_hi]

	if length(xw) < 3
		return NaN, NaN, NaN
	end

	x0 = z[i]
	x = xw .- x0
	A = hcat(ones(length(x)), x, x .^ 2)
	coef = A \ yw
	# Polynomial around x0: a + b*x + c*x^2; local curvature proxy uses c.
	return coef[1], coef[2], coef[3]
end

function make_sheba_fingerprints(profile::DataFrame; tracer_name::String=String(OBS_COL))
	n = nrow(profile)
	dts = DateTime(1998, 1, 1) .+ Minute.(30 .* (0:(n-1)))
	c1 = Vector{Float64}(undef, n)
	c2 = Vector{Float64}(undef, n)
	c3 = Vector{Float64}(undef, n)

	z = collect(profile.zeta_mid)
	y = collect(profile.phi_med)

	for i in 1:n
		a, b, c = local_fingerprint(z, y, i)
		c1[i] = a
		c2[i] = b
		c3[i] = c
	end

	shape_ratio = [abs(c2[i]) > 1e-10 ? abs(c3[i]) / abs(c2[i]) : NaN for i in 1:n]

	return DataFrame(
		datetime=dts,
		tracer=fill(tracer_name, n),
		c1=c1,
		c2=c2,
		c3=c3,
		c4=fill(NaN, n),
		zeta=z,
		ustar=fill(NaN, n),
		n_obs=collect(Int, profile.n),
		shape_ratio=shape_ratio,
	)
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

function maybe_write_rib(df::DataFrame, fingerprints::DataFrame)
	t_low_candidates = [:T_lo, :T2_5, :T2_5_, :T2_5__1, :T2_5_1, :T1, :T2]
	t_high_candidates = [:T_hi, :T10, :T10_, :T5, :T4]
	ws_low_candidates = [:ws_lo, :ws2_5, :ws2_5_, :ws2_5__1, :ws2_5_1, :ws1, :ws2]
	ws_high_candidates = [:ws_hi, :ws10, :ws10_, :ws5, :ws4]
	z_low_candidates = [:z_lo, :z1, :z2]
	z_high_candidates = [:z_hi, :z5, :z4, :zoph]

	find_col(cands) = begin
		for c in cands
			if c in propertynames(df)
				return c
			end
		end
		return nothing
	end

	tl = find_col(t_low_candidates)
	th = find_col(t_high_candidates)
	wl = find_col(ws_low_candidates)
	wh = find_col(ws_high_candidates)
	zl = find_col(z_low_candidates)
	zh = find_col(z_high_candidates)

	if isnothing(tl) || isnothing(th) || isnothing(wh)
		summary = DataFrame(metric=["rib_available", "rib_window_count"], value=[0.0, 0.0])
		CSV.write(joinpath(OUT_DIR, "rib_diagnostics_summary.csv"), summary)
		CSV.write(joinpath(OUT_DIR, "rib_laminar_events.csv"), DataFrame())
		return DataFrame(), summary
	end

	raw = select(df, :datetime, tl, th, wh)
	if !isnothing(wl)
		raw[!, wl] = df[!, wl]
	end
	if !isnothing(zl)
		raw[!, zl] = df[!, zl]
	end
	if !isnothing(zh)
		raw[!, zh] = df[!, zh]
	end
	for c in names(raw, Not(:datetime))
		raw[!, c] = _safe_float.(raw[!, c])
	end
	raw = dropmissing(raw)

	if isempty(raw)
		summary = DataFrame(metric=["rib_available", "rib_window_count"], value=[1.0, 0.0])
		CSV.write(joinpath(OUT_DIR, "rib_diagnostics_summary.csv"), summary)
		CSV.write(joinpath(OUT_DIR, "rib_laminar_events.csv"), DataFrame())
		return DataFrame(), summary
	end

	raw.rib = fill(NaN, nrow(raw))
	for i in 1:nrow(raw)
		z_low = !isnothing(zl) ? _safe_float(raw[i, zl]) : 2.5
		z_high = !isnothing(zh) ? _safe_float(raw[i, zh]) : 10.0
		if !isfinite(z_low)
			z_low = 2.5
		end
		if !isfinite(z_high)
			z_high = 10.0
		end
		if z_high <= z_low
			continue
		end
		sub = raw[i:i, :]
		v = compute_bulk_richardson(sub, z_low, z_high, tl, th, wh; ws_low_col=wl)
		raw.rib[i] = _safe_float(first(v))
	end

	if !(:zeta in propertynames(raw)) && (:zeta in propertynames(df))
		raw.zeta = _safe_float.(df[1:nrow(raw), :zeta])
	end

	fp_zeta = _safe_float.(fingerprints.zeta)
	fp_c3 = _safe_float.(fingerprints.c3)

	mapped_c3 = fill(NaN, nrow(raw))
	if !isempty(fp_zeta)
		for i in 1:nrow(raw)
			z = (:zeta in propertynames(raw)) ? _safe_float(raw[i, :zeta]) : NaN
			if !isfinite(z)
				continue
			end
			j = argmin(abs.(fp_zeta .- z))
			mapped_c3[i] = fp_c3[j]
		end
	end
	raw.c3 = mapped_c3
	joined = filter(:rib => r -> isfinite(r), raw)
	if isempty(joined)
		summary = DataFrame(metric=["rib_available", "rib_window_count"], value=[1.0, 0.0])
		CSV.write(joinpath(OUT_DIR, "rib_diagnostics_summary.csv"), summary)
		CSV.write(joinpath(OUT_DIR, "rib_laminar_events.csv"), DataFrame())
		return DataFrame(), summary
	end

	lam = joined.rib .> 0.25
	valid_c3 = .!isnan.(joined.c3)
	c3_lam = joined.c3[lam .& valid_c3]
	c3_mix = joined.c3[.!lam .& valid_c3]

	summary = DataFrame(
		metric=["rib_available", "rib_window_count", "rib_laminar_count", "rib_laminar_fraction", "c3_median_laminar", "c3_median_non_laminar"],
		value=[1.0, nrow(joined), sum(lam), sum(lam) / max(nrow(joined), 1), isempty(c3_lam) ? NaN : median(c3_lam), isempty(c3_mix) ? NaN : median(c3_mix)],
	)

	CSV.write(joinpath(OUT_DIR, "rib_diagnostics_summary.csv"), summary)
	CSV.write(joinpath(OUT_DIR, "rib_laminar_events.csv"), filter(:rib => r -> isfinite(r) && r > 0.25, joined))
	CSV.write(joinpath(OUT_DIR, "interaction_joined.csv"), joined)

	return joined, summary
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

df0 = CSV.read(IN_CSV, DataFrame; missingstring=["", "NaN", "NA", "9999", "999"])
ensure_datetime!(df0)
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

fingerprints = make_sheba_fingerprints(profile; tracer_name=String(OBS_COL))
SmearPipeline.add_stability_class!(fingerprints)
stable_events = filter(r -> r.stability == :stable || r.stability == :strongly_stable, fingerprints)
counts = combine(groupby(fingerprints, :stability), nrow => :count)
sort!(counts, :count, rev=true)

diagnostics_summary = DataFrame(
	metric=["n_profiles", "n_stable", "stable_fraction", "mean_c2", "mean_c3", "mean_shape_ratio", "median_ustar"],
	value=[
		nrow(fingerprints),
		nrow(stable_events),
		nrow(stable_events) / max(nrow(fingerprints), 1),
		mean(skipmissing(fingerprints.c2)),
		mean(skipmissing(fingerprints.c3)),
		mean(skipmissing(fingerprints.shape_ratio)),
		median(skipmissing(fingerprints.ustar)),
	],
)

interaction_df, rib_summary = maybe_write_rib(df0, fingerprints)
c1_c3_summary = emit_c1_c3_diagnostics(OUT_DIR, fingerprints, "SHEBA $(OBS_COL)")

diag_df = DataFrame(
	metric=["n_rows", "n_bins", "n_modes_kept", "rmse_binned", "mae_binned", "variance_fraction_kept"],
	value=[nrow(df), nrow(profile), N_KEEP, rmse, mae, var_keep],
)

CSV.write(joinpath(OUT_DIR, "sheba_binned_profile.csv"), profile)
CSV.write(joinpath(OUT_DIR, "sheba_dct_coeffs.csv"), coeff_df)
CSV.write(joinpath(OUT_DIR, "sheba_dct_reconstruction.csv"), recon_df)
CSV.write(joinpath(OUT_DIR, "sheba_regime_stats.csv"), reg_df)
CSV.write(joinpath(OUT_DIR, "sheba_dct_diagnostics.csv"), diag_df)

# SMEAR-parity artifacts
CSV.write(joinpath(OUT_DIR, "fingerprints.csv"), fingerprints)
CSV.write(joinpath(OUT_DIR, "stable_events.csv"), stable_events)
CSV.write(joinpath(OUT_DIR, "stability_counts.csv"), counts)
CSV.write(joinpath(OUT_DIR, "diagnostics_summary.csv"), diagnostics_summary)

default(size=(1100, 700), dpi=140)

p_curve = scatter(
	recon_df.zeta_mid,
	recon_df.phi_med;
	markersize=3,
	alpha=0.75,
	label="Binned median $(OBS_COL)",
	xlabel="zeta",
	ylabel=String(OBS_COL),
	title="SHEBA Two-Layer Stable Profile: $(OBS_COL) Binned Curve and DCT Reconstruction",
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

if !isempty(interaction_df) && all(c -> c in names(interaction_df), [:rib, :c3])
	valid_rib = .!isnan.(_safe_float.(interaction_df.rib)) .& .!isnan.(_safe_float.(interaction_df.c3))
	if any(valid_rib)
		p_rib = scatter(
			interaction_df.rib[valid_rib],
			interaction_df.c3[valid_rib];
			alpha=0.45,
			markersize=2.8,
			xlabel="Ri_b",
			ylabel="c3",
			title="SHEBA Bulk Richardson vs Curvature c3",
			legend=false,
		)
		vline!(p_rib, [0.25]; color=:red, linestyle=:dash, label="")
		savefig(p_rib, joinpath(OUT_DIR, "plot_rib_vs_c3.png"))
	end
end

if all(c -> c in propertynames(df0), [:hs, :u_])
	x = _safe_float.(df0.hs)
	y = _safe_float.(df0.u_)
	rc = _rolling_corr(x, y, ROLLING_WINDOW)
	if !isempty(rc)
		rolling = DataFrame(datetime=df0.datetime[1:length(rc)], corr_H_tau=rc)
		CSV.write(joinpath(OUT_DIR, "interaction_rolling_corr.csv"), rolling)
		valid_rc = .!isnan.(_safe_float.(rolling.corr_H_tau))
		if any(valid_rc)
			p_roll = plot(
				rolling.datetime[valid_rc],
				rolling.corr_H_tau[valid_rc];
				lw=1.8,
				xlabel="datetime",
				ylabel="corr(H, tau)",
				title="SHEBA Rolling interaction: H vs u* (window=$(ROLLING_WINDOW + 1) samples)",
				legend=false,
			)
			hline!(p_roll, [0.0]; color=:black, linestyle=:dash, label="")
			savefig(p_roll, joinpath(OUT_DIR, "plot_rolling_corr_H_tau.png"))
		end
	end
end

report_path = joinpath(OUT_DIR, "report.md")
open(report_path, "w") do io
	write(io, "# SHEBA DCT Two-Layer Analysis\n\n")
	write(io, "- Input: $(IN_CSV)\n")
	write(io, "- Output dir: $(OUT_DIR)\n")
	write(io, "- Observable: $(OBS_COL)\n")
	write(io, "- Rows used: $(nrow(df))\n")
	write(io, "- Quantile bins: $(nrow(profile))\n")
	write(io, "- DCT modes kept: $(N_KEEP)\n")
	write(io, @sprintf("- Binned reconstruction RMSE: %.5f\n", rmse))
	write(io, @sprintf("- Binned reconstruction MAE: %.5f\n", mae))
	write(io, @sprintf("- Spectral variance kept: %.2f%%\n\n", 100 * var_keep))
	write(io, @sprintf("- Fingerprints: %d\n", nrow(fingerprints)))
	write(io, @sprintf("- Stable events: %d\n\n", nrow(stable_events)))

	write(io, "## Regime Summary\n\n")
	for row in eachrow(reg_df)
		write(io, "- $(row.regime): n=$(row.n), median(zeta)=$(row.zeta_median), median($(OBS_COL))=$(row.phi_median), mean($(OBS_COL))=$(row.phi_mean)\n")
	end

	if !isempty(c1_c3_summary)
		write(io, "\n## c1-c3 Relationship\n\n")
		for row in eachrow(c1_c3_summary)
			write(io, @sprintf("- %s: n=%d, corr=%.4f, slope=%.4f, intercept=%.4f, mean(c1)=%.4f, mean(c3)=%.4f, skew(c1)=%.4f, skew(c3)=%.4f\n",
				row.subset, row.n, row.corr_c1_c3, row.slope_c3_on_c1, row.intercept_c3_on_c1, row.mean_c1, row.mean_c3, row.skew_c1, row.skew_c3))
		end
	end

	write(io, "\n## Artifacts\n\n")
	write(io, "- fingerprints.csv\n")
	write(io, "- stable_events.csv\n")
	write(io, "- stability_counts.csv\n")
	write(io, "- diagnostics_summary.csv\n")
	write(io, "- c1_c3_relationship_summary.csv\n")
	write(io, "- sheba_binned_profile.csv\n")
	write(io, "- sheba_dct_coeffs.csv\n")
	write(io, "- sheba_dct_reconstruction.csv\n")
	write(io, "- sheba_regime_stats.csv\n")
	write(io, "- sheba_dct_diagnostics.csv\n")
	write(io, "- plot_c3_c1_hist.png\n")
	write(io, "- plot_phase_c1_c3.png\n")
	write(io, "- plot_c1_c3_trend.png\n")
	write(io, "- rib_diagnostics_summary.csv\n")
	write(io, "- rib_laminar_events.csv\n")
	write(io, "- plot_sheba_dct_curve.png\n")
	write(io, "- plot_sheba_dct_coeffs.png\n")
	if isfile(joinpath(OUT_DIR, "plot_rib_vs_c3.png"))
		write(io, "- plot_rib_vs_c3.png\n")
	end
	if isfile(joinpath(OUT_DIR, "interaction_rolling_corr.csv"))
		write(io, "- interaction_rolling_corr.csv\n")
	end
	if isfile(joinpath(OUT_DIR, "plot_rolling_corr_H_tau.png"))
		write(io, "- plot_rolling_corr_H_tau.png\n")
	end
end

println("SHEBA DCT analysis written to: $(OUT_DIR)")
println("Report: $(report_path)")
