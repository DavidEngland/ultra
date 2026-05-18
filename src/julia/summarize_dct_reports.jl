using CSV
using DataFrames
using Dates
using Printf
using Statistics

const REPO_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const DEFAULT_RUNS_ROOT = joinpath(REPO_ROOT, "runs")
const DEFAULT_OUT_PREFIX = joinpath(DEFAULT_RUNS_ROOT, "summary", "dct_run_summary")

function _safe_float(x)
    if x isa Number
        return Float64(x)
    elseif x isa Missing
        return NaN
    elseif x isa AbstractString
        y = tryparse(Float64, strip(x))
        return isnothing(y) ? NaN : y
    end
    return NaN
end

function _metric_lookup(path::AbstractString)
    if !isfile(path)
        return Dict{String, Float64}()
    end
    df = CSV.read(path, DataFrame; missingstring=["", "NaN", "NA"])
    if !all(c -> c in names(df), ["metric", "value"])
        return Dict{String, Float64}()
    end
    out = Dict{String, Float64}()
    for row in eachrow(df)
        out[String(row.metric)] = _safe_float(row.value)
    end
    return out
end

function _c1c3_lookup(path::AbstractString)
    if !isfile(path)
        return Dict{String, Float64}()
    end
    df = CSV.read(path, DataFrame; missingstring=["", "NaN", "NA"])
    if !("subset" in names(df))
        return Dict{String, Float64}()
    end
    sub = filter(:subset => ==("all"), df)
    isempty(sub) && return Dict{String, Float64}()
    row = sub[1, :]
    return Dict(
        "corr_c1_c3" => _safe_float(row.corr_c1_c3),
        "slope_c3_on_c1" => _safe_float(row.slope_c3_on_c1),
        "mean_c1" => _safe_float(row.mean_c1),
        "mean_c3" => _safe_float(row.mean_c3),
        "skew_c1" => _safe_float(row.skew_c1),
        "skew_c3" => _safe_float(row.skew_c3),
    )
end

function _parse_report_metadata(path::AbstractString)
    title = ""
    meta = Dict{String, String}()
    isfile(path) || return title, meta
    for line in eachline(path)
        if startswith(line, "# ") && isempty(title)
            title = strip(line[3:end])
            continue
        end
        if !startswith(line, "- ")
            continue
        end
        m = match(r"^- ([^:]+):\s*(.*)$", line)
        isnothing(m) && continue
        key = lowercase(strip(m.captures[1]))
        key = replace(key, r"[^a-z0-9]+" => "_")
        meta[key] = strip(m.captures[2])
    end
    return title, meta
end

function _year_month(run_name::AbstractString)
    m = match(r"^(\d{4})_(\d{2})$", run_name)
    isnothing(m) && return missing, missing
    return parse(Int, m.captures[1]), parse(Int, m.captures[2])
end

function _finite_sum(x)
    vals = filter(isfinite, x)
    return isempty(vals) ? NaN : sum(vals)
end

function _finite_mean(x)
    vals = filter(isfinite, x)
    return isempty(vals) ? NaN : mean(vals)
end

function collect_run_summary(runs_root::AbstractString=DEFAULT_RUNS_ROOT)
    rows = NamedTuple[]
    for (dir, _, files) in walkdir(runs_root)
        if !("report.md" in files) || !("diagnostics_summary.csv" in files)
            continue
        end

        rel_dir = relpath(dir, runs_root)
        run_name = basename(dir)
        parent_dir = dirname(rel_dir)
        collection = (parent_dir == "." || isempty(parent_dir)) ? "root" : parent_dir
        year, month = _year_month(run_name)

        diag = _metric_lookup(joinpath(dir, "diagnostics_summary.csv"))
        c1c3 = _c1c3_lookup(joinpath(dir, "c1_c3_relationship_summary.csv"))
        rib = _metric_lookup(joinpath(dir, "rib_diagnostics_summary.csv"))
        title, meta = _parse_report_metadata(joinpath(dir, "report.md"))

        push!(rows, (
            run_dir = rel_dir,
            collection = collection,
            run_name = run_name,
            year = year,
            month = month,
            title = title,
            observable = get(meta, "observable", ""),
            time_range = get(meta, "time_range", ""),
            input = get(meta, "input", ""),
            n_profiles = get(diag, "n_profiles", NaN),
            n_stable = get(diag, "n_stable", NaN),
            stable_fraction = get(diag, "stable_fraction", NaN),
            mean_c2 = get(diag, "mean_c2", NaN),
            mean_c3 = get(diag, "mean_c3", NaN),
            mean_shape_ratio = get(diag, "mean_shape_ratio", NaN),
            median_ustar = get(diag, "median_ustar", NaN),
            c1_c3_corr = get(c1c3, "corr_c1_c3", NaN),
            c1_c3_slope = get(c1c3, "slope_c3_on_c1", NaN),
            c1_mean = get(c1c3, "mean_c1", NaN),
            c3_mean = get(c1c3, "mean_c3", NaN),
            c1_skew = get(c1c3, "skew_c1", NaN),
            c3_skew = get(c1c3, "skew_c3", NaN),
            rib_available = get(rib, "rib_available", NaN),
            rib_window_count = get(rib, "rib_window_count", NaN),
            rib_laminar_fraction = get(rib, "rib_laminar_fraction", NaN),
        ))
    end

    if isempty(rows)
        return DataFrame(
            run_dir = String[],
            collection = String[],
            run_name = String[],
            year = Union{Missing, Int}[],
            month = Union{Missing, Int}[],
            title = String[],
            observable = String[],
            time_range = String[],
            input = String[],
            n_profiles = Float64[],
            n_stable = Float64[],
            stable_fraction = Float64[],
            mean_c2 = Float64[],
            mean_c3 = Float64[],
            mean_shape_ratio = Float64[],
            median_ustar = Float64[],
            c1_c3_corr = Float64[],
            c1_c3_slope = Float64[],
            c1_mean = Float64[],
            c3_mean = Float64[],
            c1_skew = Float64[],
            c3_skew = Float64[],
            rib_available = Float64[],
            rib_window_count = Float64[],
            rib_laminar_fraction = Float64[],
        )
    end

    df = DataFrame(rows)
    sort!(df, [:collection, :year, :month, :run_name])
    return df
end

function summarize_by_collection_year(run_df::DataFrame)
    if isempty(run_df)
        return DataFrame(
            collection = String[],
            year = Union{Missing, Int}[],
            n_runs = Int[],
            total_profiles = Float64[],
            total_stable = Float64[],
            mean_stable_fraction = Float64[],
            mean_c3 = Float64[],
            mean_shape_ratio = Float64[],
            mean_c1_c3_corr = Float64[],
            mean_rib_laminar_fraction = Float64[],
        )
    end

    grouped = groupby(run_df, [:collection, :year])
    return combine(
        grouped,
        nrow => :n_runs,
        :n_profiles => _finite_sum => :total_profiles,
        :n_stable => _finite_sum => :total_stable,
        :stable_fraction => _finite_mean => :mean_stable_fraction,
        :mean_c3 => _finite_mean => :mean_c3,
        :mean_shape_ratio => _finite_mean => :mean_shape_ratio,
        :c1_c3_corr => _finite_mean => :mean_c1_c3_corr,
        :rib_laminar_fraction => _finite_mean => :mean_rib_laminar_fraction,
    )
end

function _fmt_float(x)
    return isfinite(x) ? @sprintf("%.4f", x) : "NaN"
end

function write_markdown_summary(path::AbstractString, run_df::DataFrame, yearly_df::DataFrame, runs_root::AbstractString)
    mkpath(dirname(path))
    open(path, "w") do io
        write(io, "# DCT Run Summary\n\n")
        write(io, "- Runs root: $(runs_root)\n")
        write(io, "- Generated: $(now())\n")
        write(io, "- Runs summarized: $(nrow(run_df))\n\n")

        write(io, "## Collection-Year Summary\n\n")
        for row in eachrow(yearly_df)
            year_label = ismissing(row.year) ? "unparsed" : string(row.year)
            write(io, "- $(row.collection) / $(year_label): runs=$(row.n_runs), total_profiles=$(_fmt_float(row.total_profiles)), total_stable=$(_fmt_float(row.total_stable)), mean_stable_fraction=$(_fmt_float(row.mean_stable_fraction)), mean_c3=$(_fmt_float(row.mean_c3)), mean_shape_ratio=$(_fmt_float(row.mean_shape_ratio)), mean_corr(c1,c3)=$(_fmt_float(row.mean_c1_c3_corr)), mean_rib_laminar_fraction=$(_fmt_float(row.mean_rib_laminar_fraction))\n")
        end

        write(io, "\n## Per-Run Snapshot\n\n")
        for row in eachrow(run_df)
            yrmo = ismissing(row.year) ? row.run_name : @sprintf("%04d-%02d", row.year, row.month)
            obs = isempty(row.observable) ? "n/a" : row.observable
            tr = isempty(row.time_range) ? "n/a" : row.time_range
            write(io, "- $(row.run_dir): period=$(yrmo), observable=$(obs), profiles=$(_fmt_float(row.n_profiles)), stable_fraction=$(_fmt_float(row.stable_fraction)), mean_c3=$(_fmt_float(row.mean_c3)), corr(c1,c3)=$(_fmt_float(row.c1_c3_corr)), time_range=$(tr)\n")
        end
    end
end

function main(args=ARGS)
    runs_root = length(args) >= 1 ? normpath(args[1]) : DEFAULT_RUNS_ROOT
    out_prefix = length(args) >= 2 ? args[2] : DEFAULT_OUT_PREFIX

    run_df = collect_run_summary(runs_root)
    yearly_df = summarize_by_collection_year(run_df)

    csv_path = "$(out_prefix).csv"
    yearly_path = "$(out_prefix)_yearly.csv"
    md_path = "$(out_prefix).md"
    mkpath(dirname(csv_path))
    CSV.write(csv_path, run_df)
    CSV.write(yearly_path, yearly_df)
    write_markdown_summary(md_path, run_df, yearly_df, runs_root)

    println("Per-run summary: $(csv_path)")
    println("Yearly summary: $(yearly_path)")
    println("Markdown summary: $(md_path)")
end

main()