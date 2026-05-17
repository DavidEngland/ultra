module C1C3Diagnostics

using CSV
using DataFrames
using Plots
using Statistics
using Printf

export emit_c1_c3_diagnostics

function _safe_float(x)
    if x isa Number
        return Float64(x)
    elseif x isa AbstractString
        y = tryparse(Float64, strip(x))
        return isnothing(y) ? NaN : y
    end
    return NaN
end

function _sample_skewness(v::Vector{Float64})
    n = length(v)
    n < 3 && return NaN
    mu = mean(v)
    centered = v .- mu
    s = std(v)
    (!isfinite(s) || s <= 0) && return 0.0
    return mean(centered .^ 3) / (s ^ 3)
end

function _linear_fit(x::Vector{Float64}, y::Vector{Float64})
    n = length(x)
    n < 2 && return NaN, NaN
    xbar = mean(x)
    ybar = mean(y)
    ssx = sum((x .- xbar) .^ 2)
    ssx <= 0 && return NaN, NaN
    slope = sum((x .- xbar) .* (y .- ybar)) / ssx
    intercept = ybar - slope * xbar
    return slope, intercept
end

function _subset_summary(name::String, c1::Vector{Float64}, c3::Vector{Float64})
    slope, intercept = _linear_fit(c1, c3)
    corr_val = length(c1) >= 2 ? cor(c1, c3) : NaN
    return (
        subset = name,
        n = length(c1),
        corr_c1_c3 = corr_val,
        slope_c3_on_c1 = slope,
        intercept_c3_on_c1 = intercept,
        mean_c1 = isempty(c1) ? NaN : mean(c1),
        mean_c3 = isempty(c3) ? NaN : mean(c3),
        skew_c1 = isempty(c1) ? NaN : _sample_skewness(c1),
        skew_c3 = isempty(c3) ? NaN : _sample_skewness(c3),
    )
end

function _empty_summary()
    return DataFrame(
        subset = String[],
        n = Int[],
        corr_c1_c3 = Float64[],
        slope_c3_on_c1 = Float64[],
        intercept_c3_on_c1 = Float64[],
        mean_c1 = Float64[],
        mean_c3 = Float64[],
        skew_c1 = Float64[],
        skew_c3 = Float64[],
    )
end

function emit_c1_c3_diagnostics(out_dir::AbstractString, fingerprints::DataFrame, dataset_label::AbstractString)
    summary_path = joinpath(out_dir, "c1_c3_relationship_summary.csv")

    if !all(c -> c in propertynames(fingerprints), [:c1, :c3])
        summary = _empty_summary()
        CSV.write(summary_path, summary)
        return summary
    end

    c1_all_raw = _safe_float.(fingerprints.c1)
    c3_all_raw = _safe_float.(fingerprints.c3)
    valid_all = .!isnan.(c1_all_raw) .& .!isnan.(c3_all_raw)
    c1_all = c1_all_raw[valid_all]
    c3_all = c3_all_raw[valid_all]

    if isempty(c1_all)
        summary = _empty_summary()
        CSV.write(summary_path, summary)
        return summary
    end

    summary_rows = NamedTuple[]
    push!(summary_rows, _subset_summary("all", c1_all, c3_all))

    if :stability in propertynames(fingerprints)
        near_mask_full = valid_all .& (fingerprints.stability .== :near_neutral)
        other_mask_full = valid_all .& (fingerprints.stability .!= :near_neutral)
        c1_near = c1_all_raw[near_mask_full]
        c3_near = c3_all_raw[near_mask_full]
        c1_other = c1_all_raw[other_mask_full]
        c3_other = c3_all_raw[other_mask_full]
        if !isempty(c1_near)
            push!(summary_rows, _subset_summary("near_neutral", c1_near, c3_near))
        end
        if !isempty(c1_other)
            push!(summary_rows, _subset_summary("non_neutral", c1_other, c3_other))
        end
    end

    summary = DataFrame(summary_rows)
    CSV.write(summary_path, summary)

    valid_c1 = .!isnan.(c1_all_raw) .& (abs.(c1_all_raw) .> 1e-8) .& .!isnan.(c3_all_raw)
    c3_c1 = _safe_float.(c3_all_raw[valid_c1] ./ c1_all_raw[valid_c1])
    c3_c1 = c3_c1[.!isnan.(c3_c1)]
    if !isempty(c3_c1)
        h_lo = quantile(c3_c1, 0.01)
        h_hi = quantile(c3_c1, 0.99)
        h_keep = (c3_c1 .>= h_lo) .& (c3_c1 .<= h_hi)
        if sum(h_keep) < 10
            h_keep .= true
            h_lo, h_hi = minimum(c3_c1), maximum(c3_c1)
        end
        c3_c1_plot = c3_c1[h_keep]
        p_c3c1 = histogram(
            c3_c1_plot;
            bins=50,
            alpha=0.7,
            xlabel="c3 / c1",
            ylabel="Density",
            title=@sprintf("Distribution of c3/c1 (%s, 1-99%% range)", dataset_label),
            legend=false,
        )
        xlims!(p_c3c1, h_lo, h_hi)
        savefig(p_c3c1, joinpath(out_dir, "plot_c3_c1_hist.png"))
    end

    p_phase = scatter(
        c1_all,
        c3_all;
        color=:gray45,
        alpha=0.5,
        markersize=2.0,
        xlabel="c1",
        ylabel="c3",
        title="Phase Portrait: c1 vs c3 ($(dataset_label), near-neutral highlighted)",
        legend=false,
    )
    if :stability in propertynames(fingerprints)
        near_mask = valid_all .& (fingerprints.stability .== :near_neutral)
        if any(near_mask)
            scatter!(
                p_phase,
                c1_all_raw[near_mask],
                c3_all_raw[near_mask];
                color=:dodgerblue,
                alpha=0.7,
                markersize=2.3,
                label="",
            )
        end
    end
    x_lo = quantile(c1_all, 0.01)
    x_hi = quantile(c1_all, 0.99)
    y_lo = quantile(c3_all, 0.01)
    y_hi = quantile(c3_all, 0.99)
    if x_lo < x_hi && y_lo < y_hi
        xlims!(p_phase, x_lo, x_hi)
        ylims!(p_phase, y_lo, y_hi)
    end
    hline!(p_phase, [0.0]; color=:black, linestyle=:dash, label="")
    vline!(p_phase, [0.0]; color=:black, linestyle=:dash, label="")
    savefig(p_phase, joinpath(out_dir, "plot_phase_c1_c3.png"))

    slope, intercept = _linear_fit(c1_all, c3_all)
    p_trend = scatter(
        c1_all,
        c3_all;
        color=:gray45,
        alpha=0.45,
        markersize=2.2,
        xlabel="c1",
        ylabel="c3",
        title="c1-c3 Relationship ($(dataset_label))",
        legend=false,
    )
    if isfinite(slope) && isfinite(intercept)
        xs = collect(range(minimum(c1_all), maximum(c1_all); length=100))
        ys = intercept .+ slope .* xs
        plot!(p_trend, xs, ys; color=:firebrick, linewidth=2.0, label="")
    end
    hline!(p_trend, [0.0]; color=:black, linestyle=:dash, label="")
    vline!(p_trend, [0.0]; color=:black, linestyle=:dash, label="")
    savefig(p_trend, joinpath(out_dir, "plot_c1_c3_trend.png"))

    return summary
end

end
