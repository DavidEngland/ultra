I’m continuing from the SCM anchor in src/julia/SCMSkeleton.jl: first I’ll verify the current file state and the closure file, then make the smallest SCM-area expansion that adds normalized forcing I/O and a first MOST surface path.

Read [](file:///Users/davidengland/Documents/GitHub/ultra/src/julia/SCMSkeleton.jl)

Read [](file:///Users/davidengland/Documents/GitHub/ultra/test)

Read [](file:///Users/davidengland/Documents/GitHub/ultra/src/julia/CurvatureRiClosure.jl#1-1), lines 1 to 220

I’ve isolated the first concrete slice: normalize SHEBA and SMEAR inputs into one forcing schema, clean the curvature closure so it can be included safely, and let the SCM switch between prescribed fluxes and a first MOST-based surface routine. I’m editing that slice now, plus the SCM index docs and a smoke test so the new path is documented and executable together.

Generating patch (461 lines) in [](file:///Users/davidengland/Documents/GitHub/ultra/src/julia/SCMSkeleton.jl), [](file:///Users/davidengland/Documents/GitHub/ultra/src/julia/SCMSkeleton.jl)

The first patch failed on the file-replacement format, not on the code itself. I’m retrying with a straight update patch and then I’ll validate immediately before widening to docs and tests.

Generating patch (861 lines) in [](file:///Users/davidengland/Documents/GitHub/ultra/src/julia/SCMSkeleton.jl)


```

```
The core file now expects the new SCM subfiles, so the immediate check is whether the module even loads with those includes unresolved. I’m running that narrow compile check now; if it fails, I’ll repair that same slice before adding the rest.

Ran terminal command:  julia --project=. -e 'include("src/julia/SCMSkeleton.jl")'

The missing-include failure is expected and local. I’m creating the two SCM support files and cleaning the curvature closure now, then I’ll rerun the same load check before touching docs or tests.

Created [](file:///Users/davidengland/Documents/GitHub/ultra/src/julia/scm/SurfaceMOST.jl)

Created [](file:///Users/davidengland/Documents/GitHub/ultra/src/julia/scm/ForcingIO.jl)

Generating patch (276 lines) in [](file:///Users/davidengland/Documents/GitHub/ultra/src/julia/CurvatureRiClosure.jl)


```

```
The new files are in place and the closure source is clean. I’m rerunning the same `include` check now; that will tell us whether the SCM slice compiles before I add docs and the smoke test.

Ran terminal command:  julia --project=. -e 'include("src/julia/SCMSkeleton.jl"); using .SCMSkeleton; println("scm_load_ok")'

The compile failure is still local to the curvature file. I’m reading that file tail and removing the leftover non-code marker, then I’ll rerun the same load check again.

Read [](file:///Users/davidengland/Documents/GitHub/ultra/src/julia/CurvatureRiClosure.jl)

Generating patch (28 lines) in [](file:///Users/davidengland/Documents/GitHub/ultra/src/julia/CurvatureRiClosure.jl)


```

```


Ran terminal command:  julia --project=. -e 'include("src/julia/SCMSkeleton.jl"); using .SCMSkeleton; println("scm_load_ok")'

The SCM core now loads. I’m adding the user-facing layer around it next: the SCM index docs, the workflow doc, a smoke test under `test/`, and brief README pointers so the new entry points are discoverable.

Created [](file:///Users/davidengland/Documents/GitHub/ultra/src/julia/scm/README.md)

Created [](file:///Users/davidengland/Documents/GitHub/ultra/docs/SCM_Workflows.md)

Created [](file:///Users/davidengland/Documents/GitHub/ultra/test/scm_smoke.jl)

Read [](file:///Users/davidengland/Documents/GitHub/ultra/README.md)

Read [](file:///Users/davidengland/Documents/GitHub/ultra/src/julia/README.md)

The SCM docs and smoke test are in place. I’m patching the two existing READMEs now so contributors can find the new SCM entry points without already knowing the file layout.

Generating patch (50 lines) in [](file:///Users/davidengland/Documents/GitHub/ultra/src/julia/README.md), [](file:///Users/davidengland/Documents/GitHub/ultra/README.md)


```

```

```

```
The SCM area is wired and documented. I’m running the narrow executable validation now: the new smoke test that loads SHEBA and SMEAR forcing tables and exercises the MOST-coupled SCM path.

Ran terminal command:  julia --project=. test/scm_smoke.jl

The smoke test found a strict local type annotation in the forcing loader, not a design issue. I’m loosening that helper to accept the actual `CSV.read` column-name map and then rerunning the same smoke test.

Generating patch (9 lines) in [](file:///Users/davidengland/Documents/GitHub/ultra/src/julia/scm/ForcingIO.jl)


```

```


Ran terminal command:  julia --project=. test/scm_smoke.jl

The next failure is in the smoke test harness itself, not the SCM code path. I’m removing that `nrow` dependency and rerunning the same test.

Generating patch (12 lines) in [](file:///Users/davidengland/Documents/GitHub/ultra/test/scm_smoke.jl)


```

```


Ran terminal command:  julia --project=. test/scm_smoke.jl

The end-to-end smoke path now passes. I’m doing one quick editor-diagnostics sweep on the touched SCM files, then I’ll close with what was implemented and where the current boundary still is.

Checked [](file:///Users/davidengland/Documents/GitHub/ultra/src/julia/SCMSkeleton.jl), [](file:///Users/davidengland/Documents/GitHub/ultra/src/julia/scm/SurfaceMOST.jl), [](file:///Users/davidengland/Documents/GitHub/ultra/src/julia/scm/ForcingIO.jl), [](file:///Users/davidengland/Documents/GitHub/ultra/src/julia/CurvatureRiClosure.jl), [](file:///Users/davidengland/Documents/GitHub/ultra/test/scm_smoke.jl), no problems found

Read [](file:///Users/davidengland/Documents/GitHub/ultra/src/julia/SCMSkeleton.jl#1-1), lines 1 to 40

Read [](file:///Users/davidengland/Documents/GitHub/ultra/src/julia/scm/ForcingIO.jl#1-1), lines 1 to 80

Implemented the first SCM expansion around src/julia/SCMSkeleton.jl. The module now exposes a real dataset-facing layer and a first regime-aware surface path: `Forcing` carries `u_*`, `L`, `zeta`, and reference-height metadata; `SurfaceState` and `SimulationHistory` now track surface coupling diagnostics; and the module includes the new forcing and MOST helpers plus the cleaned curvature closure.

The new SCM support files are src/julia/scm/ForcingIO.jl and src/julia/scm/SurfaceMOST.jl. `ForcingIO` normalizes SHEBA CSVs, SMEAR CSVs, and SmartSMEAR API runs routed through the existing preprocess script into one forcing schema, with `forcing_from_row` and `surface_state_from_row` helpers for replay and calibration workflows. `SurfaceMOST` adds the first `surface_flux_most(model)` path used when `prescribed_surface_fluxes=false`, using src/julia/MOSTProfiles.jl instead of hard-coded neutral exchange.

I also cleaned src/julia/CurvatureRiClosure.jl into valid source-only Julia, added the SCM index at src/julia/scm/README.md, added the workflow note at docs/SCM_Workflows.md, added the smoke test at test/scm_smoke.jl, and updated src/julia/README.md and README.md so the SCM surface is discoverable.

Validation passed. `julia --project=. test/scm_smoke.jl` completed with `scm_smoke_ok`, and editor diagnostics report no errors in the touched SCM files.

Natural next steps are:
1. Add a small driver script that loops over forcing rows and writes SCM run artifacts in the same style as the existing runs pipelines.
2. Improve the MOST surface routine from fixed-profile replay to an iterative `L` or `zeta` solve, especially for neutral-transition cases.
3. Start lifting large-scale tendencies and richer profile interpolation into the forcing adapter so calibration runs can use more of the SMEAR and SHEBA vertical structure.

Made changes.