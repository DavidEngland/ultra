include(joinpath(@__DIR__, "SmearPipeline.jl"))
using .SmearPipeline
using CSV
using DataFrames
using Dates
using HTTP
using JSON3
using Plots
using Printf
using Statistics

const DEFAULT_IN_DIR = joinpath(@__DIR__, "..", "..", "runs", "seasonal_varrio_station1", "dead_of_winter")
const DEFAULT_OUT_DIR = joinpath(@__DIR__, "..", "..", "runs", "dct_smear_seasonal_dead_of_winter")
const VARIABLE_API = get(ENV, "SMEAR_VARIABLE_API", "https://smear-backend.rahtiapp.fi/search/variable")
const USE_METADATA_HEIGHTS = lowercase(get(ENV, "DCT_SMEAR_USE_METADATA_HEIGHTS", "true")) == "true"

const IN_DIR = get(ENV, "DCT_SMEAR_SEASONAL_INPUT_DIR", DEFAULT_IN_DIR)
const OUT_DIR = get(ENV, "DCT_SMEAR_SEASONAL_OUT_DIR", DEFAULT_OUT_DIR)
const STATUS_PATH = joinpath(OUT_DIR, "run_status.txt")

mkpath(OUT_DIR)

write_status(lines::Vector{String}) = open(STATUS_PATH, "w") do io
	for line in lines
		write(io, line * "\n")
	end
end

const _TABLE_META_CACHE = Dict{String, Any}()

function _table_from_col(col::AbstractString)
	m = match(r"^([^.]+)\..+$", col)
	return isnothing(m) ? "" : m.captures[1]
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

function _height_from_location(loc)
	if loc isa AbstractString
		m = match(r"([+-]?\d+(?:\.\d+)?)", loc)
		return isnothing(m) ? NaN : _safe_float(m.captures[1])
	end
	return NaN
end

function _extract_height(entry)
	for key in ("height", "Height", "z", "Z", "measurement_height", "sensor_height")
		if haskey(entry, key)
			h = _safe_float(entry[key])
			!isnan(h) && return h
		end
	end
	if haskey(entry, "location")
		h = _height_from_location(entry["location"])
		!isnan(h) && return h
	end
	return NaN
end

function _entry_varname(entry)
	for key in ("tablevariable", "tableVariable", "name", "variable", "fullname", "id")
		if haskey(entry, key)
			return String(entry[key])
		end
	end
	return ""
end

function _fetch_table_variable_metadata(table::String)
	isempty(table) && return Any[]
	if haskey(_TABLE_META_CACHE, table)
		return _TABLE_META_CACHE[table]
	end

	url = string(VARIABLE_API, "?table=", table)
	resp = HTTP.get(url; readtimeout=60)
	resp.status == 200 || error("Metadata API request failed: $(resp.status) for $(url)")
	payload = JSON3.read(String(resp.body))

	records = if payload isa AbstractVector
		payload
	elseif payload isa AbstractDict && haskey(payload, "data")
		payload["data"]
	elseif payload isa AbstractDict && haskey(payload, "results")
		payload["results"]
	else
		Any[]
	end

	_TABLE_META_CACHE[table] = records
	return records
end

function _resolve_heights_from_metadata(cols::Vector{String})
	heights = fill(NaN, length(cols))
	for (i, col) in pairs(cols)
		table = _table_from_col(col)
		isempty(table) && continue
		try
			records = _fetch_table_variable_metadata(table)
			for rec in records
				entry = rec isa AbstractDict ? rec : Dict{String, Any}(pairs(rec))
				varname = _entry_varname(entry)
				if varname == col
					h = _extract_height(entry)
					if !isnan(h)
						heights[i] = h
						break
					end
				end
			end
		catch
			# keep NaN and fallback later
		end
	end
	return heights
end

function resolve_profile_heights(cols::Vector{String}, fallback::Vector{Float64})
	if !USE_METADATA_HEIGHTS
		return fallback, "fallback:metadata_disabled"
	end

	meta_h = _resolve_heights_from_metadata(cols)
	if all(h -> !isnan(h), meta_h)
		return meta_h, "metadata_api"
	end

	merged = copy(fallback)
	for i in eachindex(merged)
		if i <= length(meta_h) && !isnan(meta_h[i])
			merged[i] = meta_h[i]
		end
	end
	return merged, "fallback:partial_metadata"
end

function normalize_datetime!(df::DataFrame)
	:datetime in propertynames(df) || error("Input CSV must contain a datetime column")
	if eltype(df.datetime) <: AbstractString
		df.datetime = DateTime.(df.datetime)
	elseif !(eltype(df.datetime) <: DateTime)
		df.datetime = DateTime.(string.(df.datetime))
	end
end

function add_stability_aliases!(df::DataFrame)
	if "VAR_EDDY.MO_length" in names(df) && !(:L_obukhov in propertynames(df))
		df.L_obukhov = df[!, "VAR_EDDY.MO_length"]
	end
	if "VAR_EDDY.u_star" in names(df) && !(:ustar in propertynames(df))
		df.ustar = df[!, "VAR_EDDY.u_star"]
	end
	return df
end

function _profile_candidates(df::DataFrame)
	ignored = Set(["datetime", "season_year", "season_date", "target_doy", "group_name", "temp_source"])
	groups = Dict{String, Vector{Tuple{Int, String}}}()

	for col in names(df)
		col in ignored && continue
		m = match(r"^(.*?)(\d+)$", col)
		isnothing(m) && continue
		prefix = m.captures[1]
		idx = parse(Int, m.captures[2])
		push!(get!(groups, prefix, Tuple{Int, String}[]), (idx, col))
	end

	out = Dict{String, Vector{Tuple{Int, String}}}()
	for (prefix, vals) in groups
		length(vals) >= 3 || continue
		sort!(vals, by=x -> x[1], rev=true)
		out[prefix] = vals
	end
	return out
end

function select_profile_columns(df::DataFrame)
	known = [
		("temperature_profile", ["VAR_META.TDRY4", "VAR_META.TDRY3", "VAR_META.TDRY2", "VAR_META.TDRY1", "VAR_META.TDRY0"], [2.2, 4.4, 6.6, 9.0, 15.0]),
		("wind_profile", ["VAR_META.WS4", "VAR_META.WS3", "VAR_META.WS2", "VAR_META.WS1", "VAR_META.WS0"], [2.2, 4.4, 6.6, 9.0, 15.0]),
		("humidity_profile", ["VAR_META.H2O_4", "VAR_META.H2O_3", "VAR_META.H2O_2", "VAR_META.H2O_1", "VAR_META.H2O_0"], [2.2, 4.4, 6.6, 9.0, 15.0]),
	]

	for (label, cols, heights) in known
		if all(c -> c in names(df), cols)
			return cols, heights, label
		end
	end

	candidates = _profile_candidates(df)
	isempty(candidates) && error("No vertical-profile columns found (need >=3 columns with numeric suffix)")

	best_prefix = ""
	best_vals = Tuple{Int, String}[]
	for (prefix, vals) in candidates
		if length(vals) > length(best_vals)
			best_prefix = prefix
			best_vals = vals
		end
	end

	cols = [x[2] for x in best_vals]
	heights = collect(1.0:length(cols))
	return cols, heights, "auto_prefix:" * best_prefix
end

function summarize_counts(fingerprints::DataFrame)
	counts = combine(groupby(fingerprints, :stability), nrow => :count)
	sort!(counts, :count, rev=true)
	return counts
end

function compute_summary_stats(fingerprints::DataFrame, stable_events::DataFrame)
	return DataFrame(
		metric = ["n_profiles", "n_stable", "stable_fraction", "mean_c2", "mean_c3", "mean_shape_ratio", "median_ustar"],
		value = [
			nrow(fingerprints),
			nrow(stable_events),
			nrow(stable_events) / max(nrow(fingerprints), 1),
			mean(skipmissing(fingerprints.c2)),
			mean(skipmissing(fingerprints.c3)),
			mean(skipmissing(fingerprints.shape_ratio)),
			median(skipmissing(fingerprints.ustar)),
		],
	)
end

function save_standard_plots(out_dir::String, fingerprints::DataFrame, counts::DataFrame, stem::String)
	default(size=(1100, 700), dpi=140)

	p_counts = bar(
		string.(counts.stability),
		counts.count;
		xlabel="Stability class",
		ylabel="Count",
		title="DCT-SMEAR Stability Counts: $(stem)",
		legend=false,
	)
	savefig(p_counts, joinpath(out_dir, "plot_stability_counts.png"))

	valid_shape = .!isnan.(fingerprints.zeta) .& .!isnan.(fingerprints.shape_ratio)
	p_shape = scatter(
		fingerprints.zeta[valid_shape],
		fingerprints.shape_ratio[valid_shape];
		markersize=2.0,
		alpha=0.35,
		xlabel="zeta",
		ylabel="shape_ratio = |c3| / |c2|",
		title="Curvature-to-Gradient Ratio vs Stability: $(stem)",
		legend=false,
	)
	savefig(p_shape, joinpath(out_dir, "plot_shape_ratio_vs_zeta.png"))

	p_coeff = histogram(
		[fingerprints.c2 fingerprints.c3];
		bins=50,
		alpha=0.6,
		normalize=:pdf,
		label=["c2" "c3"],
		xlabel="Coefficient value",
		ylabel="Density",
		title="Spectral Coefficient Distributions: $(stem)",
	)
	savefig(p_coeff, joinpath(out_dir, "plot_coeff_distributions.png"))
end

function write_file_report(out_dir::String, stem::String, in_file::String, profile_cols::Vector{String}, profile_heights::Vector{Float64}, profile_source::String, height_source::String, raw_df::DataFrame, fingerprints::DataFrame, stable_events::DataFrame, counts::DataFrame, coef_stats::DataFrame)
	report_path = joinpath(out_dir, "report.md")
	stable_frac_pct = 100 * nrow(stable_events) / max(nrow(fingerprints), 1)
	open(report_path, "w") do io
		write(io, "# DCT-SMEAR Seasonal Results\n\n")
		write(io, "- Input file: $(in_file)\n")
		write(io, "- Profile source: $(profile_source)\n")
		write(io, "- Height source: $(height_source)\n")
		write(io, "- Profile columns: $(join(profile_cols, ", "))\n")
		write(io, "- Profile heights (m): $(join(round.(profile_heights, digits=3), ", "))\n")
		write(io, "- Raw rows: $(nrow(raw_df))\n")
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
end

function process_file(csv_path::String)
	stem = replace(basename(csv_path), ".csv" => "")
	out_dir = joinpath(OUT_DIR, stem)
	mkpath(out_dir)

	raw_df = CSV.read(csv_path, DataFrame; missingstring=["", "NaN", "NA"])
	normalize_datetime!(raw_df)
	add_stability_aliases!(raw_df)

	profile_cols, fallback_heights, profile_source = select_profile_columns(raw_df)
	heights, height_source = resolve_profile_heights(profile_cols, fallback_heights)
	profiles = build_vertical_profiles(raw_df, :T; col_names=profile_cols, heights=heights)
	fingerprints = batch_fingerprint(profiles, :T)

	if isempty(fingerprints)
		CSV.write(joinpath(out_dir, "fingerprints.csv"), DataFrame())
		CSV.write(joinpath(out_dir, "stable_events.csv"), DataFrame())
		CSV.write(joinpath(out_dir, "stability_counts.csv"), DataFrame(stability=String[], count=Int[]))
		CSV.write(joinpath(out_dir, "diagnostics_summary.csv"), DataFrame(metric=["n_profiles"], value=[0.0]))

		open(joinpath(out_dir, "report.md"), "w") do io
			write(io, "# DCT-SMEAR Seasonal Results\n\n")
			write(io, "No fingerprints were generated for $(basename(csv_path)).\n")
		end

		return (
			file=basename(csv_path),
			status="no_fingerprints",
			profile_source=profile_source,
			height_source=height_source,
			profile_cols=join(profile_cols, ";"),
			profile_heights=join(round.(heights, digits=3), ";"),
			raw_rows=nrow(raw_df),
			profiles=0,
			fingerprints=0,
			stable_events=0,
			stable_fraction=0.0,
			out_dir=out_dir,
			report=joinpath(out_dir, "report.md"),
		)
	end

	SmearPipeline.add_stability_class!(fingerprints)
	stable_events = filter(r -> r.stability == :stable, fingerprints)
	counts = summarize_counts(fingerprints)
	coef_stats = compute_summary_stats(fingerprints, stable_events)

	CSV.write(joinpath(out_dir, "fingerprints.csv"), fingerprints)
	CSV.write(joinpath(out_dir, "stable_events.csv"), stable_events)
	CSV.write(joinpath(out_dir, "stability_counts.csv"), counts)
	CSV.write(joinpath(out_dir, "diagnostics_summary.csv"), coef_stats)
	save_standard_plots(out_dir, fingerprints, counts, stem)
	write_file_report(out_dir, stem, basename(csv_path), profile_cols, heights, profile_source, height_source, raw_df, fingerprints, stable_events, counts, coef_stats)

	stable_fraction = nrow(stable_events) / max(nrow(fingerprints), 1)
	return (
		file=basename(csv_path),
		status="ok",
		profile_source=profile_source,
		height_source=height_source,
		profile_cols=join(profile_cols, ";"),
		profile_heights=join(round.(heights, digits=3), ";"),
		raw_rows=nrow(raw_df),
		profiles=length(profiles),
		fingerprints=nrow(fingerprints),
		stable_events=nrow(stable_events),
		stable_fraction=stable_fraction,
		out_dir=out_dir,
		report=joinpath(out_dir, "report.md"),
	)
end

function seasonal_inputs(in_dir::String)
	isdir(in_dir) || error("Input directory not found: $(in_dir)")
	files = filter(readdir(in_dir; join=true)) do p
		endswith(lowercase(p), ".csv") || return false
		b = basename(p)
		!occursin("manifest", b) && !occursin("status", b) && !occursin("all_groups", b)
	end
	sort!(files)
	return files
end

function write_overall_outputs(results::DataFrame)
	CSV.write(joinpath(OUT_DIR, "seasonal_file_summary.csv"), results)

	ok = filter(:status => ==("ok"), results)
	if nrow(ok) > 0
		order = sortperm(ok.stable_fraction; rev=true)
		ok_sorted = ok[order, :]
		p = bar(
			ok_sorted.file,
			100 .* ok_sorted.stable_fraction;
			xlabel="Input CSV",
			ylabel="Stable fraction (%)",
			title="Stable Fraction by Seasonal Input",
			legend=false,
			xrotation=30,
		)
		savefig(p, joinpath(OUT_DIR, "plot_stable_fraction_by_file.png"))
	end

	open(joinpath(OUT_DIR, "report.md"), "w") do io
		write(io, "# DCT-SMEAR Seasonal Batch Report\n\n")
		write(io, "- Input directory: $(IN_DIR)\n")
		write(io, "- Output directory: $(OUT_DIR)\n")
		write(io, "- Files processed: $(nrow(results))\n")
		write(io, "- Successful analyses: $(sum(results.status .== "ok"))\n")
		write(io, "- Failed/skipped: $(sum(results.status .!= "ok"))\n\n")

		write(io, "## Per-file Results\n\n")
		for row in eachrow(results)
			write(io, "- $(row.file): status=$(row.status), fingerprints=$(row.fingerprints), stable_fraction=$(round(100 * row.stable_fraction, digits=2))%\n")
		end

		write(io, "\n## Outputs\n\n")
		write(io, "- seasonal_file_summary.csv\n")
		write(io, "- plot_stable_fraction_by_file.png (when at least one successful file)\n")
		write(io, "- One subfolder per input CSV with fingerprints/report/plots\n")
	end
end

run_started = now()
write_status([
	"status=running",
	"started=$(run_started)",
	"input_dir=$(IN_DIR)",
	"out_dir=$(OUT_DIR)",
])

inputs = seasonal_inputs(IN_DIR)
isempty(inputs) && error("No seasonal CSV files found in $(IN_DIR)")

rows = NamedTuple[]
for csv_path in inputs
	println("Processing: $(basename(csv_path))")
	try
		push!(rows, process_file(csv_path))
	catch err
		out_dir = joinpath(OUT_DIR, replace(basename(csv_path), ".csv" => ""))
		mkpath(out_dir)
		open(joinpath(out_dir, "report.md"), "w") do io
			write(io, "# DCT-SMEAR Seasonal Results\n\n")
			write(io, "Failed to process $(basename(csv_path)).\n\n")
			write(io, "Error: $(sprint(showerror, err))\n")
		end
		push!(rows, (
			file=basename(csv_path),
			status="error",
			profile_source="",
			height_source="",
			profile_cols="",
			profile_heights="",
			raw_rows=0,
			profiles=0,
			fingerprints=0,
			stable_events=0,
			stable_fraction=0.0,
			out_dir=out_dir,
			report=joinpath(out_dir, "report.md"),
		))
	end
end

results = DataFrame(rows)
write_overall_outputs(results)

write_status([
	"status=ok",
	"started=$(run_started)",
	"finished=$(now())",
	"input_dir=$(IN_DIR)",
	"out_dir=$(OUT_DIR)",
	"files_processed=$(nrow(results))",
	"files_ok=$(sum(results.status .== "ok"))",
	"files_error=$(sum(results.status .== "error"))",
	"summary=$(joinpath(OUT_DIR, "seasonal_file_summary.csv"))",
	"report=$(joinpath(OUT_DIR, "report.md"))",
])

println("Seasonal DCT batch complete")
println("Summary: $(joinpath(OUT_DIR, "seasonal_file_summary.csv"))")
println("Report: $(joinpath(OUT_DIR, "report.md"))")
println("Status: $(STATUS_PATH)")