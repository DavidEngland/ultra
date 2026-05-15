#!/usr/bin/env julia

include(joinpath(@__DIR__, "SmearPipeline.jl"))
using .SmearPipeline
using CSV
using DataFrames
using Dates

const DEFAULT_AGGREGATION = "NONE"
const DEFAULT_QUALITY = "ANY"

function usage()
    println("Usage:")
    println("  julia --project=. src/julia/hyy_station2_to_dct_input.jl --from=YYYY-MM-DDTHH:MM:SS --to=YYYY-MM-DDTHH:MM:SS --out=path.csv [--aggregation=NONE|ARITHMETIC] [--quality=ANY|GOOD]")
end

function parse_args(args::Vector{String})
    isempty(args) && throw(ArgumentError("No arguments provided"))

    from_iso = ""
    to_iso = ""
    out_csv = ""
    aggregation = DEFAULT_AGGREGATION
    quality = DEFAULT_QUALITY

    for a in args
        if startswith(a, "--from=")
            from_iso = String(split(a, "=", limit=2)[2])
        elseif startswith(a, "--to=")
            to_iso = String(split(a, "=", limit=2)[2])
        elseif startswith(a, "--out=")
            out_csv = String(split(a, "=", limit=2)[2])
        elseif startswith(a, "--aggregation=")
            aggregation = String(split(a, "=", limit=2)[2])
        elseif startswith(a, "--quality=")
            quality = String(split(a, "=", limit=2)[2])
        elseif a in ("-h", "--help")
            usage()
            exit(0)
        end
    end

    isempty(from_iso) && error("Missing required flag: --from")
    isempty(to_iso) && error("Missing required flag: --to")
    isempty(out_csv) && error("Missing required flag: --out")

    from_dt = DateTime(from_iso)
    to_dt = DateTime(to_iso)
    from_dt < to_dt || error("--from must be earlier than --to")

    return from_dt, to_dt, out_csv, aggregation, quality
end

function maybe_rename!(df::DataFrame, src::String, dst::String)
    if src in names(df) && !(dst in names(df))
        rename!(df, src => dst)
    end
end

function maybe_copy_alias!(df::DataFrame, src::String, dst::String)
    if src in names(df) && !(dst in names(df))
        df[!, dst] = df[!, src]
    end
end

function _as_float_or_missing(x)
    if x isa Missing
        return missing
    elseif x isa Number
        return Float64(x)
    elseif x isa AbstractString
        y = tryparse(Float64, strip(x))
        return isnothing(y) ? missing : y
    end
    return missing
end

function coalesce_alias!(df::DataFrame, dst::String, srcs::Vector{String})
    n = nrow(df)
    out = Vector{Union{Missing, Float64}}(missing, n)
    for src in srcs
        src in names(df) || continue
        vals = df[!, src]
        for i in 1:n
            ismissing(out[i]) || continue
            v = _as_float_or_missing(vals[i])
            ismissing(v) || (out[i] = v)
        end
    end

    if any(v -> !ismissing(v), out)
        df[!, dst] = out
    end
end

function main(args::Vector{String})
    from_dt, to_dt, out_csv, aggregation, quality = parse_args(args)

    requested_vars = [
           # Hyytiala temperature profile
        "HYY_META.T42",
        "HYY_META.T84",
        "HYY_META.T168",
        "HYY_META.T336",
        "HYY_META.T504",
        "HYY_META.T672",

        # Flux / interaction variables needed by DCT diagnostics
        "HYY_EDDY233.H",
        "HYY_EDDY233.LE",
        "HYY_EDDY233.E",
        "HYY_EDDY233.F_c",
        "HYY_EDDY233.tau",
        "HYY_EDDY233.u_star",
        "HYY_EDDY233.MO_length",
        "HYY_EDDY233.u_star_460",
        "HYY_EDDY233.MO_length_460",
        "HYY_EDDYTOW.u_star_radtow",
        "HYY_EDDYTOW.MO_length_radtow",
        "HYY_EDDYSUB.u_star_subm",
        "HYY_EDDYSUB.MO_length_subm",
        "HYY_EDDYMAST.u_star_270",
        "HYY_EDDYMAST.MO_length_270",
        "HYY_EDDY233.U",
        "HYY_EDDY233.wind_dir",
        "HYY_EDDY233.Qc_H",
        "HYY_EDDY233.Qc_LE",
        "HYY_EDDY233.Qc_F_c",
        "HYY_EDDY233.Qc_tau",
        "HYY_EDDY233.CO2_storage_flux",
        "HYY_EDDY233.H_storage_flux",
        "HYY_EDDY233.LE_storage_flux",
    ]

    df = fetch_smear_tiled(
        requested_vars,
        from_dt,
        to_dt;
        aggregation=aggregation,
        quality=quality,
    )

    # Provide Varrio-style aliases expected by DCT_SMEAR diagnostics.
    # This keeps existing analysis code reusable while preserving original HYY columns.
    maybe_copy_alias!(df, "HYY_EDDY233.H", "VAR_EDDY.H")
    maybe_copy_alias!(df, "HYY_EDDY233.LE", "VAR_EDDY.LE")
    maybe_copy_alias!(df, "HYY_EDDY233.E", "VAR_EDDY.E")
    maybe_copy_alias!(df, "HYY_EDDY233.F_c", "VAR_EDDY.F_c")
    maybe_copy_alias!(df, "HYY_EDDY233.tau", "VAR_EDDY.tau")
    # Use coalesced fallbacks so zeta/ustar diagnostics still work when primary channels are sparse.
    coalesce_alias!(df, "VAR_EDDY.u_star", [
        "HYY_EDDY233.u_star",
        "HYY_EDDY233.u_star_460",
        "HYY_EDDYTOW.u_star_radtow",
        "HYY_EDDYSUB.u_star_subm",
        "HYY_EDDYMAST.u_star_270",
    ])
    coalesce_alias!(df, "VAR_EDDY.MO_length", [
        "HYY_EDDY233.MO_length",
        "HYY_EDDY233.MO_length_460",
        "HYY_EDDYTOW.MO_length_radtow",
        "HYY_EDDYSUB.MO_length_subm",
        "HYY_EDDYMAST.MO_length_270",
    ])
    maybe_copy_alias!(df, "HYY_EDDY233.U", "VAR_EDDY.U")
    maybe_copy_alias!(df, "HYY_EDDY233.wind_dir", "VAR_EDDY.wind_dir")
    maybe_copy_alias!(df, "HYY_EDDY233.Qc_H", "VAR_EDDY.Qc_H")
    maybe_copy_alias!(df, "HYY_EDDY233.Qc_LE", "VAR_EDDY.Qc_LE")
    maybe_copy_alias!(df, "HYY_EDDY233.Qc_F_c", "VAR_EDDY.Qc_F_c")
    maybe_copy_alias!(df, "HYY_EDDY233.Qc_tau", "VAR_EDDY.Qc_tau")
    maybe_copy_alias!(df, "HYY_EDDY233.CO2_storage_flux", "VAR_EDDY.CO2_storage_flux")
    maybe_copy_alias!(df, "HYY_EDDY233.H_storage_flux", "VAR_EDDY.H_storage_flux")
    maybe_copy_alias!(df, "HYY_EDDY233.LE_storage_flux", "VAR_EDDY.LE_storage_flux")

    # Add compatibility aliases for temperature columns so current DCT_SMEAR input loader can parse.
    # HYY has six levels; TDRY aliases use fallback coalescing to avoid all-NaN profile levels.
    coalesce_alias!(df, "VAR_META.TDRY4", ["HYY_META.T42"])
    coalesce_alias!(df, "VAR_META.TDRY3", ["HYY_META.T84", "HYY_META.T168"])
    coalesce_alias!(df, "VAR_META.TDRY2", ["HYY_META.T168", "HYY_META.T336"])
    coalesce_alias!(df, "VAR_META.TDRY1", ["HYY_META.T336", "HYY_META.T504", "HYY_META.T672"])
    coalesce_alias!(df, "VAR_META.TDRY0", ["HYY_META.T504", "HYY_META.T672", "HYY_META.T336"])

    sort!(df, :datetime)
    unique!(df)

    mkpath(dirname(out_csv))
    CSV.write(out_csv, df)

    status_csv = replace(out_csv, r"\.csv$" => "_fetch_status.csv")
    stats = DataFrame(
        metric=["rows", "from", "to", "aggregation", "quality"],
        value=[string(nrow(df)), string(from_dt), string(to_dt), aggregation, quality],
    )
    CSV.write(status_csv, stats)

    println("HYY station-2 adapter complete")
    println("- output: " * out_csv)
    println("- rows: " * string(nrow(df)))
    println("- status: " * status_csv)
end

if abspath(PROGRAM_FILE) == @__FILE__
    try
        main(ARGS)
    catch err
        println(stderr, "Error: " * sprint(showerror, err))
        println(stderr)
        usage()
        exit(2)
    end
end
