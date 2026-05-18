@inline _positive_or(value::Real, fallback::Real) = (isfinite(value) && value > 0) ? Float64(value) : Float64(fallback)
@inline _finite_or(value::Real, fallback::Real) = isfinite(value) ? Float64(value) : Float64(fallback)

function _surface_log_term(z_ref::Real, z0::Real, displacement_height::Real)
    z_eff = max(z_ref - displacement_height, z0 + 1.0e-6)
    return log(z_eff / max(z0, 1.0e-6))
end

function _scaled_zeta(forcing::Forcing, height::Real)
    if isfinite(forcing.obukhov_length) && forcing.obukhov_length != 0.0
        return height / forcing.obukhov_length
    end
    if isfinite(forcing.zeta_reference)
        refh = _positive_or(forcing.reference_height, height)
        return forcing.zeta_reference * height / refh
    end
    return 0.0
end

function surface_flux_most(model::SCMModel)
    forcing = model.forcing
    surface = model.surface
    params = model.surface_params
    tower = model.tower
    phi_m_fn, phi_h_fn = make_profile(params.most_profile_tag, params.most_profile_pars)

    z_u = _positive_or(tower.z_u, model.grid.z[1])
    z_t = _positive_or(tower.z_t, model.grid.z[1])
    z_q = _positive_or(tower.z_q, model.grid.z[1])
    zeta_u = _scaled_zeta(forcing, z_u)
    zeta_t = _scaled_zeta(forcing, z_t)
    zeta_q = _scaled_zeta(forcing, z_q)

    phi_m = _positive_or(phi_m_fn(zeta_u), 1.0)
    phi_h_t = _positive_or(phi_h_fn(zeta_t), 1.0)
    phi_h_q = _positive_or(phi_h_fn(zeta_q), 1.0)

    logm = _surface_log_term(z_u, params.z0m, params.displacement_height)
    logh = _surface_log_term(z_t, params.z0h, params.displacement_height)
    logq = _surface_log_term(z_q, params.z0h, params.displacement_height)

    wind_ref = _positive_or(forcing.wind_speed_ref, max(10.0 * _positive_or(forcing.friction_velocity, 0.1), 1.0))
    friction_velocity = isfinite(forcing.friction_velocity) && forcing.friction_velocity > 0 ?
        forcing.friction_velocity : VON_KARMAN * wind_ref / max(logm * phi_m, 1.0e-6)

    temp_ref = _finite_or(forcing.air_temperature_ref, model.config.theta0)
    temp_surface = _finite_or(surface.temperature, temp_ref)
    q_ref = max(_finite_or(forcing.specific_humidity_ref, model.config.q0), 0.0)
    q_surface = max(_finite_or(surface.specific_humidity, q_ref), 0.0)

    theta_star = VON_KARMAN * (temp_ref - temp_surface) / max(logh * phi_h_t, 1.0e-6)
    q_star = VON_KARMAN * (q_ref - q_surface) / max(logq * phi_h_q, 1.0e-6)

    heat_transfer_coeff = VON_KARMAN^2 / max((logm * phi_m) * (logh * phi_h_t), 1.0e-6)
    moisture_transfer_coeff = VON_KARMAN^2 / max((logm * phi_m) * (logq * phi_h_q), 1.0e-6)

    sensible_flux = -model.config.air_density * model.config.cp_air * friction_velocity * theta_star
    latent_flux = -model.config.air_density * model.config.lv * friction_velocity * q_star * params.moisture_availability

    return (
        sensible_flux = sensible_flux,
        latent_flux = latent_flux,
        friction_velocity = friction_velocity,
        zeta = _scaled_zeta(forcing, _positive_or(forcing.reference_height, z_t)),
        heat_transfer_coeff = heat_transfer_coeff,
        moisture_transfer_coeff = moisture_transfer_coeff,
    )
end
