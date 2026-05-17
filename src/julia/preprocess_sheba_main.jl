#!/usr/bin/env julia
# preprocess_sheba_main.jl
# ------------------------------------------------------------------
# Download (or read) SHEBA text data and compute zeta = z/L plus
# dimensionless stability functions for momentum, heat, and humidity.
#
# Supports both:
# - NOAA PSL main_file6_hd style two-level fields
# - NCAR/EOL ASFG 5-level profile file (prof_file_all6_ed_hd.txt)
#
# Output: CSV with compatibility columns (time, zeta, phi_obs) plus
# explicit phi_m / phi_h / phi_q columns and richer multilevel/flux fields.
#
# Usage:
#   julia julia/preprocess_sheba_main.jl <output_csv> [input_txt]
#
# If input_txt is omitted the file is downloaded from NOAA PSL.
# ------------------------------------------------------------------

using CSV, DataFrames, Statistics, Downloads, Dates

const DATA_URL = "https://psl.noaa.gov/arctic/sheba/netcdf/PerssonDatasets/main_file6_hd.txt"
const KAPPA    = 0.40     # von Kármán constant
const G        = 9.81     # m s⁻²
const RHO_CP   = 1200.0   # J m⁻³ K⁻¹  (ρ cₚ for arctic surface air)
const RHO_AIR  = 1.30     # kg m⁻³  representative near-surface arctic air density
const L_V      = 2.5e6    # J kg⁻¹ latent heat of vaporization/sublimation scale
const MISSING_VAL = 9000.0  # values ≥ 9000 are flagged missing (9999)

# Reference heights (metres) for the 2-level wind profile
const DEFAULT_Z_LO = 2.5
const DEFAULT_Z_HI = 10.0

# Quality-control thresholds
const USTAR_MIN   = 0.05   # m s⁻¹
const HS_ABS_MIN  = 2.0    # W m⁻²  (avoid near-neutral scatter)
const ZETA_MAX    = 10.0   # upper limit for stable zeta
const PHI_MAX     = 30.0   # upper limit on dimensionless wind shear

function compute_L(ustar, hs_wm2, T_C)
    # Obukhov length [m]  (positive in stable stratification)
    # L = - u*³ Tᵥ / (κ g H)   where H = hs/(ρ cₚ) [K m s⁻¹]
    T_K = T_C + 273.15
    H   = hs_wm2 / RHO_CP           # kinematic heat flux [K m s⁻¹]
    if abs(H) < 1e-10 || ustar < 1e-4
        return NaN
    end
    return -(ustar^3 * T_K) / (KAPPA * G * H)
end

function compute_phi_m(ws_lo, ws_hi, ustar, z_lo, z_hi)
    # Dimensionless wind shear at geometric-mean height Z_REF
    dz = z_hi - z_lo
    if dz <= 0
        return NaN
    end
    z_ref = sqrt(z_lo * z_hi)
    dU_dz = (ws_hi - ws_lo) / dz
    return (KAPPA * z_ref / ustar) * dU_dz
end

function compute_phi_h(t_lo, t_hi, hs_wm2, ustar, z_lo, z_hi)
    dz = z_hi - z_lo
    if dz <= 0 || !isfinite(hs_wm2) || !isfinite(ustar) || ustar <= 0
        return NaN
    end
    theta_star = -(hs_wm2 / RHO_CP) / ustar
    abs(theta_star) > 1e-12 || return NaN
    z_ref = sqrt(z_lo * z_hi)
    dtdz = (t_hi - t_lo) / dz
    return KAPPA * z_ref * dtdz / theta_star
end

function compute_phi_q(q_lo_gkg, q_hi_gkg, hl_wm2, ustar, z_lo, z_hi)
    dz = z_hi - z_lo
    if dz <= 0 || !isfinite(hl_wm2) || !isfinite(ustar) || ustar <= 0
        return NaN
    end
    qflux = hl_wm2 / (RHO_AIR * L_V)   # kg kg^-1 m s^-1
    q_star = -qflux / ustar
    abs(q_star) > 1e-12 || return NaN
    z_ref = sqrt(z_lo * z_hi)
    dqdz = ((q_hi_gkg - q_lo_gkg) * 1e-3) / dz
    return KAPPA * z_ref * dqdz / q_star
end

function load_sheba(path::AbstractString)
    # Both known SHEBA files are tab-delimited with a single variable-name header row.
    df = CSV.read(path, DataFrame; delim='\t', header=1,
                  missingstring=["9999", "999"],
                  normalizenames=true)
    return df
end

to_num(x) = begin
    if ismissing(x)
        return NaN
    elseif x isa Number
        return Float64(x)
    elseif x isa AbstractString
        y = tryparse(Float64, strip(x))
        return isnothing(y) ? NaN : y
    end
    return NaN
end

function cleaned_num(x)
    v = to_num(x)
    (!isfinite(v) || abs(v) >= MISSING_VAL) ? NaN : v
end

function first_existing(cols::Vector{String}, candidates::Vector{String})
    for c in candidates
        if c in cols
            return c
        end
    end
    return nothing
end

function pull_num(df::DataFrame, i::Int, c::Union{Nothing,String})
    isnothing(c) && return NaN
    return cleaned_num(df[i, c])
end

function median_available(df::DataFrame, i::Int, candidates::Vector{String})
    vals = Float64[]
    for c in candidates
        c in names(df) || continue
        v = cleaned_num(df[i, c])
        isfinite(v) || continue
        push!(vals, v)
    end
    return isempty(vals) ? NaN : median(vals)
end

function jd_to_datetime(jd::Float64)
    isfinite(jd) || return missing
    day_int = floor(Int, jd)
    frac = jd - day_int
    # Dataset uses day-of-year; we anchor to 1998 to provide a deterministic DateTime.
    return DateTime(1998, 1, 1) + Day(day_int - 1) + Millisecond(round(Int, frac * 86_400_000))
end

function attach_optional!(out::DataFrame, source::DataFrame, row_idx::Vector{Int}, cols::Vector{String})
    for c in cols
        c in names(source) || continue
        out[!, c] = [cleaned_num(source[i, c]) for i in row_idx]
    end
end

function main()
    if length(ARGS) < 1
        println("Usage: julia preprocess_sheba_main.jl <output_csv> [input_txt]")
        println("  output_csv : path for the output zeta/phi CSV")
        println("  input_txt  : path to local SHEBA txt file (downloaded main_file6_hd.txt if omitted)")
        exit(1)
    end

    out_csv   = ARGS[1]
    input_txt = length(ARGS) >= 2 ? ARGS[2] : nothing

    # Ensure output directory exists
    mkpath(dirname(out_csv))

    # Download if needed
    local_txt = if input_txt !== nothing
        input_txt
    else
        tmp = tempname() * ".txt"
        @info "Downloading SHEBA main_file6_hd.txt from NOAA PSL …"
        Downloads.download(DATA_URL, tmp)
        @info "Downloaded to $tmp"
        tmp
    end

    @info "Reading $local_txt …"
    df = load_sheba(local_txt)
    @info "Loaded $(nrow(df)) rows, $(ncol(df)) columns"

    col_names = String.(names(df))
    @info "Columns: $(join(col_names, ", "))"

    jd_col = first_existing(col_names, ["JD", "JJD"])
    isnothing(jd_col) && error("Missing JD/JJD column in input")

    # Support legacy main_file6 and 5-level NCAR profile inputs.
    ws_lo_col = first_existing(col_names, ["ws2_5", "ws2_5_", "ws2_5__1", "ws2_5_1", "ws1", "ws2"])
    ws_hi_col = first_existing(col_names, ["ws10", "ws10_", "ws5", "ws4"])
    t_lo_col = first_existing(col_names, ["T2_5", "T2_5_", "T2_5__1", "T2_5_1", "T1", "T2"])
    t_hi_col = first_existing(col_names, ["T10", "T10_", "T5", "T4"])
    q_lo_col = first_existing(col_names, ["q1", "q2"])
    q_hi_col = first_existing(col_names, ["q5", "q4"])

    z_lo_col = first_existing(col_names, ["z1", "z2"])
    z_hi_col = first_existing(col_names, ["z5", "z4", "zoph"])

    ustar_single_col = first_existing(col_names, ["u_", "u__1", "ustar", "u_star"])
    hs_single_col = first_existing(col_names, ["hs"])
    hl_single_col = first_existing(col_names, ["hl"])

    n_total = nrow(df)

    # Build output arrays
    kept_idx = Int[]
    times    = Float64[]
    datetimes = Union{Missing,DateTime}[]
    zeta_out = Float64[]
    phi_m_out = Float64[]
    phi_h_out = Float64[]
    phi_q_out = Float64[]
    l_out    = Float64[]
    ustar_out = Float64[]
    hs_out = Float64[]
    hl_out = Float64[]
    ws_lo_out = Float64[]
    ws_hi_out = Float64[]
    t_lo_out = Float64[]
    t_hi_out = Float64[]
    q_lo_out = Float64[]
    q_hi_out = Float64[]
    z_lo_out = Float64[]
    z_hi_out = Float64[]

    n_missing_ustar = 0
    n_missing_ws    = 0
    n_missing_hs    = 0
    n_unstable      = 0
    n_qc_fail       = 0
    n_good          = 0

    for i in 1:n_total
        # Extract values; treat missing or ≥ MISSING_VAL as bad
        u = isfinite(pull_num(df, i, ustar_single_col)) ? pull_num(df, i, ustar_single_col) :
            median_available(df, i, ["u_1", "u_2", "u_3", "u_4", "u_5"])
        h = isfinite(pull_num(df, i, hs_single_col)) ? pull_num(df, i, hs_single_col) :
            median_available(df, i, ["hs1", "hs2", "hs3", "hs4", "hs5"])
        hl = pull_num(df, i, hl_single_col)

        wl = pull_num(df, i, ws_lo_col)
        wh = pull_num(df, i, ws_hi_col)
        tl = pull_num(df, i, t_lo_col)
        th = pull_num(df, i, t_hi_col)
        ql = pull_num(df, i, q_lo_col)
        qh = pull_num(df, i, q_hi_col)
        t = pull_num(df, i, jd_col)

        z_lo = pull_num(df, i, z_lo_col)
        z_hi = pull_num(df, i, z_hi_col)
        if !isfinite(z_lo)
            z_lo = DEFAULT_Z_LO
        end
        if !isfinite(z_hi)
            z_hi = DEFAULT_Z_HI
        end

        if isnan(u) || u >= MISSING_VAL;  n_missing_ustar += 1; continue; end
        if isnan(h) || abs(h) >= MISSING_VAL; n_missing_hs += 1; continue; end
        if isnan(wl) || wl >= MISSING_VAL || isnan(wh) || wh >= MISSING_VAL
            n_missing_ws += 1; continue
        end
        if isnan(tl) || tl >= MISSING_VAL || isnan(th) || th >= MISSING_VAL
            n_missing_ws += 1; continue
        end

        # Basic QC
        if u < USTAR_MIN;                n_qc_fail += 1; continue; end
        if abs(h) < HS_ABS_MIN;          n_qc_fail += 1; continue; end
        if wh < wl;                      n_qc_fail += 1; continue; end  # non-monotonic profile

        T_avg = 0.5 * (tl + th)
        L = compute_L(u, h, T_avg)
        if isnan(L) || isinf(L);         n_qc_fail += 1; continue; end

        zeta = sqrt(z_lo * z_hi) / L

        # Stable: zeta > 0
        if zeta <= 0.0;    n_unstable += 1; continue; end
        if zeta > ZETA_MAX; n_qc_fail += 1; continue; end

        phi_m = compute_phi_m(wl, wh, u, z_lo, z_hi)
        if isnan(phi_m) || isinf(phi_m) || phi_m <= 0.0 || phi_m > PHI_MAX
            n_qc_fail += 1; continue
        end

        phi_h = compute_phi_h(tl, th, h, u, z_lo, z_hi)
        phi_q = (isfinite(ql) && isfinite(qh) && isfinite(hl)) ? compute_phi_q(ql, qh, hl, u, z_lo, z_hi) : NaN

        push!(kept_idx, i)
        push!(times,    isnan(t) ? NaN : t)
        push!(datetimes, jd_to_datetime(t))
        push!(zeta_out, zeta)
        push!(phi_m_out, phi_m)
        push!(phi_h_out, phi_h)
        push!(phi_q_out, phi_q)
        push!(l_out, L)
        push!(ustar_out, u)
        push!(hs_out, h)
        push!(hl_out, hl)
        push!(ws_lo_out, wl)
        push!(ws_hi_out, wh)
        push!(t_lo_out, tl)
        push!(t_hi_out, th)
        push!(q_lo_out, ql)
        push!(q_hi_out, qh)
        push!(z_lo_out, z_lo)
        push!(z_hi_out, z_hi)
        n_good += 1
    end

    @info "Preprocessing summary:"
    @info "  Total rows           : $n_total"
    @info "  Missing u*           : $n_missing_ustar"
    @info "  Missing hs           : $n_missing_hs"
    @info "  Missing wind/T       : $n_missing_ws"
    @info "  Unstable (zeta ≤ 0)  : $n_unstable"
    @info "  QC failures          : $n_qc_fail"
    @info "  Good stable rows     : $n_good"

    if n_good < 10
        @warn "Very few good rows ($n_good). Check data format."
    end

    out_df = DataFrame(
        time=times,
        datetime=datetimes,
        zeta=zeta_out,
        phi_obs=phi_m_out,
        phi_m=phi_m_out,
        phi_h=phi_h_out,
        phi_q=phi_q_out,
        L_obukhov=l_out,
        ustar=ustar_out,
        hs=hs_out,
        hl=hl_out,
        ws_lo=ws_lo_out,
        ws_hi=ws_hi_out,
        T_lo=t_lo_out,
        T_hi=t_hi_out,
        q_lo=q_lo_out,
        q_hi=q_hi_out,
        z_lo=z_lo_out,
        z_hi=z_hi_out,
    )

    # Preserve richer ASFG profile fields when present.
    attach_optional!(out_df, df, kept_idx, [
        "lat", "lon", "Press", "z1", "z2", "z3", "z4", "z5", "zoph",
        "ws1", "ws2", "ws3", "ws4", "ws5",
        "wd1", "wd2", "wd3", "wd4", "wd5",
        "T1", "T2", "T3", "T4", "T5",
        "q1", "q2", "q3", "q4", "q5",
        "rh1", "rh2", "rh3", "rh4", "rh5",
        "u_1", "u_2", "u_3", "u_4", "u_5",
        "hs1", "hs2", "hs3", "hs4", "hs5",
        "hl", "LWd", "Lwu", "SWd", "Swu",
    ])

    CSV.write(out_csv, out_df)
    @info "Written to $out_csv"
end

main()
