# Quickstart

This quickstart is focused on running [src/julia/DCT_SMEAR.jl](src/julia/DCT_SMEAR.jl) and the other main Julia entry scripts in this repository.

## 1) Requirements

- Julia 1.9+
- Internet access for SmartSMEAR API-based runs

From repository root:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## 2) DCT_SMEAR Fast Run

Run:

```bash
julia --project=. -e 'include("src/julia/DCT_SMEAR.jl")'
```

Primary outputs are written under:

- [runs/dct_smear_20250501_20250601](runs/dct_smear_20250501_20250601)

Expected files include:

- [runs/dct_smear_20250501_20250601/fingerprints.csv](runs/dct_smear_20250501_20250601/fingerprints.csv)
- [runs/dct_smear_20250501_20250601/stable_events.csv](runs/dct_smear_20250501_20250601/stable_events.csv)
- [runs/dct_smear_20250501_20250601/stability_counts.csv](runs/dct_smear_20250501_20250601/stability_counts.csv)
- [runs/dct_smear_20250501_20250601/diagnostics_summary.csv](runs/dct_smear_20250501_20250601/diagnostics_summary.csv)
- [runs/dct_smear_20250501_20250601/report.md](runs/dct_smear_20250501_20250601/report.md)

## 3) Metadata Lookup Helpers For SMEAR Scripting

Generated compact lookup files:

- [data/smear/vars_compact_lookup.json](data/smear/vars_compact_lookup.json)
- [data/smear/varrio_dct_subset.json](data/smear/varrio_dct_subset.json)

Julia helper module:

- [src/julia/SMEARVarLookup.jl](src/julia/SMEARVarLookup.jl)

Smoke test:

```bash
julia --project=. -e 'include("src/julia/SMEARVarLookup.jl"); using .SMEARVarLookup; println(length(varrio_dct_vars(:temperature_profile))); println(station_categories(1))'
```

## 4) Other Common Entry Scripts

Varrio seasonal preprocessing (same day-of-year across years, station 1):

```bash
julia --project=. src/julia/SMEAR_seasonal.jl --start-year=2016 --end-year=2025 --doy=15 --season=dead_of_winter
```

This writes grouped tracer inputs under:

- [runs/seasonal_varrio_station1/dead_of_winter](runs/seasonal_varrio_station1/dead_of_winter)

Key outputs include:

- [runs/seasonal_varrio_station1/dead_of_winter/varrio_dead_of_winter_heat_flux.csv](runs/seasonal_varrio_station1/dead_of_winter/varrio_dead_of_winter_heat_flux.csv)
- [runs/seasonal_varrio_station1/dead_of_winter/varrio_dead_of_winter_momentum_flux.csv](runs/seasonal_varrio_station1/dead_of_winter/varrio_dead_of_winter_momentum_flux.csv)
- [runs/seasonal_varrio_station1/dead_of_winter/varrio_dead_of_winter_humidity_profile.csv](runs/seasonal_varrio_station1/dead_of_winter/varrio_dead_of_winter_humidity_profile.csv)
- [runs/seasonal_varrio_station1/dead_of_winter/varrio_dead_of_winter_co2_tracers.csv](runs/seasonal_varrio_station1/dead_of_winter/varrio_dead_of_winter_co2_tracers.csv)
- [runs/seasonal_varrio_station1/dead_of_winter/varrio_dead_of_winter_dct_temperature_input.csv](runs/seasonal_varrio_station1/dead_of_winter/varrio_dead_of_winter_dct_temperature_input.csv)

Run DCT_SMEAR on the preprocessed seasonal input:

```bash
DCT_SMEAR_INPUT_CSV="runs/seasonal_varrio_station1/dead_of_winter/varrio_dead_of_winter_dct_temperature_input.csv" \
DCT_SMEAR_OUT_DIR="runs/dct_smear_varrio_dead_of_winter" \
julia --project=. -e 'include("src/julia/DCT_SMEAR.jl")'
```

SHEBA preprocess:

```bash
julia --project=. src/julia/preprocess_sheba_main.jl runs/sheba/input/sheba_input.csv data/sheba/raw/main_file6_hd.txt
```

SHEBA preprocess from richer NCAR/EOL 5-level profile file:

```bash
julia --project=. src/julia/preprocess_sheba_main.jl \
  runs/sheba/input/sheba_input_rich.csv \
  data/sheba/raw/ncar_eol_dee002994255/prof_file_all6_ed_hd.txt
```

This preserves compatibility fields (`time`, `zeta`, `phi_obs`) and also carries
many extra profile/flux variables (for example `z1..z5`, `ws1..ws5`, `T1..T5`,
`q1..q5`, `rh1..rh5`, `u_1..u_5`, `hs1..hs5`, `hl`, radiation terms) when present.

SHEBA fit (Grachev baseline):

```bash
julia --project=. src/julia/sheba_ultra.jl runs/sheba/input/sheba_input.csv runs/sheba/fit/sheba_ultra_grachev SHEBA --baseline=grachev
```

SHEBA DCT parity run (legacy + SMEAR-style artifacts):

```bash
julia --project=. -e 'include("src/julia/DCT_SHEBA.jl")'
```

Optional environment controls:

```bash
DCT_SHEBA_INPUT_CSV="runs/sheba/input/sheba_input.csv" \
DCT_SHEBA_OUT_DIR="runs/sheba/dct_main_file6" \
DCT_SHEBA_OBS_COL="phi_obs" \
DCT_SHEBA_ROLLING_WINDOW=12 \
julia --project=. -e 'include("src/julia/DCT_SHEBA.jl")'
```

Run against the richer NCAR-derived input:

```bash
DCT_SHEBA_INPUT_CSV="runs/sheba/input/sheba_input_rich.csv" \
DCT_SHEBA_OUT_DIR="runs/sheba/dct_main_file6_rich" \
julia --project=. -e 'include("src/julia/DCT_SHEBA.jl")'
```

Run heat and humidity scalar variants from the same rich input:

```bash
DCT_SHEBA_INPUT_CSV="runs/sheba/input/sheba_input_rich.csv" \
DCT_SHEBA_OUT_DIR="runs/sheba/dct_phi_h" \
DCT_SHEBA_OBS_COL="phi_h" \
julia --project=. -e 'include("src/julia/DCT_SHEBA.jl")'

DCT_SHEBA_INPUT_CSV="runs/sheba/input/sheba_input_rich.csv" \
DCT_SHEBA_OUT_DIR="runs/sheba/dct_phi_q" \
DCT_SHEBA_OBS_COL="phi_q" \
julia --project=. -e 'include("src/julia/DCT_SHEBA.jl")'
```

`phi_obs` remains the backward-compatible default and is currently equal to `phi_m`.

Expected parity outputs include:

- [runs/sheba/dct_main_file6/fingerprints.csv](runs/sheba/dct_main_file6/fingerprints.csv)
- [runs/sheba/dct_main_file6/stable_events.csv](runs/sheba/dct_main_file6/stable_events.csv)
- [runs/sheba/dct_main_file6/stability_counts.csv](runs/sheba/dct_main_file6/stability_counts.csv)
- [runs/sheba/dct_main_file6/diagnostics_summary.csv](runs/sheba/dct_main_file6/diagnostics_summary.csv)
- [runs/sheba/dct_main_file6/rib_diagnostics_summary.csv](runs/sheba/dct_main_file6/rib_diagnostics_summary.csv)
- [runs/sheba/dct_main_file6/report.md](runs/sheba/dct_main_file6/report.md)

Synthetic ultraspherical smoke test:

```bash
julia --project=. src/julia/ultraspherical_practical_run.jl --synthetic runs/tmp/ultra_synth 0.08 320
```

SMEAR preprocessing template:

```bash
julia --project=. src/julia/preprocess_tower_to_ultra_input.jl HYY runs/smear/input/hyy_input.csv 24.0 0.0 --mode=api-smear --profile-mode=two-level --from=2018-01-01T00:00:00 --to=2018-02-01T00:00:00 --interval=30 --aggregation=ARITHMETIC --quality=ANY --tv-uw=HYY_EDDY233.uw --tv-vw=HYY_EDDY233.vw --tv-wthetav=HYY_EDDY233.wtheta_v --tv-thetav=HYY_EDDY233.theta_v --tv-u1=HYY_META.WSU168 --tv-u2=HYY_EDDY233.U --tv-theta1=HYY_META.T168 --tv-theta2=HYY_EDDY233.av_t --z1=16.8 --z2=24.0 --phi=phi_m --stable-only
```

Hyytiälä (station 2) DCT adapter run (single window):

```bash
julia --project=. src/julia/hyy_station2_to_dct_input.jl \
  --from=2021-01-01T00:00:00 \
  --to=2021-02-01T00:00:00 \
  --out=runs/hyy_station2/input/hyy_station2_2021_01_dct_input.csv \
  --aggregation=ARITHMETIC \
  --quality=ANY

DCT_SMEAR_INPUT_CSV="runs/hyy_station2/input/hyy_station2_2021_01_dct_input.csv" \
DCT_SMEAR_OUT_DIR="runs/hyy_station2/dct/2021_01" \
DCT_SMEAR_FETCH_INTERACTION_FLUX=false \
julia --project=. -e 'include("src/julia/DCT_SMEAR.jl")'
```

Hyytiälä (station 2) winter matrix run (2021-2025):

```bash
bash scripts/run_smear_hyy_station2_winter_matrix.sh 2021 2025 hyy_station2_ri_curvature_tier1
```

Continue on per-month failures:

```bash
bash scripts/run_smear_hyy_station2_winter_matrix.sh 2021 2025 hyy_station2_ri_curvature_tier1 true
```

Värriö (station 1) winter matrix run (2020-2024):

```bash
bash scripts/run_smear_varrio_station1_winter_matrix.sh 2020 2024 varrio_station1_ri_curvature_tier1
```

Continue on per-month failures:

```bash
bash scripts/run_smear_varrio_station1_winter_matrix.sh 2020 2024 varrio_station1_ri_curvature_tier1 true
```

## 5) Troubleshooting

- If you get SmartSMEAR 400 variable errors, verify tablevariable names in [data/smear/vars.json](data/smear/vars.json).
- For Varrio-specific scripting, use [data/smear/varrio_dct_subset.json](data/smear/varrio_dct_subset.json) and [src/julia/SMEARVarLookup.jl](src/julia/SMEARVarLookup.jl) instead of hardcoding names.
- If dependencies drift, rerun:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```
