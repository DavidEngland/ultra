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

SHEBA preprocess:

```bash
julia --project=. src/julia/preprocess_sheba_main.jl runs/sheba/input/sheba_input.csv data/sheba/raw/main_file6_hd.txt
```

SHEBA fit (Grachev baseline):

```bash
julia --project=. src/julia/sheba_ultra.jl runs/sheba/input/sheba_input.csv runs/sheba/fit/sheba_ultra_grachev SHEBA --baseline=grachev
```

Synthetic ultraspherical smoke test:

```bash
julia --project=. src/julia/ultraspherical_practical_run.jl --synthetic runs/tmp/ultra_synth 0.08 320
```

SMEAR preprocessing template:

```bash
julia --project=. src/julia/preprocess_tower_to_ultra_input.jl HYY runs/smear/input/hyy_input.csv 24.0 0.0 --mode=api-smear --profile-mode=two-level --from=2018-01-01T00:00:00 --to=2018-02-01T00:00:00 --interval=30 --aggregation=ARITHMETIC --quality=ANY --tv-uw=HYY_EDDY233.uw --tv-vw=HYY_EDDY233.vw --tv-wthetav=HYY_EDDY233.wtheta_v --tv-thetav=HYY_EDDY233.theta_v --tv-u1=HYY_META.WSU168 --tv-u2=HYY_EDDY233.U --tv-theta1=HYY_META.T168 --tv-theta2=HYY_EDDY233.av_t --z1=16.8 --z2=24.0 --phi=phi_m --stable-only
```

## 5) Troubleshooting

- If you get SmartSMEAR 400 variable errors, verify tablevariable names in [data/smear/vars.json](data/smear/vars.json).
- For Varrio-specific scripting, use [data/smear/varrio_dct_subset.json](data/smear/varrio_dct_subset.json) and [src/julia/SMEARVarLookup.jl](src/julia/SMEARVarLookup.jl) instead of hardcoding names.
- If dependencies drift, rerun:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```
