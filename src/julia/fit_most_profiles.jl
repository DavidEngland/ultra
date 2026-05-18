#!/usr/bin/env julia

using CSV
using DataFrames
using LsqFit
using Printf
using Statistics

include(joinpath(@__DIR__, "tracer_registry.jl"))
include(joinpath(@__DIR__, "MOSTProfiles.jl"))
using .MOSTProfiles

function parse_flag(args::Vector{String}, key::String, default::String)
    prefix = key * "="
    for arg in args
        startswith(arg, prefix) || continue
        parts = split(arg, "=", limit=2)
        length(parts) == 2 || return default
        return parts[2]
    end
    return default
end

function parse_float_flag(args::Vector{String}, key::String, default::Float64)
    value = parse_flag(args, key, string(default))
    parsed = tryparse(Float64, value)
    parsed === nothing && error("Could not parse $(key) as Float64: $(value)")
    return parsed
end

function output_base(path::AbstractString)
    return endswith(lowercase(path), ".csv") ? path[1:end-4] : path
end

_safe_float(x) = x isa Missing ? NaN : (x isa Number ? Float64(x) : something(tryparse(Float64, strip(String(x))), NaN))

function finite_mean(v)
    vals = filter(isfinite, v)
    return isempty(vals) ? NaN : mean(vals)
end

function finite_std(v)
    vals = filter(isfinite, v)
    return length(vals) < 2 ? NaN : std(vals)
end

rmse(obs, pred) = sqrt(mean((obs .- pred) .^ 2))
mae(obs, pred) = mean(abs.(obs .- pred))

unstable_model(z, b, lambda_u) = (1 .- b .* z) .^ (-1.0 / lambda_u)
weakly_stable_model(x, slope0, c2) = 1 .+ slope0 .* x .+ c2 .* x .^ 2

function detect_ri_driver(df::DataFrame)
    candidates = [:Ri_g, :rig, :Ri, :ri, :Ri_b, :ri_b, :rib, :Rib, :Ri_bulk]
    for candidate in candidates
        candidate in propertynames(df) && return candidate
    end
    return nothing
end

function tracer_from_name(name::AbstractString, df::DataFrame)
    key = lowercase(strip(name))
    if key in ("momentum", "phi_m")
        if :phi_m in propertynames(df)
            return get_tracer(:momentum)
        elseif :phi_obs in propertynames(df)
            return generic_tracer(:momentum;
                display="Momentum  phi_m",
                phi_col=:phi_obs,
                lambda_unstable=4.0,
                b_unstable_default=16.0,
                a_stable_default=5.0,
                b_stable_default=5.0)
        end
    elseif key in ("heat", "phi_h")
        (:phi_h in propertynames(df)) && return get_tracer(:heat)
    elseif key in ("humidity", "q", "phi_q")
        (:phi_q in propertynames(df)) && return generic_tracer(:q;
            display="Humidity  phi_q",
            phi_col=:phi_q,
            scale_var="q_*",
            sign_note="Check latent-heat and humidity-gradient sign conventions before interpreting phi_q.",
            lambda_unstable=2.0,
            b_unstable_default=16.0,
            a_stable_default=5.0,
            b_stable_default=5.0)
    elseif startswith(key, "phi_")
        phi_col = Symbol(key)
        phi_col in propertynames(df) || return nothing
        tracer_id = Symbol(replace(key, "phi_" => ""))
        return generic_tracer(tracer_id;
            display="Tracer $(key)",
            phi_col=phi_col,
            lambda_unstable=2.0,
            b_unstable_default=16.0,
            a_stable_default=5.0,
            b_stable_default=5.0)
    end
    return nothing
end

function infer_tracers(df::DataFrame, tracer_arg::AbstractString)
    defs = TracerDef[]
    if !isempty(strip(tracer_arg))
        for item in split(tracer_arg, ",")
            tracer = tracer_from_name(item, df)
            isnothing(tracer) && error("Requested tracer not found in input: $(item)")
            push!(defs, tracer)
        end
        return defs
    end

    if :phi_m in propertynames(df)
        push!(defs, get_tracer(:momentum))
    elseif :phi_obs in propertynames(df)
        push!(defs, generic_tracer(:momentum;
            display="Momentum  phi_m",
            phi_col=:phi_obs,
            lambda_unstable=4.0,
            b_unstable_default=16.0,
            a_stable_default=5.0,
            b_stable_default=5.0))
    end
    :phi_h in propertynames(df) && push!(defs, get_tracer(:heat))
    :phi_q in propertynames(df) && push!(defs, generic_tracer(:q;
        display="Humidity  phi_q",
        phi_col=:phi_q,
        scale_var="q_*",
        sign_note="Check latent-heat and humidity-gradient sign conventions before interpreting phi_q.",
        lambda_unstable=2.0,
        b_unstable_default=16.0,
        a_stable_default=5.0,
        b_stable_default=5.0))

    isempty(defs) && error("No phi_m, phi_h, phi_q, or phi_obs columns found in input CSV.")
    return defs
end

function fit_unstable_family(z_u::Vector{Float64}, y_u::Vector{Float64}, tracer::TracerDef, family::String)
    n_u = length(z_u)
    if n_u < 5
        return (family=family,
            fit_status="default_no_unstable_data",
            b=tracer.b_unstable_default,
            lambda_u=tracer.lambda_unstable,
            rmse=NaN,
            mae=NaN,
            n_unstable=n_u)
    end

    if family == "BD_CLASSIC"
        fit = curve_fit((z, p) -> unstable_model(z, p[1], tracer.lambda_unstable),
            z_u, y_u, [tracer.b_unstable_default]; lower=[0.1], upper=[500.0])
        b = fit.param[1]
        lambda_u = tracer.lambda_unstable
    elseif family == "BD_PL"
        fit = curve_fit((z, p) -> unstable_model(z, p[1], p[2]),
            z_u, y_u, [tracer.b_unstable_default, tracer.lambda_unstable];
            lower=[0.1, 0.5], upper=[500.0, 20.0])
        b = fit.param[1]
        lambda_u = fit.param[2]
    else
        error("Unsupported family: $(family)")
    end

    pred_u = unstable_model(z_u, b, lambda_u)
    return (family=family,
        fit_status="fit_ok",
        b=b,
        lambda_u=lambda_u,
        rmse=rmse(y_u, pred_u),
        mae=mae(y_u, pred_u),
        n_unstable=n_u)
end

function fit_weakly_stable_branch(x_s::Vector{Float64}, y_s::Vector{Float64}, slope0::Float64)
    n_s = length(x_s)
    if n_s < 3
        pred = weakly_stable_model(x_s, slope0, 0.0)
        return (fit_status="linear_default",
            c2=0.0,
            rmse=n_s == 0 ? NaN : rmse(y_s, pred),
            mae=n_s == 0 ? NaN : mae(y_s, pred),
            n_weakly_stable=n_s)
    end

    fit = curve_fit((x, p) -> weakly_stable_model(x, slope0, p[1]),
        x_s, y_s, [0.0]; lower=[-500.0], upper=[500.0])
    c2 = fit.param[1]
    pred = weakly_stable_model(x_s, slope0, c2)
    return (fit_status="fit_ok",
        c2=c2,
        rmse=rmse(y_s, pred),
        mae=mae(y_s, pred),
        n_weakly_stable=n_s)
end

function driver_value(zeta::Float64, rig::Float64)
    if isfinite(rig)
        return max(rig, 0.0)
    end
    return max(zeta, 0.0)
end

function piecewise_prediction(zeta::Float64, rig::Float64, regime::Symbol, b::Float64, lambda_u::Float64, c2::Float64)
    if regime == :unstable || (regime == :near_neutral && zeta < 0.0)
        return unstable_model([zeta], b, lambda_u)[1]
    elseif regime == :near_neutral || regime == :weakly_stable
        x = driver_value(zeta, rig)
        return weakly_stable_model([x], b / lambda_u, c2)[1]
    end
    return NaN
end

function fit_one_tracer(df::DataFrame, tracer::TracerDef; ri_col=nothing, ric::Float64=DEFAULT_RIC, zeta_neutral::Float64=DEFAULT_ZETA_NEUTRAL, families::Vector{String}=["BD_CLASSIC", "BD_PL"])
    zeta = _safe_float.(df.zeta)
    phi = _safe_float.(df[!, tracer.phi_col])
    rig = isnothing(ri_col) ? fill(NaN, nrow(df)) : _safe_float.(df[!, ri_col])
    valid = isfinite.(zeta) .& isfinite.(phi)
    regimes = fill(:invalid, nrow(df))
    regimes[valid] = assign_regimes(zeta[valid], rig[valid]; ric=ric, zeta_neutral=zeta_neutral)

    unstable_mask = valid .& (regimes .== :unstable)
    weak_mask = valid .& (regimes .== :weakly_stable)
    near_mask = valid .& (regimes .== :near_neutral)

    z_u = zeta[unstable_mask]
    y_u = phi[unstable_mask]
    x_s = [driver_value(zeta[i], rig[i]) for i in eachindex(zeta) if weak_mask[i]]
    y_s = phi[weak_mask]

    param_rows = NamedTuple[]
    pred_rows = NamedTuple[]
    regime_rows = NamedTuple[]
    curve_rows = NamedTuple[]

    for family in families
        unstable_fit = fit_unstable_family(z_u, y_u, tracer, family)
        slope0 = unstable_fit.b / unstable_fit.lambda_u
        weak_fit = fit_weakly_stable_branch(x_s, y_s, slope0)
        ri_thickness = unstable_fit.lambda_u / unstable_fit.b

        fitted = fill(NaN, nrow(df))
        for i in eachindex(fitted)
            valid[i] || continue
            fitted[i] = piecewise_prediction(zeta[i], rig[i], regimes[i], unstable_fit.b, unstable_fit.lambda_u, weak_fit.c2)
            push!(pred_rows, (
                tracer=String(tracer.id),
                family=family,
                row_index=i,
                datetime=:datetime in propertynames(df) ? string(df[i, :datetime]) : "",
                zeta=zeta[i],
                rig=rig[i],
                regime=String(regimes[i]),
                phi_obs=phi[i],
                phi_fit=fitted[i],
                residual=isfinite(fitted[i]) ? phi[i] - fitted[i] : NaN,
            ))
        end

        fitted_mask = valid .& isfinite.(fitted)
        push!(param_rows, (
            tracer=String(tracer.id),
            phi_column=String(tracer.phi_col),
            family=family,
            unstable_fit_status=unstable_fit.fit_status,
            weak_fit_status=weak_fit.fit_status,
            n_unstable=unstable_fit.n_unstable,
            n_near_neutral=sum(near_mask),
            n_weakly_stable=weak_fit.n_weakly_stable,
            n_strongly_stable=sum(valid .& (regimes .== :strongly_stable)),
            b_unstable=unstable_fit.b,
            lambda_unstable=unstable_fit.lambda_u,
            neutral_slope=unstable_fit.b / unstable_fit.lambda_u,
            ri_thickness=ri_thickness,
            ric_regime=ric,
            c2_weakly_stable=weak_fit.c2,
            rmse_unstable=unstable_fit.rmse,
            rmse_weakly_stable=weak_fit.rmse,
            mae_unstable=unstable_fit.mae,
            mae_weakly_stable=weak_fit.mae,
            rmse_piecewise=any(fitted_mask) ? rmse(phi[fitted_mask], fitted[fitted_mask]) : NaN,
            mae_piecewise=any(fitted_mask) ? mae(phi[fitted_mask], fitted[fitted_mask]) : NaN,
        ))

        for regime in (:unstable, :near_neutral, :weakly_stable, :strongly_stable)
            mask = valid .& (regimes .== regime)
            pred_mask = mask .& isfinite.(fitted)
            push!(regime_rows, (
                tracer=String(tracer.id),
                family=family,
                regime=String(regime),
                n_obs=sum(mask),
                phi_mean=finite_mean(phi[mask]),
                phi_std=finite_std(phi[mask]),
                fit_mean=finite_mean(fitted[mask]),
                residual_rmse=any(pred_mask) ? rmse(phi[pred_mask], fitted[pred_mask]) : NaN,
                residual_mae=any(pred_mask) ? mae(phi[pred_mask], fitted[pred_mask]) : NaN,
            ))
        end

        if !isempty(z_u)
            zgrid_u = collect(range(minimum(z_u), 0.0; length=120))
            for z in zgrid_u
                push!(curve_rows, (
                    tracer=String(tracer.id),
                    family=family,
                    branch="unstable",
                    x_driver=z,
                    phi_fit=unstable_model([z], unstable_fit.b, unstable_fit.lambda_u)[1],
                ))
            end
        end
        x_hi = max(ric, isempty(x_s) ? ric : maximum(x_s))
        xgrid_s = collect(range(0.0, x_hi; length=120))
        for x in xgrid_s
            push!(curve_rows, (
                tracer=String(tracer.id),
                family=family,
                branch="weakly_stable",
                x_driver=x,
                phi_fit=weakly_stable_model([x], slope0, weak_fit.c2)[1],
            ))
        end
    end

    return DataFrame(param_rows), DataFrame(pred_rows), DataFrame(regime_rows), DataFrame(curve_rows)
end

function write_report(path::AbstractString, input_csv::AbstractString, dataset_label::AbstractString, ri_col, ric::Float64, zeta_neutral::Float64, params_df::DataFrame)
    driver_label = isnothing(ri_col) ? "zeta fallback" : string(ri_col)
    open(path, "w") do io
        write(io, "# MOST Branch Fits\n\n")
        write(io, "- Input: $(input_csv)\n")
        write(io, "- Dataset: $(dataset_label)\n")
        write(io, "- Ri driver: $(driver_label)\n")
        write(io, "- Ri_c: $(ric)\n")
        write(io, "- Near-neutral band: |zeta| <= $(zeta_neutral)\n\n")

        write(io, "## Model Form\n\n")
        write(io, "Unstable branch:\n\n")
        write(io, "\$\$\\phi_u(\\zeta) = (1 - b\\,\\zeta)^{-1/\\lambda}, \\qquad \\zeta < 0\$\$\n\n")
        write(io, "Weakly stable branch:\n\n")
        write(io, "\$\$\\phi_{ws}(R) = 1 + s_0 R + c_2 R^2, \\qquad s_0 = b/\\lambda\$\$\n\n")
        write(io, "with \$R\$ taken from the available Richardson-number driver and otherwise approximated by \$\\zeta\$ near neutral.\n\n")
        write(io, "The implied thickness scale is\n\n")
        write(io, "\$\$Ri_{thick} = 1/s_0 = \\lambda / b,\$\$\n\n")
        write(io, "so momentum with \$\\lambda = 4\$ reduces to \$Ri_{thick} = 4/b\$. This is reported for each fit alongside the regime threshold \$Ri_c\$.\n\n")

        write(io, "## Fit Summary\n\n")
        for tracer_df in groupby(params_df, :tracer)
            write(io, "### $(first(tracer_df.tracer))\n\n")
            for row in eachrow(tracer_df)
                write(io, @sprintf("- %s: unstable_status=%s, weak_status=%s, b=%.4f, lambda=%.4f, slope0=%.4f, Ri_thick=%.4f, c2=%.4f, RMSE_piecewise=%.4f\n",
                    row.family, row.unstable_fit_status, row.weak_fit_status, row.b_unstable, row.lambda_unstable, row.neutral_slope, row.ri_thickness, row.c2_weakly_stable, row.rmse_piecewise))
            end
            write(io, "\n")
        end

        write(io, "## Artifacts\n\n")
        write(io, "- fit_params.csv\n")
        write(io, "- fit_predictions.csv\n")
        write(io, "- fit_regime_stats.csv\n")
        write(io, "- fit_curves.csv\n")
    end
end

function main(args=ARGS)
    length(args) >= 2 || error("Usage: julia src/julia/fit_most_profiles.jl <input_csv> <output_prefix> [dataset_label] [--tracers=momentum,heat,q] [--families=BD_CLASSIC,BD_PL] [--ric=0.25] [--zeta-neutral=0.1]")

    input_csv = args[1]
    out_prefix = output_base(args[2])
    dataset_label = length(args) >= 3 && !startswith(args[3], "--") ? args[3] : basename(input_csv)
    flag_args = length(args) >= 3 && !startswith(args[3], "--") ? args[4:end] : args[3:end]

    ric = parse_float_flag(flag_args, "--ric", DEFAULT_RIC)
    zeta_neutral = parse_float_flag(flag_args, "--zeta-neutral", DEFAULT_ZETA_NEUTRAL)
    tracer_arg = parse_flag(flag_args, "--tracers", "")
    family_arg = uppercase.(strip.(split(parse_flag(flag_args, "--families", "BD_CLASSIC,BD_PL"), ",")))

    mkpath(dirname(out_prefix))
    df = CSV.read(input_csv, DataFrame; missingstring=["", "NaN", "NA", "999", "9999"], normalizenames=true)
    :zeta in propertynames(df) || error("Input CSV must contain a zeta column.")

    ri_col = detect_ri_driver(df)
    tracers = infer_tracers(df, tracer_arg)

    params_parts = DataFrame[]
    pred_parts = DataFrame[]
    regime_parts = DataFrame[]
    curve_parts = DataFrame[]
    for tracer in tracers
        param_df, pred_df, regime_df, curve_df = fit_one_tracer(df, tracer; ri_col=ri_col, ric=ric, zeta_neutral=zeta_neutral, families=family_arg)
        push!(params_parts, param_df)
        push!(pred_parts, pred_df)
        push!(regime_parts, regime_df)
        push!(curve_parts, curve_df)
    end

    params_df = isempty(params_parts) ? DataFrame() : vcat(params_parts...)
    pred_df = isempty(pred_parts) ? DataFrame() : vcat(pred_parts...)
    regime_df = isempty(regime_parts) ? DataFrame() : vcat(regime_parts...)
    curve_df = isempty(curve_parts) ? DataFrame() : vcat(curve_parts...)

    CSV.write("$(out_prefix)_fit_params.csv", params_df)
    CSV.write("$(out_prefix)_fit_predictions.csv", pred_df)
    CSV.write("$(out_prefix)_fit_regime_stats.csv", regime_df)
    CSV.write("$(out_prefix)_fit_curves.csv", curve_df)
    write_report("$(out_prefix)_report.md", input_csv, dataset_label, ri_col, ric, zeta_neutral, params_df)

    println("Wrote: $(out_prefix)_fit_params.csv")
    println("Wrote: $(out_prefix)_fit_predictions.csv")
    println("Wrote: $(out_prefix)_fit_regime_stats.csv")
    println("Wrote: $(out_prefix)_fit_curves.csv")
    println("Wrote: $(out_prefix)_report.md")
end

main()