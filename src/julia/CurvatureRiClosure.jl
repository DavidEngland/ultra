"""
    CurvatureRiClosure(K0, Ri_c, Pr_t, beta)

Richardson-number closure with a curvature-derived expansion of the effective
critical Richardson number in statically stable layers.
"""
struct CurvatureRiClosure <: AbstractClosure
    K0::Float64
    Ri_c::Float64
    Pr_t::Float64
    beta::Float64
end

CurvatureRiClosure(K0::Float64) = CurvatureRiClosure(K0, 0.25, 1.0, 0.5)

function diffusivities(closure::CurvatureRiClosure, model::SCMModel)
    grid = model.grid
    state = model.state
    nz = grid.nz
    theta_ref = max(sum(state.theta) / max(nz, 1), 200.0)

    km = fill(1.0e-4, nz)
    kh = fill(1.0e-4, nz)
    nz < 3 && return km, kh

    for k in 2:(nz - 1)
        dz_span = grid.z[k + 1] - grid.z[k - 1]
        dtheta = state.theta[k + 1] - state.theta[k - 1]
        du = state.u[k + 1] - state.u[k - 1]
        dv = state.v[k + 1] - state.v[k - 1]

        n2 = (GRAVITY / theta_ref) * dtheta / dz_span
        s2 = (du^2 + dv^2) / max(dz_span^2, 1.0e-8)
        rig = s2 > 1.0e-9 ? n2 / s2 : 1.0e6

        dz_up = grid.z[k + 1] - grid.z[k]
        dz_dn = grid.z[k] - grid.z[k - 1]
        d2theta = ((state.theta[k + 1] - state.theta[k]) / dz_up -
                   (state.theta[k] - state.theta[k - 1]) / dz_dn) / max(grid.dz[k], 1.0e-6)

        slope_scale = abs(dtheta / dz_span) / max(0.5 * (dz_up + dz_dn), 1.0e-6)
        curvature_metric = n2 > 0 ? max(d2theta / max(slope_scale, 1.0e-6), 0.0) : 0.0
        fc = clamp(1.0 + closure.beta * curvature_metric, 1.0, 2.0)
        ri_eff = closure.Ri_c * fc

        if rig < ri_eff
            f_stability = (1.0 - rig / ri_eff)^2
            km[k] = max(1.0e-4, closure.K0 * f_stability)
            kh[k] = max(1.0e-4, km[k] / closure.Pr_t)
        end
    end

    return km, kh
end
