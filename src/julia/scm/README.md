# SCM Area

This directory collects the current single-column model implementation surface in one place.

## Files

- `../SCMSkeleton.jl`: public SCM entry point and timestepper
- `SurfaceMOST.jl`: first regime-aware MOST surface-flux routine used when `Forcing.prescribed_surface_fluxes == false`
- `ForcingIO.jl`: common forcing normalization for SHEBA and SMEAR CSV inputs plus a SmartSMEAR API adapter that delegates to the existing preprocess script
- `../CurvatureRiClosure.jl`: curvature-aware Richardson closure included by `SCMSkeleton.jl`
- `../MOSTProfiles.jl`: MOST profile families used by the surface layer
- `../SCMSkeleton.md`: design note for model structure and numerics
- `../SCMSkeleton_vs_SCAFFOLDING.md`: roadmap note for stronger surface and substrate physics
- `../toy_sc_m.jl`: legacy monolithic reference implementation

## Current Workflow

1. Load a normalized forcing table with `load_sheba_forcing_table`, `load_smear_forcing_table`, or `load_forcing_table`.
2. Convert one row into a `Forcing` with `forcing_from_row`.
3. Convert the same row into a `SurfaceState` with `surface_state_from_row`.
4. Pass `surface_params=SurfaceSlabParameters(...)` when the run should select a non-default MOST family such as `GRACHEV`; the default remains `BD_CLASSIC`.
5. Run `run_model` with `prescribed_surface_fluxes=true` for direct observed fluxes or `false` for MOST-resolved surface exchange.
6. Use `SimulationHistory` fields to inspect surface fluxes, `u_*`, `zeta`, transfer coefficients, and closure diagnostics.

## Input Support

- SHEBA CSV: direct support for preprocessed files such as `runs/sheba/input/sheba_input_rich.csv`
- SMEAR CSV: direct support for normalized preprocess outputs and existing DCT input CSVs with `MO_length`, `u_star`, and tower temperatures
- SmartSMEAR API: `smear_api_to_forcing_table(...)` shells out to `preprocess_tower_to_ultra_input.jl`, writes a temporary CSV, then loads the normalized forcing table

## Surface And Strategy Notes

- `SurfaceMOST.jl` resolves its profile family through `SurfaceSlabParameters`, so SHEBA or polar runs can opt into `GRACHEV` without changing the forcing schema.
- `MOSTProfiles.jl` should stay focused on profile families and Ri-zeta utilities. Future spectral or ML calibration should live in a separate layer.
- Practical SCM rollout stays SHEBA first, SMEAR-I or Varrio second, SMEAR-II or Hyytiala third.
- Tracer priority is momentum, heat, humidity, CO2, then additional tracers.

## Validation

Use `test/scm_smoke.jl` for a narrow compile and run check of the SCM surface. The smoke test covers both the default `BD_CLASSIC` path and an explicit `GRACHEV` selection.
