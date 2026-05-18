# SCM Workflows

This note collects the current single-column model workflow in one place so contributors do not need to reconstruct the implementation from scattered scripts.

## Canonical SCM Files

- `src/julia/SCMSkeleton.jl`: public SCM module, grid, state, timestepper, and diagnostics
- `src/julia/scm/SurfaceMOST.jl`: first regime-aware MOST surface coupling
- `src/julia/scm/ForcingIO.jl`: common CSV and API-facing forcing adapters
- `src/julia/CurvatureRiClosure.jl`: curvature-aware Richardson closure
- `src/julia/MOSTProfiles.jl`: MOST profile families and Ri or zeta utilities
- `src/julia/SCMSkeleton.md`: design note for the model architecture and numerics
- `src/julia/SCMSkeleton_vs_SCAFFOLDING.md`: roadmap note for stronger-physics SCM work
- `src/julia/toy_sc_m.jl`: earlier monolithic reference model
- `test/scm_smoke.jl`: narrow validation script for the current SCM slice

## Supported Data Paths

### SHEBA CSV

Use preprocessed SHEBA products such as `runs/sheba/input/sheba_input_rich.csv`.

Example Julia pattern:

```julia
include("src/julia/SCMSkeleton.jl")
using .SCMSkeleton

forcing_table = load_sheba_forcing_table("runs/sheba/input/sheba_input_rich.csv")
row = forcing_table[1, :]
config = ModelConfig(nz=24, dt=20.0, t_end=600.0, use_implicit=true)
forcing = forcing_from_row(row, config.nz; prescribed_surface_fluxes=false)
surface = surface_state_from_row(row)
model, history = run_model(config; forcing=forcing, surface=surface, closure=CurvatureRiClosure(0.8))
```

### SMEAR CSV

Use either:

- normalized preprocess output from `src/julia/preprocess_tower_to_ultra_input.jl`
- existing SMEAR or HYY DCT input CSVs that already carry `MO_length`, `u_star`, and tower temperatures

Example:

```julia
forcing_table = load_smear_forcing_table("runs/hyy_station2_ri_curvature_tier1/input/hyy_station2_2020_02_dct_input.csv")
```

### SmartSMEAR API

The SCM layer does not duplicate the API-fetch logic. Instead it delegates to the validated tower preprocess script and then loads the resulting normalized table.

Example:

```julia
forcing_table = smear_api_to_forcing_table(
    "HYY";
    from_iso="2024-01-01T00:00:00",
    to_iso="2024-01-02T00:00:00",
    z_m=10.0,
    d_m=0.0,
    profile_mode="raw",
)
```

That design keeps the SCM forcing path aligned with the rest of the SMEAR preprocessing workflow instead of creating a second API client to maintain.

## Surface Coupling Modes

### Prescribed Flux Mode

Set `prescribed_surface_fluxes=true` when the forcing row should inject observed sensible and latent heat fluxes directly into the column.

### MOST Surface Mode

Set `prescribed_surface_fluxes=false` to use `surface_flux_most(model)`. The current MOST routine:

- uses `MOSTProfiles.jl` with a `BD_CLASSIC` profile family
- consumes `u_*`, `L` or `zeta`, reference wind, reference temperature, reference humidity, roughness lengths, and tower heights
- returns sensible flux, latent flux, `u_*`, `zeta`, and transfer coefficients for history tracking

This is the first regime-aware surface layer. It is intentionally minimal and should be treated as the current insertion point for stronger surface physics, not the final formulation.

## Calibration And Validation Notes

The current SCM surface is designed to work with:

- CSV-backed validation and replay runs
- API-backed SMEAR fetches routed through the existing preprocess script
- future calibration workflows where a forcing table can be regenerated externally and replayed through the same SCM driver

That split is deliberate. The SCM should consume normalized forcing products, not own every upstream fetch or preprocessing detail.

## Immediate Gaps

- SHEBA preprocessing still filters unstable rows, which limits unstable-surface validation cases
- large-scale advection tendencies are currently zero-filled in `forcing_from_row`
- the MOST surface routine is a first stable path, not yet an iterative Obukhov solver
- lower-boundary substrate physics in the design notes are not yet implemented in the module
