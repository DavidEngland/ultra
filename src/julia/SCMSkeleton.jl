module SCMSkeleton

using CSV
using DataFrames
using Dates
using LinearAlgebra

include(joinpath(@__DIR__, "MOSTProfiles.jl"))
using .MOSTProfiles

export ModelConfig,
	   Grid,
	   ColumnState,
	   SurfaceState,
	   SurfaceSlabParameters,
	   SurfaceSlabState,
	   TowerSite,
	   Forcing,
	   SimulationHistory,
	   SCMModel,
	   AbstractClosure,
	   ConstantDiffusivityClosure,
	   RiBasedClosure,
	   CurvatureRiClosure,
	   build_grid,
	   initial_state,
	   default_forcing,
	   diffusivities,
	   diagnose_richardson,
	   compute_tke_budget,
	   surface_flux_most,
	   forcing_from_row,
	   surface_state_from_row,
	   load_forcing_table,
	   load_sheba_forcing_table,
	   load_smear_forcing_table,
	   smear_api_to_forcing_table,
	   step!,
	   run_model

const GRAVITY = 9.81
const VON_KARMAN = 0.40

Base.@kwdef struct ModelConfig
	z_top::Float64 = 500.0
	nz::Int = 30
	dt::Float64 = 20.0
	t_end::Float64 = 6.0 * 3600.0
	stretch::Float64 = 3.0
	theta0::Float64 = 265.0
	dtheta_dz::Float64 = 0.01
	q0::Float64 = 0.001
	dq_dz::Float64 = 0.0
	u0::Float64 = 4.0
	v0::Float64 = 0.0
	use_implicit::Bool = false
	air_density::Float64 = 1.25
	cp_air::Float64 = 1004.0
	lv::Float64 = 2.5e6
	theta_ref::Float64 = 273.15
end

struct Grid
	z::Vector{Float64}
	dz::Vector{Float64}
	nz::Int
	jacobian::Vector{Float64}
end

mutable struct ColumnState
	theta::Vector{Float64}
	q::Vector{Float64}
	u::Vector{Float64}
	v::Vector{Float64}
end

mutable struct SurfaceState
	temperature::Float64
	specific_humidity::Float64
	sensible_flux::Float64
	latent_flux::Float64
	net_radiation::Float64
	ground_flux::Float64
	zeta::Float64
	friction_velocity::Float64
	heat_transfer_coeff::Float64
	moisture_transfer_coeff::Float64
end

Base.@kwdef struct SurfaceSlabParameters
	depth::Float64 = 0.1
	rho::Float64 = 1800.0
	cp::Float64 = 2000.0
	conductivity::Float64 = 0.3
	albedo::Float64 = 0.2
	emissivity::Float64 = 0.98
	z0m::Float64 = 0.05
	z0h::Float64 = 0.01
	displacement_height::Float64 = 0.0
	moisture_availability::Float64 = 1.0
	most_profile_tag::String = "BD_CLASSIC"
	most_profile_pars::Dict{Symbol, Any} = Dict{Symbol, Any}()
end

mutable struct SurfaceSlabState
	skin_temperature::Float64
	deep_temperature::Float64
	liquid_fraction::Float64
end

Base.@kwdef struct TowerSite
	z_t::Float64 = 2.0
	z_q::Float64 = 2.0
	z_u::Float64 = 10.0
	latitude::Float64 = 0.0
	longitude::Float64 = 0.0
	terrain::String = "unknown"
end

struct Forcing
	theta_tendency::Vector{Float64}
	q_tendency::Vector{Float64}
	u_tendency::Vector{Float64}
	v_tendency::Vector{Float64}
	sensible_flux::Float64
	latent_flux::Float64
	shortwave_down::Float64
	longwave_down::Float64
	air_temperature_ref::Float64
	specific_humidity_ref::Float64
	wind_speed_ref::Float64
	surface_pressure::Float64
	friction_velocity::Float64
	obukhov_length::Float64
	zeta_reference::Float64
	reference_height::Float64
	prescribed_surface_fluxes::Bool
end

mutable struct SimulationHistory
	time::Vector{Float64}
	surface_temperature::Vector{Float64}
	sensible_flux::Vector{Float64}
	latent_flux::Vector{Float64}
	surface_zeta::Vector{Float64}
	surface_friction_velocity::Vector{Float64}
	heat_transfer_coeff::Vector{Float64}
	moisture_transfer_coeff::Vector{Float64}
	max_km::Vector{Float64}
	max_kh::Vector{Float64}
	max_ri::Vector{Float64}
	max_shear_production::Vector{Float64}
	max_buoyant_destruction::Vector{Float64}
end

mutable struct SCMModel
	config::ModelConfig
	grid::Grid
	state::ColumnState
	surface::SurfaceState
	surface_params::SurfaceSlabParameters
	slab::SurfaceSlabState
	tower::TowerSite
	forcing::Forcing
	time::Float64
	step_count::Int
end

abstract type AbstractClosure end

struct ConstantDiffusivityClosure <: AbstractClosure
	km::Float64
	kh::Float64
end

struct RiBasedClosure <: AbstractClosure
	K0::Float64
	Ri_c::Float64
	Pr_t::Float64
end

function build_grid(config::ModelConfig)
	nz = config.nz
	eta = ((1:nz) .- 0.5) ./ nz
	eta_interfaces = (0:nz) ./ nz
	stretch = config.stretch
	if abs(stretch) < 1e-8
		z = config.z_top .* eta
		z_interfaces = config.z_top .* eta_interfaces
		jacobian = fill(config.z_top, nz)
	else
		scale = expm1(stretch)
		z = config.z_top .* expm1.(stretch .* eta) ./ scale
		z_interfaces = config.z_top .* expm1.(stretch .* eta_interfaces) ./ scale
		jacobian = config.z_top .* stretch .* exp.(stretch .* eta) ./ scale
	end
	dz = diff(z_interfaces)
	return Grid(z, dz, nz, jacobian)
end

function initial_state(config::ModelConfig, grid::Grid)
	theta = config.theta0 .+ config.dtheta_dz .* grid.z
	q = max.(config.q0 .+ config.dq_dz .* grid.z, 0.0)
	u = fill(config.u0, grid.nz)
	v = fill(config.v0, grid.nz)
	return ColumnState(theta, q, u, v)
end

function default_forcing(config::ModelConfig)
	nz = config.nz
	return Forcing(
		zeros(nz),
		zeros(nz),
		zeros(nz),
		zeros(nz),
		0.0,
		0.0,
		0.0,
		0.0,
		config.theta0,
		config.q0,
		hypot(config.u0, config.v0),
		101325.0,
		NaN,
		NaN,
		0.0,
		10.0,
		true,
	)
end

function _default_surface(config::ModelConfig)
	return SurfaceState(config.theta0, config.q0, 0.0, 0.0, 0.0, 0.0, NaN, NaN, NaN, NaN)
end

function _default_slab(config::ModelConfig)
	return SurfaceSlabState(config.theta0, config.theta0, 1.0)
end

function _empty_history()
	return SimulationHistory(
		Float64[],
		Float64[],
		Float64[],
		Float64[],
		Float64[],
		Float64[],
		Float64[],
		Float64[],
		Float64[],
		Float64[],
		Float64[],
		Float64[],
		Float64[],
	)
end

function _gradient(values::AbstractVector{<:Real}, z::AbstractVector{<:Real})
	n = length(values)
	grad = zeros(Float64, n)
	if n == 1
		return grad
	end
	grad[1] = (values[2] - values[1]) / (z[2] - z[1])
	for idx in 2:(n - 1)
		grad[idx] = (values[idx + 1] - values[idx - 1]) / (z[idx + 1] - z[idx - 1])
	end
	grad[n] = (values[n] - values[n - 1]) / (z[n] - z[n - 1])
	return grad
end

function diagnose_richardson(model::SCMModel)
	z = model.grid.z
	state = model.state
	dtheta_dz = _gradient(state.theta, z)
	du_dz = _gradient(state.u, z)
	dv_dz = _gradient(state.v, z)
	shear2 = du_dz .^ 2 .+ dv_dz .^ 2
	n2 = (GRAVITY / model.config.theta_ref) .* dtheta_dz
	ri = n2 ./ max.(shear2, 1e-8)
	return ri, shear2, n2
end

function diffusivities(closure::ConstantDiffusivityClosure, model::SCMModel)
	km = fill(closure.km, model.grid.nz)
	kh = fill(closure.kh, model.grid.nz)
	return km, kh
end

function diffusivities(closure::RiBasedClosure, model::SCMModel)
	ri, _, _ = diagnose_richardson(model)
	reduction = max.(0.0, 1 .- ri ./ closure.Ri_c) .^ 2
	km = closure.K0 .* reduction
	kh = km ./ closure.Pr_t
	return km, kh
end

include(joinpath(@__DIR__, "scm", "SurfaceMOST.jl"))
include(joinpath(@__DIR__, "scm", "ForcingIO.jl"))
include(joinpath(@__DIR__, "CurvatureRiClosure.jl"))

function _interface_conductance(k::AbstractVector{<:Real}, grid::Grid)
	nz = grid.nz
	conductance = zeros(Float64, max(nz - 1, 0))
	for idx in 1:(nz - 1)
		kf = 0.5 * (k[idx] + k[idx + 1])
		conductance[idx] = kf / (grid.z[idx + 1] - grid.z[idx])
	end
	return conductance
end

function _explicit_diffusion_tendency(field::AbstractVector{<:Real}, k::AbstractVector{<:Real}, grid::Grid)
	nz = grid.nz
	tendency = zeros(Float64, nz)
	conductance = _interface_conductance(k, grid)
	flux = zeros(Float64, nz + 1)
	for idx in 1:(nz - 1)
		flux[idx + 1] = -conductance[idx] * (field[idx + 1] - field[idx])
	end
	for idx in 1:nz
		tendency[idx] = -(flux[idx + 1] - flux[idx]) / grid.dz[idx]
	end
	return tendency
end

function _implicit_diffusion_step(field::AbstractVector{<:Real}, k::AbstractVector{<:Real}, grid::Grid, dt::Real)
	nz = grid.nz
	nz == 1 && return [field[1]]
	conductance = _interface_conductance(k, grid)
	lower = zeros(Float64, nz - 1)
	diag = ones(Float64, nz)
	upper = zeros(Float64, nz - 1)
	for idx in 1:nz
		west = idx > 1 ? dt * conductance[idx - 1] / grid.dz[idx] : 0.0
		east = idx < nz ? dt * conductance[idx] / grid.dz[idx] : 0.0
		diag[idx] += west + east
		if idx > 1
			lower[idx - 1] = -west
		end
		if idx < nz
			upper[idx] = -east
		end
	end
	system = Tridiagonal(lower, diag, upper)
	return system \ collect(field)
end

function _surface_tendencies(model::SCMModel)
	nz = model.grid.nz
	theta_source = zeros(Float64, nz)
	q_source = zeros(Float64, nz)
	forcing = model.forcing
	surface = model.surface
	if forcing.prescribed_surface_fluxes
		surface.sensible_flux = forcing.sensible_flux
		surface.latent_flux = forcing.latent_flux
		surface.friction_velocity = forcing.friction_velocity
		surface.zeta = forcing.zeta_reference
		surface.heat_transfer_coeff = NaN
		surface.moisture_transfer_coeff = NaN
	else
		diag = surface_flux_most(model)
		surface.sensible_flux = diag.sensible_flux
		surface.latent_flux = diag.latent_flux
		surface.friction_velocity = diag.friction_velocity
		surface.zeta = diag.zeta
		surface.heat_transfer_coeff = diag.heat_transfer_coeff
		surface.moisture_transfer_coeff = diag.moisture_transfer_coeff
	end
	surface.net_radiation = forcing.shortwave_down + forcing.longwave_down
	surface.ground_flux = surface.net_radiation - surface.sensible_flux - surface.latent_flux
	theta_source[1] = surface.sensible_flux / (model.config.air_density * model.config.cp_air * model.grid.dz[1])
	q_source[1] = surface.latent_flux / (model.config.air_density * model.config.lv * model.grid.dz[1])
	return theta_source, q_source
end

function compute_tke_budget(model::SCMModel, km::AbstractVector{<:Real}, kh::AbstractVector{<:Real})
	_, shear2, n2 = diagnose_richardson(model)
	shear_production = km .* shear2
	buoyant_destruction = (GRAVITY / model.config.theta_ref) .* kh .* max.(n2, 0.0)
	return shear_production, buoyant_destruction
end

function _record_history!(history::SimulationHistory, model::SCMModel, km::AbstractVector{<:Real}, kh::AbstractVector{<:Real})
	ri, _, _ = diagnose_richardson(model)
	shear_production, buoyant_destruction = compute_tke_budget(model, km, kh)
	push!(history.time, model.time)
	push!(history.surface_temperature, model.surface.temperature)
	push!(history.sensible_flux, model.surface.sensible_flux)
	push!(history.latent_flux, model.surface.latent_flux)
	push!(history.surface_zeta, model.surface.zeta)
	push!(history.surface_friction_velocity, model.surface.friction_velocity)
	push!(history.heat_transfer_coeff, model.surface.heat_transfer_coeff)
	push!(history.moisture_transfer_coeff, model.surface.moisture_transfer_coeff)
	push!(history.max_km, maximum(km))
	push!(history.max_kh, maximum(kh))
	push!(history.max_ri, maximum(ri))
	push!(history.max_shear_production, maximum(shear_production))
	push!(history.max_buoyant_destruction, maximum(buoyant_destruction))
	return history
end

function step!(model::SCMModel, closure::AbstractClosure)
	config = model.config
	state = model.state
	forcing = model.forcing
	model.surface.temperature = model.slab.skin_temperature
	km, kh = diffusivities(closure, model)
	theta_source, q_source = _surface_tendencies(model)
	theta_rhs = state.theta .+ config.dt .* (forcing.theta_tendency .+ theta_source)
	q_rhs = state.q .+ config.dt .* (forcing.q_tendency .+ q_source)
	u_rhs = state.u .+ config.dt .* forcing.u_tendency
	v_rhs = state.v .+ config.dt .* forcing.v_tendency

	if config.use_implicit
		state.theta .= _implicit_diffusion_step(theta_rhs, kh, model.grid, config.dt)
		state.q .= _implicit_diffusion_step(q_rhs, kh, model.grid, config.dt)
		state.u .= _implicit_diffusion_step(u_rhs, km, model.grid, config.dt)
		state.v .= _implicit_diffusion_step(v_rhs, km, model.grid, config.dt)
	else
		state.theta .= theta_rhs .+ config.dt .* _explicit_diffusion_tendency(theta_rhs, kh, model.grid)
		state.q .= q_rhs .+ config.dt .* _explicit_diffusion_tendency(q_rhs, kh, model.grid)
		state.u .= u_rhs .+ config.dt .* _explicit_diffusion_tendency(u_rhs, km, model.grid)
		state.v .= v_rhs .+ config.dt .* _explicit_diffusion_tendency(v_rhs, km, model.grid)
	end

	model.time += config.dt
	model.step_count += 1
	return km, kh
end

function run_model(
	config::ModelConfig;
	closure::AbstractClosure = ConstantDiffusivityClosure(0.6, 0.4),
	forcing::Forcing = default_forcing(config),
	surface::SurfaceState = _default_surface(config),
	surface_params::SurfaceSlabParameters = SurfaceSlabParameters(),
	slab::SurfaceSlabState = _default_slab(config),
	tower::TowerSite = TowerSite(),
	log_every::Int = 1,
)
	grid = build_grid(config)
	state = initial_state(config, grid)
	model = SCMModel(config, grid, state, surface, surface_params, slab, tower, forcing, 0.0, 0)
	history = _empty_history()
	km, kh = diffusivities(closure, model)
	_record_history!(history, model, km, kh)
	nsteps = max(1, ceil(Int, config.t_end / config.dt))
	stride = max(log_every, 1)
	for step_idx in 1:nsteps
		km, kh = step!(model, closure)
		if step_idx % stride == 0 || step_idx == nsteps
			_record_history!(history, model, km, kh)
		end
	end
	return model, history
end

end
