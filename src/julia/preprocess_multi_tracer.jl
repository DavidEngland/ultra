#!/usr/bin/env julia

# preprocess_multi_tracer.jl
#
# Multi-tracer MOST preprocessing engine.
# Supports momentum (φ_m), heat (φ_h), and generic tracers q_1..q_n.
# Reads from CSV files or fetches directly from the SmartSMEAR API.
# Outputs a multi-column CSV (one phi_<tracer> column per selected tracer),
# per-regime statistics, a tracer inventory, and a run summary.
#
# Usage (non-interactive):
#   julia preprocess_multi_tracer.jl <input_or_station> <output_base> <z_m> <d_m> [FLAGS]
#
# Flags:
#   --mode=raw|two-level|api-smear    (default: raw)
#   --tracers=momentum,heat           (comma-separated; default: momentum)
#   --interactive                     (interactive tracer selection via prompts)
#   --stable-only                     (keep only ζ > 0 rows)
#   --unstable-only                   (keep only ζ < 0 rows)
#   --wtv-eps=<eps>                   (near-neutral flux threshold; default 1e-12)
#   --ric=<value>                     (Ri_c for regime bins; default 0.25)
#   --zeta-neutral=<value>            (|ζ| ≤ value → near-neutral; default 0.1)
#
# Two-level mode:
#   --z1=<m> --z2=<m>
#
# API mode:
#   --from=ISO_DATETIME --to=ISO_DATETIME
#   --interval=30 --aggregation=ARITHMETIC --quality=ANY
#   --list-variables                  (inventory mode: list SMEAR vars then exit)
#   SMEAR variable flags (required unless --interactive):
#     Momentum:  --tv-uw=TABLE.VAR --tv-vw=TABLE.VAR
#     Wind profile (two-level): --tv-u1=TABLE.VAR --tv-u2=TABLE.VAR
#     Direct gradient (raw):    --tv-dudz=TABLE.VAR
#     Heat:      --tv-wthetav=TABLE.VAR --tv-thetav=TABLE.VAR
#                --tv-dthetadz=TABLE.VAR (raw) or --tv-theta1/2=TABLE.VAR (two-level)
#     Stability: --tv-mo-length=TABLE.VAR [--tv-ustar=TABLE.VAR]
#     Generic tracer qK (K=1,2,...):
#       --qK-name=<label>             (display name, e.g. CO2)
#       --qK-wflux=TABLE.VAR          (turbulent flux w′c′)
#       --qK-conc=TABLE.VAR           (mean concentration c̄)
#       --qK-grad=TABLE.VAR           (pre-computed dc/dz; raw mode)
#       --qK-c1=TABLE.VAR --qK-c2=TABLE.VAR  (two-level)
#       --qK-lambda=<float>           (baseline exponent; default 2)
#       --qK-phi-lo=<float>           (lower plausibility bound; default 0.1)
#       --qK-phi-hi=<float>           (upper plausibility bound; default 200)
#       --qK-wflux-eps=<float>        (min |w′c′| to compute phi; default 1e-6)

using CSV, DataFrames, Dates, Downloads, Statistics

include(joinpath(@__DIR__, "tracer_registry.jl"))

# Optional JSON3 for SMEAR inventory API responses
const HAVE_JSON3 = try
    @eval using JSON3
    true
catch
    false
end

# ─────────────────────────────── Constants ───────────────────────────────────

const KAPPA           = 0.4
const G               = 9.81
const DEFAULT_WTV_EPS = 1e-12
const SMEAR_BASE_URL  = "https://smear-backend-avaa-smear-prod.2.rahtiapp.fi"

# ─────────────────────────────── Helpers ─────────────────────────────────────

function parse_flag(args, key, default)
    for a in args
        startswith(a, key) || continue
        parts = split(a, "=", limit=2)
        length(parts) == 2 || return default
        return parts[2]
    end
    return default
end

function parse_float_flag(args, key)
    v = parse_flag(args, key, "")
    isempty(v) && return nothing
    r = tryparse(Float64, v)
    r === nothing && error("Cannot parse $(key) value as Float64: $(v)")
    return r
end

parse_required_flag(args, key) = begin
    v = parse_flag(args, key, "")
    isempty(v) && error("Missing required flag: $(key)=...")
    v
end

has_flag(args, f) = any(x -> x == f, args)

to_float(x) = x isa Missing ? NaN :
              x isa Number  ? Float64(x) :
              something(tryparse(Float64, strip(String(x))), NaN)

function pick_col(df, aliases; required=true)
    colmap = Dict(Symbol(lowercase(String(c))) => c for c in names(df))
    for a in aliases
        k = Symbol(lowercase(String(a)))
        haskey(colmap, k) && return colmap[k]
    end
    required && error("Missing required column.  Tried: $(join(string.(aliases), ", "))")
    return nothing
end

col_float(df, col) = [to_float(df[i, col]) for i in 1:nrow(df)]

maybe_col(df, aliases) = begin
    c = pick_col(df, aliases; required=false)
    c === nothing ? nothing : col_float(df, c)
end

output_base(p) = endswith(lowercase(p), ".csv") ? p[1:end-4] : p

# ────────────────────────── SMEAR API helpers ─────────────────────────────────

function smear_fetch_json(url::String)
    tmp = Downloads.download(url)
    txt = read(tmp, String)
    rm(tmp; force=true)
    return txt
end

"""
Query the SMEAR variable search API and return a list of (table, variable)
tuples that match `query`.  Requires JSON3; returns empty list if unavailable.
"""
function smear_search_variables(query::String = "")
    HAVE_JSON3 || begin
        @warn "JSON3 not installed; cannot fetch SMEAR variable inventory.\n  Install with: using Pkg; Pkg.add(\"JSON3\")"
        return NamedTuple[]
    end
    url = SMEAR_BASE_URL * "/search/variable"
    isempty(query) || (url *= "?name=$(query)")
    txt = smear_fetch_json(url)
    items = JSON3.read(txt)
    return [(table=get(x, :tableName, ""), variable=get(x, :name, ""),
             description=get(x, :description, "")) for x in items]
end

"""
Print a formatted variable inventory for a station.
Filters to tables whose name starts with `station_prefix` (case-insensitive).
"""
function print_smear_inventory(station_prefix::String; query::String = "")
    vars = smear_search_variables(query)
    isempty(vars) && begin
        println("  (no variables found — check station_prefix or JSON3 installation)")
        return
    end
    prefix_lo = lowercase(station_prefix)
    grouped   = Dict{String, Vector{String}}()
    for v in vars
        startswith(lowercase(v.table), prefix_lo) || continue
        push!(get!(grouped, v.table, String[]),
              isempty(v.description) ? v.variable : "$(v.variable)  — $(v.description)")
    end
    if isempty(grouped)
        println("  (no variables match station prefix '$(station_prefix)')")
        return
    end
    for tbl in sort(collect(keys(grouped)))
        println("  Table: $(tbl)")
        for vname in sort(grouped[tbl])
            println("    $(tbl).$(vname)")
        end
    end
end

"""
Write the tracer inventory artifact (CSV + short markdown).
"""
function write_tracer_inventory(base::String, selected::Vector{TracerDef},
                                mode::AbstractString, source::AbstractString)
    rows = [(tracer=t.id, display=t.display, phi_col=t.phi_col,
             scale_var=t.scale_var, lambda_unstable=t.lambda_unstable,
             b_unstable_default=t.b_unstable_default,
             phi_lo=t.phi_lo, phi_hi=t.phi_hi,
             sign_note=t.sign_note) for t in selected]
    CSV.write("$(base)_tracer_inventory.csv", DataFrame(rows))

    lines = [
        "# Tracer Inventory",
        "",
        "- source: $(source)",
        "- mode: $(mode)",
        "- tracers selected: $(join([string(t.id) for t in selected], ", "))",
        "",
        "| tracer | φ column | scale | λ_u | b_u | φ bounds | sign note |",
        "|---|---|---|---|---|---|---|",
    ]
    for t in selected
        push!(lines, "| $(t.display) | $(t.phi_col) | $(t.scale_var) | " *
              "$(t.lambda_unstable) | $(t.b_unstable_default) | " *
              "[$(t.phi_lo), $(t.phi_hi)] | $(t.sign_note) |")
    end
    write("$(base)_tracer_inventory.md", join(lines, "\n") * "\n")
end

# ─────────────────────────── SMEAR API fetch ─────────────────────────────────

struct QTracerSpec
    id        :: Symbol
    display   :: String
    tv_wflux  :: String    # tablevariable for w′c′
    tv_conc   :: String    # tablevariable for c̄ (mean)
    tv_grad   :: String    # tablevariable for dc/dz (raw mode; may be empty)
    tv_c1     :: String    # tablevariable for c at z1 (two-level; may be empty)
    tv_c2     :: String    # tablevariable for c at z2
    lambda    :: Float64
    phi_lo    :: Float64
    phi_hi    :: Float64
    wflux_eps :: Float64
end

"""
Parse generic tracer specs from CLI args.
Recognises --q1-..., --q2-..., etc.
"""
function parse_q_tracer_specs(args::Vector{String})::Vector{QTracerSpec}
    specs = QTracerSpec[]
    indices = Set{Int}()
    for a in args
        m = match(r"^--q(\d+)-", a)
        m === nothing || push!(indices, parse(Int, m.captures[1]))
    end
    for k in sort(collect(indices))
        pfx = "--q$(k)-"
        tv_wflux  = parse_flag(args, "$(pfx)wflux",    "")
        tv_conc   = parse_flag(args, "$(pfx)conc",     "")
        tv_grad   = parse_flag(args, "$(pfx)grad",     "")
        tv_c1     = parse_flag(args, "$(pfx)c1",       "")
        tv_c2     = parse_flag(args, "$(pfx)c2",       "")
        name      = parse_flag(args, "$(pfx)name",     "q$(k)")
        lambda    = parse_float_flag(args, "$(pfx)lambda")
        phi_lo    = parse_float_flag(args, "$(pfx)phi-lo")
        phi_hi    = parse_float_flag(args, "$(pfx)phi-hi")
        wflux_eps = parse_float_flag(args, "$(pfx)wflux-eps")
        push!(specs, QTracerSpec(
            Symbol("q$(k)"), name, tv_wflux, tv_conc, tv_grad, tv_c1, tv_c2,
            lambda    === nothing ? 2.0    : lambda,
            phi_lo    === nothing ? 0.1    : phi_lo,
            phi_hi    === nothing ? 200.0  : phi_hi,
            wflux_eps === nothing ? 1e-6   : wflux_eps,
        ))
    end
    return specs
end

function build_smear_tablevars(extra::Vector{String}, mode::String,
                                tracers::Vector{Symbol},
                                q_specs::Vector{QTracerSpec})::Vector{String}
    tv_set = String[]

    push_tv(s) = isempty(s) || push!(tv_set, s)

    # Stability / base flux variables
    mo_tv = parse_flag(extra, "--tv-mo-length", "")
    if !isempty(mo_tv)
        push!(tv_set, mo_tv)
        ustar_tv = parse_flag(extra, "--tv-ustar", "")
        isempty(ustar_tv) || push!(tv_set, ustar_tv)
    else
        for f in ("--tv-uw", "--tv-vw", "--tv-wthetav", "--tv-thetav")
            push_tv(parse_flag(extra, f, ""))
        end
    end

    # Profile / gradient variables
    if mode == "raw"
        push_tv(parse_flag(extra, "--tv-dudz", ""))
        push_tv(parse_flag(extra, "--tv-dthetadz", ""))
    else
        for f in ("--tv-u1", "--tv-u2", "--tv-theta1", "--tv-theta2")
            push_tv(parse_flag(extra, f, ""))
        end
    end

    # Heat tracer gradient
    if :heat in tracers
        push_tv(parse_flag(extra, "--tv-dthetadz", ""))
    end

    # Generic tracers
    for q in q_specs
        push_tv(q.tv_wflux); push_tv(q.tv_conc)
        push_tv(q.tv_grad);  push_tv(q.tv_c1); push_tv(q.tv_c2)
    end

    return unique(filter(!isempty, tv_set))
end

function fetch_smear_df(station_label::String, extra::Vector{String}, mode::String,
                         tracers::Vector{Symbol}, q_specs::Vector{QTracerSpec})
    from_iso    = parse_required_flag(extra, "--from")
    to_iso      = parse_required_flag(extra, "--to")
    interval    = parse_flag(extra, "--interval",    "30")
    aggregation = parse_flag(extra, "--aggregation", "ARITHMETIC")
    quality     = parse_flag(extra, "--quality",     "ANY")

    tablevars = build_smear_tablevars(extra, mode, tracers, q_specs)
    isempty(tablevars) && error("No tablevariable flags found.  Use --tv-* flags or --interactive.")

    params = ["from=$(from_iso)", "to=$(to_iso)", "interval=$(interval)",
              "aggregation=$(aggregation)", "quality=$(quality)"]
    for tv in tablevars
        push!(params, "tablevariable=$(tv)")
    end

    url = SMEAR_BASE_URL * "/search/timeseries/csv?" * join(params, "&")
    println("Fetching from SmartSMEAR ($(station_label)) …")
    tmp = Downloads.download(url)
    df  = CSV.read(tmp, DataFrame)
    rm(tmp; force=true)

    # Reconstruct timestamp
    if all(c -> c in names(df), [:Year, :Month, :Day, :Hour, :Minute, :Second])
        df.timestamp = [Dates.format(
            DateTime(Int(to_float(df.Year[i])), Int(to_float(df.Month[i])),
                     Int(to_float(df.Day[i])),  Int(to_float(df.Hour[i])),
                     Int(to_float(df.Minute[i])), Int(to_float(df.Second[i]))),
            dateformat"yyyy-mm-ddTHH:MM:SS") for i in 1:nrow(df)]
    end

    # Alias columns from tablevariable names
    colmap_lo = Dict(lowercase(String(c)) => c for c in names(df))
    for tv in tablevars
        k = lowercase(tv)
        haskey(colmap_lo, k) || error("SMEAR response missing expected column for '$(tv)'.")
    end

    println("  → $(nrow(df)) rows fetched")
    return df
end

# ─────────────────────────── Interactive selection ────────────────────────────

"""
Run the interactive tracer-selection wizard.
Returns (selected_tracer_symbols, q_specs, updated_extra_args).
"""
function interactive_select_tracers(station_label::String, extra::Vector{String},
                                    mode::String)
    println()
    println("=" ^ 60)
    println("  Multi-Tracer Preprocessor — Interactive Setup")
    println("=" ^ 60)
    println()

    # ── Variable inventory (api-smear only) ──
    if mode == "api-smear"
        println("Fetching variable inventory for station '$(station_label)' …")
        println("(Requires JSON3.  Install once with:  using Pkg; Pkg.add(\"JSON3\"))")
        println()
        print_smear_inventory(station_label)
        println()
    end

    # ── Standard tracer menu ──
    println("Standard tracers available:")
    builtin = [(:momentum, "Momentum (φ_m)  —  requires: u*w*, v*w*, dU/dz or two-level"),
               (:heat,     "Heat     (φ_h)  —  requires: w*θ_v*, θ_v, dθ/dz or two-level")]
    for (i, (id, desc)) in enumerate(builtin)
        println("  [$i] $(desc)")
    end
    println()
    print("Enter numbers to select (comma-separated, e.g. '1,2'): ")
    sel_str = strip(readline())
    selected = Symbol[]
    for tok in split(sel_str, r"[,\s]+")
        n = tryparse(Int, strip(tok))
        (n !== nothing && 1 ≤ n ≤ length(builtin)) && push!(selected, builtin[n][1])
    end
    isempty(selected) && push!(selected, :momentum)
    println("  → Selected: $(join(string.(selected), ", "))")
    println()

    # ── Generic tracers ──
    print("Add a generic tracer (e.g. CO2, humidity)? [y/N]: ")
    add_q = lowercase(strip(readline()))
    q_specs = QTracerSpec[]
    q_k = 1
    while add_q == "y"
        println()
        println("  Generic tracer q$(q_k):")
        print("    Display name (e.g. CO2): ")
        q_name = strip(readline())
        isempty(q_name) && (q_name = "q$(q_k)")

        tv_wflux = ""
        if mode == "api-smear"
            print("    SMEAR tablevariable for turbulent flux w′c′ (TABLE.VAR): ")
            tv_wflux = strip(readline())
            print("    SMEAR tablevariable for mean concentration c̄ (TABLE.VAR): ")
            tv_conc  = strip(readline())
        else
            tv_conc = ""
        end

        tv_grad = ""; tv_c1 = ""; tv_c2 = ""
        if mode == "raw"
            print("    Column alias for dc/dz gradient (or leave blank to skip): ")
            tv_grad = strip(readline())
        elseif mode == "two-level"
            print("    Column alias for c at z1 (lower level): ")
            tv_c1 = strip(readline())
            print("    Column alias for c at z2 (upper level): ")
            tv_c2 = strip(readline())
        end

        print("    Baseline exponent λ (2=heat-like, 4=momentum-like) [2]: ")
        lam_str = strip(readline())
        lam_val = isempty(lam_str) ? 2.0 : something(tryparse(Float64, lam_str), 2.0)

        push!(q_specs, QTracerSpec(
            Symbol("q$(q_k)"), q_name, tv_wflux,
            mode == "api-smear" ? tv_conc : "",
            tv_grad, tv_c1, tv_c2, lam_val, 0.1, 200.0, 1e-6))
        q_k += 1

        print("  Add another generic tracer? [y/N]: ")
        add_q = lowercase(strip(readline()))
    end

    # ── Variable mappings for api-smear ──
    if mode == "api-smear" && !isempty(selected)
        println()
        println("Now enter the SmartSMEAR tablevariable flags for selected tracers.")
        println("Format: TABLE.VARIABLE  (e.g.  HYY_EDDY233.uw)")
        println()

        extra_interactive = copy(extra)

        function prompt_tv(flag_key, prompt_str, required=true)
            existing = parse_flag(extra_interactive, flag_key, "")
            isempty(existing) || return  # already set
            print("  $(prompt_str): ")
            val = strip(readline())
            if !isempty(val)
                push!(extra_interactive, "$(flag_key)=$(val)")
            elseif required
                @warn "  (skipped — you may need to re-run with $(flag_key)=TABLE.VAR)"
            end
        end

        println("── Stability / base flux ──")
        prompt_tv("--tv-uw",       "Momentum flux  --tv-uw")
        prompt_tv("--tv-vw",       "Cross flux     --tv-vw")
        prompt_tv("--tv-wthetav",  "Buoyancy flux  --tv-wthetav")
        prompt_tv("--tv-thetav",   "Virtual temp   --tv-thetav", false)

        if :momentum in selected
            println("── Momentum gradient ──")
            if parse_flag(extra_interactive, "--profile-mode", "raw") == "two-level"
                prompt_tv("--tv-u1", "Wind at z1  --tv-u1")
                prompt_tv("--tv-u2", "Wind at z2  --tv-u2")
            else
                prompt_tv("--tv-dudz", "Wind gradient  --tv-dudz (or blank for two-level)", false)
            end
        end

        if :heat in selected
            println("── Heat gradient ──")
            if parse_flag(extra_interactive, "--profile-mode", "raw") == "two-level"
                prompt_tv("--tv-theta1", "Temp at z1  --tv-theta1")
                prompt_tv("--tv-theta2", "Temp at z2  --tv-theta2")
            else
                prompt_tv("--tv-dthetadz", "Temp gradient  --tv-dthetadz (or blank)", false)
            end
        end

        return selected, q_specs, extra_interactive
    end

    return selected, q_specs, extra
end

# ──────────────────────────── Core φ computation ─────────────────────────────

"""
Compute phi_obs for a single generic tracer q_k.

  phi_q = κ·z_eff / q_* · (dc/dz)
  q_*   = −w′c′ / u_*

Returns (phi_q_vector, n_valid).
"""
function compute_phi_q(ustar::Vector{Float64},
                       wflux::Vector{Float64},
                       dcdz::Vector{Float64},
                       z_eff::Float64,
                       spec::QTracerSpec)
    n     = length(ustar)
    phi_q = fill(NaN, n)
    for i in 1:n
        isfinite(ustar[i]) && ustar[i] > 0 || continue
        isfinite(wflux[i]) || continue
        abs(wflux[i]) < spec.wflux_eps && continue
        isfinite(dcdz[i]) || continue
        q_star = -wflux[i] / ustar[i]
        abs(q_star) < 1e-30 && continue
        phi_q[i] = KAPPA * z_eff * dcdz[i] / q_star
    end
    return phi_q
end

# ──────────────────────────────── Main ───────────────────────────────────────

function print_usage()
    println("""
Usage:
  julia preprocess_multi_tracer.jl <input_or_station> <output_base> <z_m> <d_m> [FLAGS]

FLAGS:
  --mode=raw|two-level|api-smear       (default: raw)
  --tracers=momentum,heat              (comma-separated list)
  --interactive                        (guided wizard instead of --tracers)
  --stable-only | --unstable-only
  --wtv-eps=<eps>                      (near-neutral threshold; default 1e-12)
  --ric=<float>                        (Ri_c for regime bins; default 0.25)
  --zeta-neutral=<float>               (|ζ| ≤ this → near-neutral; default 0.1)
  --list-variables                     (api-smear: print variable inventory and exit)

  Two-level mode:
    --z1=<m> --z2=<m>

  API mode:
    --from=ISO_DATETIME --to=ISO_DATETIME
    --interval=30 --aggregation=ARITHMETIC --quality=ANY
    --tv-uw=TABLE.VAR --tv-vw=TABLE.VAR
    --tv-wthetav=TABLE.VAR --tv-thetav=TABLE.VAR
    --tv-dudz=TABLE.VAR  OR  --tv-u1/u2=TABLE.VAR (two-level)
    --tv-dthetadz=TABLE.VAR  OR  --tv-theta1/2=TABLE.VAR (two-level)

  Generic tracers (K = 1, 2, ...):
    --qK-name=<label>
    --qK-wflux=TABLE.VAR  --qK-conc=TABLE.VAR
    --qK-grad=TABLE.VAR   (raw) or --qK-c1/c2=TABLE.VAR (two-level)
    --qK-lambda=<float>   (baseline exponent; default 2)
    --qK-wflux-eps=<float>
""")
end

function main()
    if length(ARGS) < 4 || has_flag(ARGS, "--help")
        print_usage()
        return
    end

    input_src  = ARGS[1]
    output_csv = ARGS[2]
    z_m        = parse(Float64, ARGS[3])
    d_m        = parse(Float64, ARGS[4])
    extra      = length(ARGS) > 4 ? collect(ARGS[5:end]) : String[]

    z_eff = z_m - d_m
    z_eff > 0 || error("z_m - d_m must be > 0.  Got z_m=$(z_m), d_m=$(d_m)")

    mode       = parse_flag(extra, "--mode", "raw")
    wtv_eps    = something(parse_float_flag(extra, "--wtv-eps"), DEFAULT_WTV_EPS)
    ric        = something(parse_float_flag(extra, "--ric"),     DEFAULT_RIC)
    zeta_neut  = something(parse_float_flag(extra, "--zeta-neutral"), DEFAULT_ZETA_NEUTRAL)
    stable_only   = has_flag(extra, "--stable-only")
    unstable_only = has_flag(extra, "--unstable-only")

    mode in ("raw", "two-level", "api-smear") ||
        error("--mode must be raw, two-level, or api-smear")

    # ── Variable inventory mode ──
    if mode == "api-smear" && has_flag(extra, "--list-variables")
        println("SMEAR variable inventory for '$(input_src)':")
        print_smear_inventory(input_src)
        return
    end

    # ── Tracer selection ──
    q_specs = parse_q_tracer_specs(extra)

    selected_ids, q_specs, extra = if has_flag(extra, "--interactive")
        profile_mode = parse_flag(extra, "--profile-mode", "raw")
        actual_mode  = mode == "api-smear" ? profile_mode : mode
        interactive_select_tracers(input_src, extra, actual_mode)
    else
        sel_str = parse_flag(extra, "--tracers", "momentum")
        ids = [Symbol(strip(s)) for s in split(sel_str, ',') if !isempty(strip(s))]
        isempty(ids) && push!(ids, :momentum)
        ids, q_specs, extra
    end

    # Build TracerDef list (builtins + generic q)
    selected_tracers = TracerDef[]
    for id in selected_ids
        haskey(TRACER_REGISTRY, id) || error("Unknown tracer '$(id)'.  Built-ins: momentum, heat.  For custom tracers use --qK-* flags.")
        push!(selected_tracers, TRACER_REGISTRY[id])
    end
    q_tracerdefs = [generic_tracer(q.id;
                        display=q.display,
                        lambda_unstable=q.lambda,
                        phi_lo=q.phi_lo, phi_hi=q.phi_hi,
                        wflux_eps=q.wflux_eps)
                    for q in q_specs]
    all_tracers = vcat(selected_tracers, q_tracerdefs)

    println("\nTracers selected: $(join([t.display for t in all_tracers], ", "))")

    # ── Load data ──
    profile_mode = parse_flag(extra, "--profile-mode", "raw")
    actual_mode  = mode == "api-smear" ? profile_mode : mode

    df = if mode == "api-smear"
        fetch_smear_df(input_src, extra, actual_mode, selected_ids, q_specs)
    else
        CSV.read(input_src, DataFrame)
    end
    n = nrow(df)

    # ── Column binding ──
    c_mo       = pick_col(df, [:mo_length, :MO_length, :L, :monin_obukhov_length]; required=false)
    c_ust_dir  = pick_col(df, [:u_star, :ustar, :uStar]; required=false)
    have_direct_mo = c_mo !== nothing

    c_uw  = pick_col(df, [:uw, :u_w_cov, :u_prime_w_prime]; required=!have_direct_mo)
    c_vw  = pick_col(df, [:vw, :v_w_cov, :v_prime_w_prime]; required=!have_direct_mo)
    c_wtv = pick_col(df, [:wthetav, :w_theta_v, :wthetav_cov]; required=!have_direct_mo)
    c_tv  = pick_col(df, [:thetav, :theta_v, :theta_v_mean]; required=!have_direct_mo)

    uw        = c_uw  === nothing ? fill(NaN, n) : col_float(df, c_uw)
    vw        = c_vw  === nothing ? fill(NaN, n) : col_float(df, c_vw)
    wtv       = c_wtv === nothing ? fill(NaN, n) : col_float(df, c_wtv)
    thetav    = c_tv  === nothing ? fill(NaN, n) : col_float(df, c_tv)
    mo_direct = c_mo  === nothing ? fill(NaN, n) : col_float(df, c_mo)
    ust_dir   = c_ust_dir === nothing ? fill(NaN, n) : col_float(df, c_ust_dir)

    # Gradients for momentum and heat
    dudz = dthetadz = nothing
    if actual_mode == "raw"
        dudz      = maybe_col(df, [:dudz, :dU_dz, :dUdz])
        dthetadz  = maybe_col(df, [:dthetadz, :dtheta_dz, :dthetav_dz])
    elseif actual_mode == "two-level"
        z1 = something(parse_float_flag(extra, "--z1"), error("--z1 required for two-level mode"))
        z2 = something(parse_float_flag(extra, "--z2"), error("--z2 required for two-level mode"))
        dz = z2 - z1
        abs(dz) > 0 || error("two-level mode requires z1 ≠ z2")

        c_u1 = pick_col(df, [:u1, :u_low, :U1, :wind_low])
        c_u2 = pick_col(df, [:u2, :u_high, :U2, :wind_high])
        c_t1 = pick_col(df, [:theta1, :theta_low, :T1, :temp_low])
        c_t2 = pick_col(df, [:theta2, :theta_high, :T2, :temp_high])

        u1 = col_float(df, c_u1); u2 = col_float(df, c_u2)
        t1 = col_float(df, c_t1); t2 = col_float(df, c_t2)
        dudz     = (u2 .- u1) ./ dz
        dthetadz = (t2 .- t1) ./ dz
    end

    # Generic tracer gradients
    q_dcdz = Vector{Union{Vector{Float64}, Nothing}}(nothing, length(q_specs))
    q_wflux = Vector{Union{Vector{Float64}, Nothing}}(nothing, length(q_specs))
    for (k, q) in enumerate(q_specs)
        if !isempty(q.tv_wflux)
            q_wflux[k] = maybe_col(df, [Symbol(lowercase(q.tv_wflux)), Symbol(q.tv_wflux)])
        end
        if actual_mode == "raw" && !isempty(q.tv_grad)
            q_dcdz[k] = maybe_col(df, [Symbol(lowercase(q.tv_grad)), Symbol(q.tv_grad)])
        elseif actual_mode == "two-level" && !isempty(q.tv_c1) && !isempty(q.tv_c2)
            c1v = maybe_col(df, [Symbol(lowercase(q.tv_c1)), Symbol(q.tv_c1)])
            c2v = maybe_col(df, [Symbol(lowercase(q.tv_c2)), Symbol(q.tv_c2)])
            if c1v !== nothing && c2v !== nothing
                q_dcdz[k] = (c2v .- c1v) ./ (z2 - z1)
            end
        end
    end

    # ── Core physics loop ──
    ustar       = fill(NaN, n)
    L_arr       = fill(NaN, n)
    zeta_arr    = fill(NaN, n)
    neutral_flg = falses(n)
    phi_m_arr   = fill(NaN, n)
    phi_h_arr   = fill(NaN, n)

    for i in 1:n
        # u_*
        if isfinite(ust_dir[i]) && ust_dir[i] > 0
            ustar[i] = ust_dir[i]
        elseif isfinite(uw[i]) && isfinite(vw[i])
            tau = sqrt(uw[i]^2 + vw[i]^2)
            ustar[i] = sqrt(tau)
        end

        # Obukhov length / ζ
        if have_direct_mo && isfinite(mo_direct[i]) && mo_direct[i] != 0.0
            L_arr[i]    = mo_direct[i]
            zeta_arr[i] = z_eff / L_arr[i]
        else
            !isfinite(ustar[i]) || ustar[i] ≤ 0 && continue
            !isfinite(thetav[i]) || thetav[i] ≤ 0 && continue
            !isfinite(wtv[i])                      && continue

            if abs(wtv[i]) ≤ wtv_eps
                neutral_flg[i] = true
                zeta_arr[i]    = 0.0
                L_arr[i]       = wtv[i] < 0 ? Inf : -Inf
            else
                L_arr[i]    = -(ustar[i]^3 * thetav[i]) / (KAPPA * G * wtv[i])
                zeta_arr[i] = z_eff / L_arr[i]
            end
        end

        # φ_m
        if dudz !== nothing && isfinite(dudz[i]) && isfinite(ustar[i]) && ustar[i] > 0
            phi_m_arr[i] = KAPPA * z_eff * dudz[i] / ustar[i]
        end

        # φ_h
        if dthetadz !== nothing && isfinite(dthetadz[i]) &&
           isfinite(ustar[i]) && ustar[i] > 0 && isfinite(wtv[i])
            theta_star = -wtv[i] / ustar[i]
            if abs(theta_star) > 1e-12
                phi_h_arr[i] = KAPPA * z_eff * dthetadz[i] / theta_star
            end
        end
    end

    # Generic tracer phi
    q_phi_arrays = Dict{Symbol, Vector{Float64}}()
    for (k, q) in enumerate(q_specs)
        wflux_v = q_wflux[k] !== nothing ? q_wflux[k] : fill(NaN, n)
        dcdz_v  = q_dcdz[k]  !== nothing ? q_dcdz[k]  : fill(NaN, n)
        q_phi_arrays[q.id] = compute_phi_q(ustar, wflux_v, dcdz_v, z_eff, q)
    end

    # Gradient Richardson number (when both phi_m and phi_h are finite)
    rig_arr = fill(NaN, n)
    for i in 1:n
        isfinite(zeta_arr[i]) && isfinite(phi_m_arr[i]) && isfinite(phi_h_arr[i]) &&
        phi_m_arr[i] > 0 &&
        (rig_arr[i] = zeta_arr[i] * phi_h_arr[i] / phi_m_arr[i]^2)
    end

    regimes = assign_regimes(zeta_arr, rig_arr; ric, zeta_neutral=zeta_neut)

    # ── Quality filter ──
    qpass = isfinite.(zeta_arr) .& isfinite.(ustar)
    stable_only   && (qpass .&= zeta_arr .> 0.0)
    unstable_only && (qpass .&= zeta_arr .< 0.0)

    # ── Assemble output DataFrame ──
    out = DataFrame()
    if :time in names(df)
        out.time = df.time[qpass]
    elseif :timestamp in names(df)
        out.time = df.timestamp[qpass]
    else
        out.time = collect(1:n)[qpass]
    end
    out.zeta        = zeta_arr[qpass]
    out.u_star      = ustar[qpass]
    out.L           = L_arr[qpass]
    out.Ri_g        = rig_arr[qpass]
    out.regime      = string.(regimes[qpass])
    out.neutral_transition = neutral_flg[qpass]
    out.phi_m       = phi_m_arr[qpass]
    out.phi_h       = phi_h_arr[qpass]
    for (q, t) in zip(q_specs, q_tracerdefs)
        out[!, t.phi_col] = q_phi_arrays[q.id][qpass]
    end

    # Legacy single-target phi_obs column (first tracer's phi)
    first_phi_col = length(all_tracers) > 0 ? all_tracers[1].phi_col : :phi_m
    out.phi_obs = out[!, first_phi_col]

    mkpath(dirname(output_csv) == "" ? "." : dirname(output_csv))
    CSV.write(output_csv, out)
    println("\nWrote $(nrow(out)) rows to $(output_csv)")

    # ── Per-tracer regime stats ──
    base = output_base(output_csv)
    all_regime_stats = DataFrame[]
    out_cols = Set(Symbol.(names(out)))
    for t in all_tracers
        phi_col = t.phi_col
        phi_col in out_cols || continue
        phi_vec = Vector{Float64}(out[!, phi_col])
        # Apply per-tracer physical bounds
        valid   = isfinite.(phi_vec) .& (phi_vec .>= t.phi_lo) .& (phi_vec .<= t.phi_hi)
        if !any(valid)
            @warn "Tracer $(t.id): no valid φ values after bounds filter [$(t.phi_lo), $(t.phi_hi)]"
            continue
        end
        zv = Vector{Float64}(out.zeta[valid])
        pv = phi_vec[valid]
        rv = Vector{Float64}(out.Ri_g[valid])
        stats = regime_stats(zv, pv, rv; ric, zeta_neutral=zeta_neut, tracer_id=String(t.id))
        push!(all_regime_stats, stats)
    end

    if !isempty(all_regime_stats)
        combined_stats = vcat(all_regime_stats...)
        CSV.write("$(base)_regime_stats.csv", combined_stats)
        println("Wrote regime stats to $(base)_regime_stats.csv")
    end

    # ── Tracer inventory ──
    write_tracer_inventory(base, all_tracers, mode, input_src)
    println("Wrote tracer inventory to $(base)_tracer_inventory.csv")

    # ── Preprocessing summary ──
    write_preprocess_summary(output_csv, out, all_tracers, input_src, mode,
                              stable_only, unstable_only, z_m, d_m, z_eff,
                              wtv_eps, ric, zeta_neut, n, count(neutral_flg))
    println("Wrote summary to $(base)_preprocess_summary.md")

    # Per-tracer sign convention reminder
    println("\n── Sign convention reminders ──")
    for t in all_tracers
        println("  $(t.display): $(t.sign_note)")
    end
end

# ────────────────────────── Summary writer ───────────────────────────────────

function write_preprocess_summary(output_csv, out, tracers, input_source, mode,
                                   stable_only, unstable_only, z_m, d_m, z_eff,
                                   wtv_eps, ric, zeta_neut, total_rows, neutral_count)
    base = output_base(output_csv)
    nw   = nrow(out)
    has  = nw > 0
    zv   = has ? Vector{Float64}(out.zeta) : Float64[]

    tracer_lines = String[]
    out_cols = Set(Symbol.(names(out)))
    for t in tracers
        phi_col = t.phi_col
        phi_col in out_cols || continue
        pv = filter(isfinite, Vector{Float64}(out[!, phi_col]))
        isempty(pv) && continue
        push!(tracer_lines,
              "  - $(t.display):  n_finite=$(length(pv))  " *
              "q50=$(round(quantile(pv,0.5),digits=3))  " *
              "[q05=$(round(quantile(pv,0.05),digits=3)), " *
              "q95=$(round(quantile(pv,0.95),digits=3))]")
    end

    regime_counts = if has
        regimes_out = Symbol.(out.regime)
        Dict(lab => count(==(lab), regimes_out) for lab in REGIME_ORDER)
    else
        Dict(lab => 0 for lab in REGIME_ORDER)
    end

    lines = [
        "# Multi-Tracer Preprocess Summary",
        "",
        "## Source",
        "",
        "- input: $(input_source)",
        "- mode: $(mode)",
        "- stable_only: $(stable_only)  unstable_only: $(unstable_only)",
        "",
        "## Geometry and Thresholds",
        "",
        "- z_m=$(z_m)  d_m=$(d_m)  z_eff=$(z_eff)",
        "- wtv_eps=$(wtv_eps)  Ri_c=$(ric)  ζ_neutral=$(zeta_neut)",
        "",
        "## Row Accounting",
        "",
        "- total rows read: $(total_rows)",
        "- rows written: $(nw)",
        "- near-neutral transitions flagged: $(neutral_count)",
        "",
        "## Regime Counts  (Ri_c = $(ric))",
        "",
        join(["- $(REGIME_DISPLAY[lab]): $(get(regime_counts,lab,0))" for lab in REGIME_ORDER], "\n"),
        "",
        "## ζ Distribution",
        "",
        has ? "- range: [$(round(minimum(zv),digits=4)), $(round(maximum(zv),digits=4))]" : "- (no data)",
        has ? "- quantiles 5/50/95%: $(round(quantile(zv,0.05),digits=4)) / $(round(quantile(zv,0.50),digits=4)) / $(round(quantile(zv,0.95),digits=4))" : "",
        "",
        "## φ by Tracer",
        "",
        isempty(tracer_lines) ? "- (none)" : join(tracer_lines, "\n"),
        "",
        "## Sign Convention Reminders",
        "",
        join(["- $(t.display): $(t.sign_note)" for t in tracers], "\n"),
        "",
        "## Artifacts",
        "",
        "- data CSV: $(output_csv)",
        "- regime stats: $(base)_regime_stats.csv",
        "- tracer inventory: $(base)_tracer_inventory.csv  /  $(base)_tracer_inventory.md",
        "- summary: $(base)_preprocess_summary.md",
    ]
    write("$(base)_preprocess_summary.md", join(lines, "\n") * "\n")
end

try
    main()
catch err
    println(stderr, "Error: ", err)
    for (exc, bt) in Base.catch_stack()
        showerror(stderr, exc, bt)
        println(stderr)
    end
    exit(1)
end
