include(joinpath(@__DIR__, "SmearPipeline.jl"))
include(joinpath(@__DIR__, "SMEARVarLookup.jl"))

using .SmearPipeline
using .SMEARVarLookup
using CSV
using DataFrames
using Dates
using Printf

const REPO_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

const DEFAULT_START_YEAR = 2016
const DEFAULT_END_YEAR = 2025
const DEFAULT_DOY = 15
const DEFAULT_SEASON = "dead_of_winter"
const DEFAULT_FETCH_RETRIES = 3

Base.@kwdef struct SeasonalConfig
    start_year::Int = DEFAULT_START_YEAR
    end_year::Int = DEFAULT_END_YEAR
    doy::Int = DEFAULT_DOY
    season::String = DEFAULT_SEASON
    aggregation::String = "NONE"
    quality::String = "ANY"
    fetch_retries::Int = DEFAULT_FETCH_RETRIES
end

function parse_args(args::Vector{String})
    start_year = DEFAULT_START_YEAR
    end_year = DEFAULT_END_YEAR
    doy = DEFAULT_DOY
    season = DEFAULT_SEASON
    aggregation = "NONE"
    quality = "ANY"
    fetch_retries = DEFAULT_FETCH_RETRIES

    for a in args
        if startswith(a, "--start-year=")
            start_year = parse(Int, split(a, "=", limit=2)[2])
        elseif startswith(a, "--end-year=")
            end_year = parse(Int, split(a, "=", limit=2)[2])
        elseif startswith(a, "--doy=")
            doy = parse(Int, split(a, "=", limit=2)[2])
        elseif startswith(a, "--season=")
            season = split(a, "=", limit=2)[2]
        elseif startswith(a, "--aggregation=")
            aggregation = split(a, "=", limit=2)[2]
        elseif startswith(a, "--quality=")
            quality = split(a, "=", limit=2)[2]
        elseif startswith(a, "--fetch-retries=")
            fetch_retries = parse(Int, split(a, "=", limit=2)[2])
        end
    end

    start_year <= end_year || error("start-year must be <= end-year")
    1 <= doy <= 366 || error("doy must be in 1..366")
    fetch_retries >= 1 || error("fetch-retries must be >= 1")

    return SeasonalConfig(
        start_year=start_year,
        end_year=end_year,
        doy=doy,
        season=season,
        aggregation=aggregation,
        quality=quality,
        fetch_retries=fetch_retries,
    )
end

function doy_window(year::Int, doy::Int)
    max_doy = daysinyear(year)
    doy <= max_doy || error("DOY $(doy) is out of range for year $(year) (max $(max_doy))")
    date = Date(year, 1, 1) + Day(doy - 1)
    start_dt = DateTime(date)
    end_dt = start_dt + Day(1)
    return date, start_dt, end_dt
end

function fetch_smear_with_retry(
    tablevars::Vector{String},
    start_dt::DateTime,
    end_dt::DateTime;
    aggregation::String,
    quality::String,
    retries::Int,
)
    last_err = nothing
    for attempt in 1:retries
        try
            return fetch_smear_tiled(tablevars, start_dt, end_dt; aggregation=aggregation, quality=quality)
        catch err
            last_err = err
            if attempt < retries
                delay_s = 2.0^(attempt - 1)
                @warn "Fetch attempt failed, retrying" attempt=attempt retries=retries delay_s=delay_s exception=(err, catch_backtrace())
                sleep(delay_s)
            end
        end
    end
    error("Fetch failed after $(retries) attempts. Last error: $(last_err)")
end

function seasonal_groups()
    return Dict(
        "temperature_profile" => varrio_dct_vars(:temperature_profile),
        "wind_profile" => varrio_dct_vars(:wind_profile),
        "humidity_profile" => [
            "VAR_META.H2O_0",
            "VAR_META.H2O_1",
            "VAR_META.H2O_2",
            "VAR_META.H2O_3",
            "VAR_META.H2O_4",
            "VAR_META.RH0",
        ],
        "co2_tracers" => [
            "VAR_META.CO206",
            "VAR_EDDY.F_c",
            "VAR_EDDY.CO2_storage_flux",
            "VAR_EDDY.Qc_F_c",
        ],
        "heat_flux" => [
            "VAR_EDDY.H",
            "VAR_EDDY.LE",
            "VAR_EDDY.E",
            "VAR_EDDY.H_storage_flux",
            "VAR_EDDY.LE_storage_flux",
            "VAR_EDDY.Qc_H",
            "VAR_EDDY.Qc_LE",
        ],
        "momentum_flux" => [
            "VAR_EDDY.tau",
            "VAR_EDDY.u_star",
            "VAR_EDDY.U",
            "VAR_EDDY.wind_dir",
            "VAR_EDDY.MO_length",
            "VAR_EDDY.Qc_tau",
        ],
        "other_tracers" => [
            "VAR_EDDY.H_sub",
            "VAR_EDDY.LE_sub",
            "VAR_EDDY.E_sub",
            "VAR_EDDY.F_c_sub",
            "VAR_EDDY.tau_sub",
            "VAR_EDDY.u_star_sub",
            "VAR_EDDY.MO_length_sub",
            "VAR_EDDY.U_sub",
            "VAR_EDDY.wind_dir_sub",
        ],
    )
end

function fetch_group_for_year(
    group_name::String,
    tablevars::Vector{String},
    year::Int,
    doy::Int;
    aggregation::String,
    quality::String,
    fetch_retries::Int,
)
    date_str = ""
    start_str = ""
    end_str = ""

    try
        date, start_dt, end_dt = doy_window(year, doy)
        date_str = string(date)
        start_str = string(start_dt)
        end_str = string(end_dt)
        df = fetch_smear_with_retry(tablevars, start_dt, end_dt; aggregation=aggregation, quality=quality, retries=fetch_retries)
        if nrow(df) > 0
            df.season_year = fill(year, nrow(df))
            df.season_date = fill(date_str, nrow(df))
            df.target_doy = fill(doy, nrow(df))
            df.group_name = fill(group_name, nrow(df))
        end
        status = DataFrame(
            group_name=[group_name],
            season_year=[year],
            season_date=[date_str],
            target_doy=[doy],
            start_dt=[start_str],
            end_dt=[end_str],
            status=[nrow(df) > 0 ? "ok" : "empty"],
            rows=[nrow(df)],
            message=[""],
        )
        return df, status
    catch err
        status = DataFrame(
            group_name=[group_name],
            season_year=[year],
            season_date=[date_str],
            target_doy=[doy],
            start_dt=[start_str],
            end_dt=[end_str],
            status=["error"],
            rows=[0],
            message=[sprint(showerror, err)],
        )
        return DataFrame(), status
    end
end

function fetch_group_all_years(
    group_name::String,
    tablevars::Vector{String},
    years::UnitRange{Int},
    doy::Int;
    aggregation::String,
    quality::String,
    fetch_retries::Int,
)
    dfs = DataFrame[]
    stats = DataFrame[]

    for year in years
        df_y, status_y = fetch_group_for_year(group_name, tablevars, year, doy; aggregation=aggregation, quality=quality, fetch_retries=fetch_retries)
        push!(stats, status_y)
        nrow(df_y) > 0 && push!(dfs, df_y)
    end

    df_out = isempty(dfs) ? DataFrame() : vcat(dfs...; cols=:union)
    status_out = vcat(stats...)
    return df_out, status_out
end

function build_combined(groups::Dict{String, DataFrame})
    nonempty = [k for (k, v) in groups if nrow(v) > 0]
    isempty(nonempty) && return DataFrame()

    keycols = [:datetime, :season_year, :season_date, :target_doy]
    frames = [select(groups[k], keycols..., Not([:group_name])) for k in nonempty]
    for f in frames
        sort!(f, keycols)
        unique!(f)
    end

    ref_keys = select(frames[1], keycols)
    aligned = all(f -> isequal(select(f, keycols), ref_keys), frames)

    if aligned
        nonkey_frames = [select(f, Not(keycols)) for f in frames[2:end]]
        base = isempty(nonkey_frames) ? frames[1] : hcat(frames[1], nonkey_frames...; makeunique=true)
    else
        base = reduce((a, b) -> outerjoin(a, b; on=keycols, makeunique=true), frames)
    end

    sort!(base, :datetime)
    unique!(base)
    return base
end

function fetch_dct_temperature_input(years::UnitRange{Int}, doy::Int; aggregation::String, quality::String, fetch_retries::Int)
    candidates = [
        (
            "metadata_tdry",
            ["VAR_META.TDRY0", "VAR_META.TDRY1", "VAR_META.TDRY2", "VAR_META.TDRY3", "VAR_META.TDRY4", "VAR_EDDY.MO_length", "VAR_EDDY.u_star"],
        ),
        (
            "legacy_t",
            ["VAR_META.T2", "VAR_META.T4", "VAR_META.T66", "VAR_META.T9", "VAR_META.T15", "VAR_EDDY.MO_length", "VAR_EDDY.u_star"],
        ),
    ]

    rows = DataFrame[]
    status_rows = DataFrame[]

    for year in years
        date_str = ""
        fetched = false

        for (source_name, cols) in candidates
            try
                date, start_dt, end_dt = doy_window(year, doy)
                date_str = string(date)
                df = fetch_smear_with_retry(cols, start_dt, end_dt; aggregation=aggregation, quality=quality, retries=fetch_retries)
                if nrow(df) > 0
                    df.season_year = fill(year, nrow(df))
                    df.season_date = fill(date_str, nrow(df))
                    df.target_doy = fill(doy, nrow(df))
                    df.temp_source = fill(source_name, nrow(df))
                    push!(rows, df)

                    push!(status_rows, DataFrame(
                        season_year=[year],
                        season_date=[date_str],
                        target_doy=[doy],
                        temp_source=[source_name],
                        status=["ok"],
                        rows=[nrow(df)],
                        message=[""],
                    ))
                    fetched = true
                    break
                end
            catch err
                push!(status_rows, DataFrame(
                    season_year=[year],
                    season_date=[date_str],
                    target_doy=[doy],
                    temp_source=[source_name],
                    status=["error"],
                    rows=[0],
                    message=[sprint(showerror, err)],
                ))
            end
        end

        if !fetched
            push!(status_rows, DataFrame(
                season_year=[year],
                season_date=[date_str],
                target_doy=[doy],
                temp_source=["none"],
                status=["empty"],
                rows=[0],
                message=["No candidate set returned rows"],
            ))
        end
    end

    dct_df = isempty(rows) ? DataFrame() : vcat(rows...; cols=:union)
    dct_status = vcat(status_rows...)
    return dct_df, dct_status
end

function main(args::Vector{String})
    cfg = parse_args(args)

    start_year = cfg.start_year
    end_year = cfg.end_year
    doy = cfg.doy
    season = cfg.season
    aggregation = cfg.aggregation
    quality = cfg.quality
    fetch_retries = cfg.fetch_retries

    years = start_year:end_year
    out_dir = joinpath(REPO_ROOT, "runs", "seasonal_varrio_station1", season)
    mkpath(out_dir)

    groups_cfg = seasonal_groups()
    group_data = Dict{String, DataFrame}()
    status_tables = DataFrame[]

    println("Preparing seasonal Varrio inputs")
    println("- station_id: 1")
    println("- season label: $(season)")
    println("- target day-of-year: $(doy)")
    println("- years: $(start_year):$(end_year)")
    println("- fetch retries: $(fetch_retries)")

    for (group_name, tablevars) in sort(collect(groups_cfg); by=x -> x[1])
        println("Fetching group $(group_name) with $(length(tablevars)) variables")
        gdf, gstatus = fetch_group_all_years(group_name, tablevars, years, doy; aggregation=aggregation, quality=quality, fetch_retries=fetch_retries)
        group_data[group_name] = gdf
        push!(status_tables, gstatus)

        csv_path = joinpath(out_dir, "varrio_$(season)_$(group_name).csv")
        CSV.write(csv_path, gdf)
        println("- wrote $(basename(csv_path)) rows=$(nrow(gdf))")
    end

    combined = build_combined(group_data)
    combined_path = joinpath(out_dir, "varrio_$(season)_all_groups.csv")
    CSV.write(combined_path, combined)

    status_df = vcat(status_tables...)
    status_path = joinpath(out_dir, "varrio_$(season)_fetch_status.csv")
    CSV.write(status_path, status_df)

    dct_temp_df, dct_temp_status = fetch_dct_temperature_input(years, doy; aggregation=aggregation, quality=quality, fetch_retries=fetch_retries)
    dct_temp_path = joinpath(out_dir, "varrio_$(season)_dct_temperature_input.csv")
    dct_temp_status_path = joinpath(out_dir, "varrio_$(season)_dct_temperature_status.csv")
    CSV.write(dct_temp_path, dct_temp_df)
    CSV.write(dct_temp_status_path, dct_temp_status)

    manifest = DataFrame(
        artifact=[
            basename(combined_path),
            basename(status_path),
            basename(dct_temp_path),
            basename(dct_temp_status_path),
        ],
        rows=[
            nrow(combined),
            nrow(status_df),
            nrow(dct_temp_df),
            nrow(dct_temp_status),
        ],
        note=[
            "Union of all seasonal groups on datetime + season keys",
            "Per-group and per-year fetch diagnostics",
            "DCT_SMEAR-ready temperature+stability input with source fallback",
            "Per-year candidate-source outcome for DCT input",
        ],
    )

    for (group_name, gdf) in sort(collect(group_data); by=x -> x[1])
        push!(manifest, (
            "varrio_$(season)_$(group_name).csv",
            nrow(gdf),
            "Seasonal group export",
        ))
    end

    manifest_path = joinpath(out_dir, "varrio_$(season)_manifest.csv")
    CSV.write(manifest_path, manifest)

    report_path = joinpath(out_dir, "report.md")
    open(report_path, "w") do io
        write(io, "# Varrio Seasonal Input Preparation\n\n")
        write(io, "- station_id: 1\n")
        write(io, "- season label: $(season)\n")
        write(io, "- target day-of-year: $(doy)\n")
        write(io, "- years: $(start_year):$(end_year)\n")
        write(io, "- aggregation: $(aggregation)\n")
        write(io, "- quality: $(quality)\n\n")

        write(io, "## Group row counts\n\n")
        for (group_name, gdf) in sort(collect(group_data); by=x -> x[1])
            write(io, @sprintf("- %s: %d rows\n", group_name, nrow(gdf)))
        end

        write(io, "\n## DCT input\n\n")
        write(io, @sprintf("- dct temperature input rows: %d\n", nrow(dct_temp_df)))
        write(io, "- dct status file: $(basename(dct_temp_status_path))\n")

        write(io, "\n## Artifacts\n\n")
        for row in eachrow(manifest)
            write(io, @sprintf("- %s (%d rows): %s\n", row.artifact, row.rows, row.note))
        end
    end

    println("Done. Wrote seasonal outputs to: $(out_dir)")
    println("Report: $(report_path)")
end

main(ARGS)
