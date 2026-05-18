include(joinpath(@__DIR__, "..", "src", "julia", "SCMSkeleton.jl"))
using .SCMSkeleton

function first_valid_row(df)
    for row in eachrow(df)
        if isfinite(row.reference_height) && (isfinite(row.zeta_reference) || isfinite(row.obukhov_length) || isfinite(row.friction_velocity))
            return row
        end
    end
    error("No valid forcing row found")
end

sheba = load_sheba_forcing_table(joinpath(@__DIR__, "..", "runs", "sheba", "input", "sheba_input_rich.csv"))
@assert size(sheba, 1) > 0
sheba_row = first_valid_row(sheba)

smear = load_smear_forcing_table(joinpath(@__DIR__, "..", "runs", "hyy_station2_ri_curvature_tier1", "input", "hyy_station2_2020_02_dct_input.csv"))
@assert size(smear, 1) > 0
smear_row = first_valid_row(smear)
smear_forcing = forcing_from_row(smear_row, 12; prescribed_surface_fluxes=true)
@assert isfinite(smear_forcing.reference_height)

config = ModelConfig(nz=12, dt=10.0, t_end=60.0, use_implicit=true)
forcing = forcing_from_row(sheba_row, config.nz; prescribed_surface_fluxes=false)
surface = surface_state_from_row(sheba_row)
model, history = run_model(config; forcing=forcing, surface=surface, closure=CurvatureRiClosure(0.8), log_every=1)

@assert !isempty(history.time)
@assert all(isfinite, model.state.theta)
@assert any(isfinite, history.surface_friction_velocity)
@assert any(isfinite, history.surface_zeta)
println("scm_smoke_ok")
