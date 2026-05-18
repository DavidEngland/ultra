@inline function _to_float(value)
    if ismissing(value)
        return NaN
    elseif value isa Number
        return Float64(value)
    else
        parsed = tryparse(Float64, strip(String(value)))
        return parsed === nothing ? NaN : parsed
    end
end

@inline function _to_kelvin(value::Real)
    numeric = _to_float(value)
    return (!isfinite(numeric) || numeric > 200.0) ? numeric : numeric + 273.15
end

@inline function _to_specific_humidity(value::Real)
    numeric = _to_float(value)
    if !isfinite(numeric)
        return NaN
    end
    return numeric > 1.0 ? numeric * 1.0e-3 : numeric
end

function _colmap(df::DataFrame)
    return Dict(Symbol(lowercase(String(name))) => name for name in names(df))
end

function _row_lookup(row::DataFrameRow, colmap::AbstractDict{Symbol, <:Any}, aliases; default=missing)
    for alias in aliases
        key = Symbol(lowercase(String(alias)))
        if haskey(colmap, key)
            return row[colmap[key]]
        end
    end
    return default
end

function _dataset_kind(df::DataFrame)
    colmap = _colmap(df)
    if any(haskey(colmap, key) for key in (:phi_q, :t_lo, :ws_lo, :q_lo, :z_lo))
        return :sheba
    end
    return :smear
end

function _normalize_row(row::DataFrameRow, colmap::AbstractDict{Symbol, <:Any}, dataset::Symbol, source_path::AbstractString, default_reference_height::Float64)
    datetime_value = _row_lookup(row, colmap, (:datetime, :time, :timestamp); default=missing)

    reference_height = _to_float(_row_lookup(row, colmap, (:reference_height, :z_lo, :z1, :z_m); default=default_reference_height))
    if !isfinite(reference_height) || reference_height <= 0
        reference_height = default_reference_height
    end

    obukhov_length = _to_float(_row_lookup(row, colmap, (:obukhov_length, :l_obukhov, :l, :var_eddy_mo_length, :hyy_eddy233_mo_length, :hyy_eddymast_mo_length_270); default=NaN))
    zeta_reference = _to_float(_row_lookup(row, colmap, (:zeta_reference, :zeta); default=NaN))
    if !isfinite(zeta_reference) && isfinite(obukhov_length) && obukhov_length != 0.0
        zeta_reference = reference_height / obukhov_length
    end

    friction_velocity = _to_float(_row_lookup(row, colmap, (:friction_velocity, :ustar, :u_star, :var_eddy_u_star, :hyy_eddy233_u_star, :hyy_eddy233_u_star_460, :hyy_eddymast_u_star_270); default=NaN))
    sensible_flux = _to_float(_row_lookup(row, colmap, (:sensible_flux, :hs, :var_eddy_h, :hyy_eddy233_h); default=0.0))
    latent_flux = _to_float(_row_lookup(row, colmap, (:latent_flux, :hl, :var_eddy_le, :hyy_eddy233_le); default=0.0))

    air_temperature_ref = _to_kelvin(_row_lookup(row, colmap, (:air_temperature_ref, :t_lo, :t1, :var_meta_tdry0, :var_meta_tdry1, :hyy_meta_t42, :hyy_meta_t84); default=NaN))
    if !isfinite(air_temperature_ref)
        air_temperature_ref = 273.15
    end

    surface_temperature = _to_kelvin(_row_lookup(row, colmap, (:surface_temperature, :t_lo, :t1, :var_meta_tdry0, :hyy_meta_t42); default=air_temperature_ref))
    specific_humidity_ref = _to_specific_humidity(_row_lookup(row, colmap, (:specific_humidity_ref, :q_lo, :q1, :var_meta_h2o0, :var_meta_h2o_0); default=0.001))
    if !isfinite(specific_humidity_ref)
        specific_humidity_ref = 0.001
    end
    surface_specific_humidity = _to_specific_humidity(_row_lookup(row, colmap, (:surface_specific_humidity, :q_lo, :q1, :var_meta_h2o0, :var_meta_h2o_0); default=specific_humidity_ref))

    wind_speed_ref = _to_float(_row_lookup(row, colmap, (:wind_speed_ref, :ws_lo, :ws1, :var_eddy_u, :hyy_eddy233_u); default=NaN))
    if !isfinite(wind_speed_ref) || wind_speed_ref <= 0
        wind_speed_ref = isfinite(friction_velocity) && friction_velocity > 0 ? max(10.0 * friction_velocity, 1.0) : 5.0
    end

    surface_pressure = _to_float(_row_lookup(row, colmap, (:surface_pressure, :press); default=101325.0))
    if !isfinite(surface_pressure)
        surface_pressure = 101325.0
    end

    return (
        dataset = String(dataset),
        source_path = source_path,
        datetime = datetime_value,
        air_temperature_ref = air_temperature_ref,
        specific_humidity_ref = specific_humidity_ref,
        wind_speed_ref = wind_speed_ref,
        sensible_flux = isfinite(sensible_flux) ? sensible_flux : 0.0,
        latent_flux = isfinite(latent_flux) ? latent_flux : 0.0,
        surface_pressure = surface_pressure,
        friction_velocity = friction_velocity,
        obukhov_length = obukhov_length,
        zeta_reference = zeta_reference,
        reference_height = reference_height,
        surface_temperature = isfinite(surface_temperature) ? surface_temperature : air_temperature_ref,
        surface_specific_humidity = isfinite(surface_specific_humidity) ? surface_specific_humidity : specific_humidity_ref,
    )
end

function _normalize_table(df::DataFrame, dataset::Symbol, source_path::AbstractString, default_reference_height::Float64)
    colmap = _colmap(df)
    rows = NamedTuple[]
    for (row_index, row) in enumerate(eachrow(df))
        normalized = _normalize_row(row, colmap, dataset, source_path, default_reference_height)
        if isfinite(normalized.friction_velocity) || isfinite(normalized.obukhov_length) || isfinite(normalized.zeta_reference)
            push!(rows, merge((row_index = row_index,), normalized))
        end
    end
    return DataFrame(rows)
end

function load_forcing_table(path::AbstractString; dataset::Symbol=:auto, reference_height::Float64=10.0)
    df = CSV.read(path, DataFrame; normalizenames=true)
    chosen = dataset == :auto ? _dataset_kind(df) : dataset
    return _normalize_table(df, chosen, path, reference_height)
end

function load_sheba_forcing_table(path::AbstractString; reference_height::Float64=10.0)
    return load_forcing_table(path; dataset=:sheba, reference_height=reference_height)
end

function load_smear_forcing_table(path::AbstractString; reference_height::Float64=10.0)
    return load_forcing_table(path; dataset=:smear, reference_height=reference_height)
end

function forcing_from_row(row, nz::Integer; prescribed_surface_fluxes::Bool=true)
    return Forcing(
        zeros(nz),
        zeros(nz),
        zeros(nz),
        zeros(nz),
        row.sensible_flux,
        row.latent_flux,
        0.0,
        0.0,
        row.air_temperature_ref,
        row.specific_humidity_ref,
        row.wind_speed_ref,
        row.surface_pressure,
        row.friction_velocity,
        row.obukhov_length,
        row.zeta_reference,
        row.reference_height,
        prescribed_surface_fluxes,
    )
end

function surface_state_from_row(row)
    return SurfaceState(
        row.surface_temperature,
        row.surface_specific_humidity,
        0.0,
        0.0,
        0.0,
        0.0,
        NaN,
        NaN,
        NaN,
        NaN,
    )
end

function smear_api_to_forcing_table(station_label::AbstractString; out_csv::AbstractString=tempname() * ".csv", z_m::Float64=10.0, d_m::Float64=0.0, from_iso::AbstractString, to_iso::AbstractString, profile_mode::AbstractString="raw", preprocess_script::AbstractString=joinpath(@__DIR__, "..", "preprocess_tower_to_ultra_input.jl"), extra_flags::Vector{String}=String[])
    mkpath(dirname(out_csv))
    cmd = `$(Base.julia_cmd()) --project=. $(preprocess_script) $(station_label) $(out_csv) $(z_m) $(d_m) --mode=api-smear --profile-mode=$(profile_mode) --from=$(from_iso) --to=$(to_iso) $(extra_flags...)`
    run(cmd)
    return load_smear_forcing_table(out_csv; reference_height=max(z_m - d_m, 1.0))
end
