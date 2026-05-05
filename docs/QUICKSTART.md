# Quickstart

## 1) Requirements

- Julia 1.9+
- Packages: CSV, DataFrames, LsqFit, LinearAlgebra, Statistics, Random
- Optional plotting: CairoMakie

Install packages:

```bash
julia -e 'using Pkg; Pkg.add(["CSV","DataFrames","LsqFit","LinearAlgebra","Statistics","Random","Dates","Downloads"])'
julia -e 'using Pkg; Pkg.add("CairoMakie")'
```

## 2) Synthetic smoke test

```bash
julia src/julia/ultraspherical_practical_run.jl --synthetic runs/tmp/ultra_synth 0.08 320
```

Expected files include:
- runs/tmp/ultra_synth_metrics.csv
- runs/tmp/ultra_synth_params.csv
- runs/tmp/ultra_synth_coeffs.csv

## 3) SHEBA workflow

Preprocess (uses retained raw file or downloads if omitted):

```bash
julia src/julia/preprocess_sheba_main.jl runs/sheba/input/sheba_input.csv data/sheba/raw/main_file6_hd.txt
```

Profile-rich SHEBA source (already retained from NCAR order):

- data/sheba/raw/ncar_eol_dee002994255/prof_file_all6_ed_hd.txt

Use this file for future multi-level gradient preprocessing and HSNBL sensitivity tests.

NCAR download policy reminder:

- Download one file at a time (sequential) for NCAR order links.

Fit with Grachev baseline:

```bash
julia src/julia/sheba_ultra.jl runs/sheba/input/sheba_input.csv runs/sheba/fit/sheba_ultra_grachev SHEBA --baseline=grachev
```

Fit with zero baseline (ultraspherical only):

```bash
julia src/julia/sheba_ultra.jl runs/sheba/input/sheba_input.csv runs/sheba/fit/sheba_ultra_zero SHEBA --baseline=zero
```

## 4) SMEAR workflow (template)

Preprocess via API/local tower:

```bash
julia src/julia/preprocess_tower_to_ultra_input.jl HYY runs/smear/input/hyy_input.csv 24.0 0.0 --mode=api-smear --profile-mode=two-level --from=2018-01-01T00:00:00 --to=2018-02-01T00:00:00 --interval=30 --aggregation=ARITHMETIC --quality=ANY --tv-uw=HYY_EDDY233.uw --tv-vw=HYY_EDDY233.vw --tv-wthetav=HYY_EDDY233.wtheta_v --tv-thetav=HYY_EDDY233.theta_v --tv-u1=HYY_META.WSU168 --tv-u2=HYY_EDDY233.U --tv-theta1=HYY_META.T168 --tv-theta2=HYY_EDDY233.av_t --z1=16.8 --z2=24.0 --phi=phi_m --stable-only
```

Fit:

```bash
julia src/julia/ultraspherical_practical_run.jl runs/smear/input/hyy_input.csv runs/smear/fit/hyy_ultra
```

## 5) Validation

- Compare RMSE in metrics files (baseline vs baseline+ULTRA)
- Review report markdown in the same output prefix
- Optionally inspect generated PNG comparison plots
