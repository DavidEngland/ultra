# SHEBA Variable Catalog

This note documents the structure and intent of [data/sheba/vars.json](data/sheba/vars.json), which is the SHEBA-side analogue of the SMEAR variable inventory.

## Purpose

The catalog is intended to support:

- consistent plot labels and titles
- future variable pickers or lookup helpers
- stable column descriptions across the two main SHEBA ASFG hourly files
- future preprocessing/report code that needs human-readable metadata

The catalog is source-driven. Descriptions were built from:

- [data/sheba/raw/readme_ASFG3.0.txt](data/sheba/raw/readme_ASFG3.0.txt)
- [data/sheba/raw/main_file6_hd.txt](data/sheba/raw/main_file6_hd.txt)
- [data/sheba/raw/ncar_eol_dee002994255/prof_file_all6_ed_hd.txt](data/sheba/raw/ncar_eol_dee002994255/prof_file_all6_ed_hd.txt)
- [data/sheba/raw/ncar_eol_dee002994255/README-info-13_114.txt](data/sheba/raw/ncar_eol_dee002994255/README-info-13_114.txt)

## Files Covered

### 1. main_file6_hd

Two-level hourly file derived from the five-level tower file.
It contains interpolated 2.5 m and 10 m wind, temperature, and humidity, plus median fluxes and bulk flux products.

Good default source for:

- two-level MOST diagnostics
- bulk Richardson calculations
- direct `phi_m`, `phi_h`, and humidity-scalar workflows

### 2. prof_file_all6_ed_hd

Five-level hourly tower file with:

- actual level heights `z1..z5`
- wind, temperature, humidity, and relative humidity profiles
- friction velocity and sensible heat flux by level
- latent heat flux
- radiometer and surface temperatures
- turbulence moments and structure-function parameters
- FFT counts and QC flags

Good default source for:

- true multi-level profile plots
- level-by-level comparisons
- turbulence-variance and structure-function diagnostics

## Naming Conventions

The catalog stores normalized column names where that is the form most Julia code will use after `CSV.read(...; normalizenames=true)`.

Common conversions are:

- `ws2.5` -> `ws2_5`
- `wd2.5` -> `wd2_5`
- `T2.5` -> `T2_5`
- `q2.5` -> `q2_5`
- `rhi2.5` -> `rhi2_5`
- `u*` -> `u_`
- `u*1` -> `u_1`

When the raw file name materially differs from the normalized name, `vars.json` includes `rawColumn`.

## Grouped Variables

Unlike the SMEAR JSON, the SHEBA catalog uses grouped level families for repeated tower fields. This keeps the file readable while still making the metadata explicit enough for future expansion.

Examples:

- `ws1..ws5`
- `T1..T5`
- `q1..q5`
- `rh1..rh5`
- `rhi1..rhi5`
- `u_1..u_5`
- `hs1..hs5`
- `sgu1..sgu5`
- `cu21..cu25`
- `No1..No5`
- `fl1..fl5`

Each grouped entry provides:

- `members`
- `titleTemplate`
- `plotLabelTemplate`
- `unit`
- a shared description

For grouped tower variables, level index should be paired with the corresponding height variable `z1..z5` when building plot annotations.

## Plotting Guidance

Recommended precedence when building labels:

1. use `plotLabel` when present
2. otherwise use `title`
3. for grouped families, expand `plotLabelTemplate` or `titleTemplate`
4. append units from `unit` in axis labels or legends when that adds clarity

Examples:

- `phi_h` plots using `T2_5` and `T10` should label temperatures as `Temperature (2.5 m)` and `Temperature (10 m)`
- profile plots from `T1..T5` should use the actual heights from `z1..z5`, not just the level index
- turbulence QC overlays should include `fl#` because a failed flag can imply suspect sonic-derived wind fields

## Important Data Caveats

- `Tsfc` is the ASFG best estimate of surface temperature and is generally preferable to using a single radiometer channel blindly.
- `T_s_epp` is described as the most reliable radiometric surface temperature in general, with caveats noted in the ASFG readme.
- `hl` from the Ophir instruments is explicitly described as low relative to bulk latent heat estimates and should be used cautiously.
- `rhi#` is relative humidity with respect to ice and is usually the better humidity field for stable Arctic boundary-layer interpretation.
- `fl#` values are quality flags where `0=pass` and `1=fail`; failed turbulence flags can also imply suspect sonic-derived wind quantities.
- The raw main-file header includes `zogb10`, while the nearby moisture roughness field at 2.5 m is `zoqb2.5`. The catalog preserves `zogb10` as written in the file but notes that it likely denotes the 10 m moisture roughness analogue.

## Suggested Future Uses

- build a small SHEBA lookup helper similar to `SMEARVarLookup.jl`
- auto-generate plot titles and legend labels from `vars.json`
- standardize column descriptions in reports
- support variable selection UIs for SHEBA runs
- expand the catalog later if daily files or higher-frequency PI-specific files are added
