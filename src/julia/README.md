# Julia Models

This folder contains lightweight Julia prototypes for atmospheric boundary-layer work.

## Files

- [SCMSkeleton.jl](SCMSkeleton.jl): clean 1D single-column model scaffold for prototyping closures and forcings.
- [scm/README.md](scm/README.md): SCM index for forcing adapters, MOST surface coupling, validation, and related files.
- [toy_sc_m.jl](toy_sc_m.jl): earlier toy Arctic column model with more embedded physics in a single script.
- [MOSTProfiles.jl](MOSTProfiles.jl): Monin-Obukhov similarity profile families and Ri-zeta correction utilities.

## Recommended Starting Point

If the goal is to build a reusable single-column model, start with [SCMSkeleton.jl](SCMSkeleton.jl) and [scm/README.md](scm/README.md).

Why:

- It separates grid, state, forcing, closure, timestepper, and diagnostics.
- It is easier to wrap in Pluto or another online interface.
- It is easier to replace placeholder physics with research-grade parameterizations.

Use [toy_sc_m.jl](toy_sc_m.jl) as a physics reference, not as the main architectural template.

## Conceptual Workflow

The skeleton is organized around the standard SCM loop:

1. Build a vertical grid.
2. Initialize prognostic state variables.
3. Define a forcing function for large-scale tendencies and either prescribed or MOST-resolved surface fluxes.
4. Define a turbulence closure that returns momentum and scalar diffusivities.
5. Advance the model in time.
6. Record a small set of diagnostics.

## Intended Audience

The main audience is numerical modelers who want to test:

- stability-dependent vertical mixing,
- curvature-aware corrections,
- idealized stable boundary-layer scenarios,
- simple teaching demonstrations before moving to a full SCM or LES framework.

## Current Limitations

The skeleton is intentionally incomplete. It currently uses:

- explicit or implicit vertical diffusion depending on configuration,
- baseline constant-diffusivity and Richardson-dependent closures,
- prescribed surface fluxes or a selectable MOST surface profile,
- a very simple boundary-layer-depth proxy.

It does not yet include:

- radiation,
- Coriolis forcing,
- prognostic TKE,
- rigorous moisture thermodynamics,
- NetCDF output.

`MOSTProfiles.jl` should stay focused on the baseline similarity families and correction utilities. If spectral, Gegenbauer, or ML calibration is added later, it should sit in a separate layer that augments or compares against those baseline profiles.

## Suggested Next Step

Use [../docs/SCM_Workflows.md](../docs/SCM_Workflows.md) for the current CSV and API-backed SCM workflow.

Implement a new closure by adding a subtype of `AbstractClosure` in [SCMSkeleton.jl](SCMSkeleton.jl) and defining
`diffusivities(closure, model)`.

Then connect the module to a Pluto notebook for interactive experiments.