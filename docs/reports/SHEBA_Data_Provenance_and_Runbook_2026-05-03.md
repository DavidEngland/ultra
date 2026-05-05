# SHEBA Data Provenance and Runbook (2026-05-03)

## Purpose

This document captures where SHEBA data was found, what was downloaded, how it was preprocessed for ultraspherical fitting, and exactly how to rerun the workflow.

## Public Data Source (Confirmed)

Primary archive root:
https://psl.noaa.gov/arctic/sheba/netcdf/

Primary dataset directory used:
https://psl.noaa.gov/arctic/sheba/netcdf/PerssonDatasets/

Files used for this run:
- https://psl.noaa.gov/arctic/sheba/netcdf/PerssonDatasets/main_file6_hd.txt
- https://psl.noaa.gov/arctic/sheba/netcdf/PerssonDatasets/readme_ASFG3.0.txt

Notes:
- Access is anonymous HTTP (no account/login required).
- Data are tab-delimited text with 9999-style missing values.
- The readme documents column definitions for the ASFG tower products.

## Local Retained Raw Snapshot (NOAA PSL)

Saved local copies for reproducibility:
- data/sheba/raw/main_file6_hd.txt
- data/sheba/raw/readme_ASFG3.0.txt
- data/sheba/raw/SHA256SUMS.txt

SHA-256 checksums:
- main_file6_hd.txt: ca97864a7ab372d148b11ba652a74c9ccab30b36b9aa963ed506bad1b51a34e8
- readme_ASFG3.0.txt: f198e9c96c38f68b09e2c3fdd00e91cfb696dd47a6a0dd84b30aedb15e9a6459

## Local Retained Raw Snapshot (NSF NCAR EOL)

NCAR order URL used:
- https://data.eol.ucar.edu/pub/download/data/dee002994255/

Dataset metadata:
- Dataset 13.114 (Tower, 5-level hourly measurements plus radiometer and surface data at Met City)
- DOI: https://doi.org/10.5065/D65H7DNS

Saved local copies for reproducibility:
- data/sheba/raw/ncar_eol_dee002994255/prof_file_all6_ed_hd.txt
- data/sheba/raw/ncar_eol_dee002994255/readme_ASFG3.0.txt
- data/sheba/raw/ncar_eol_dee002994255/README-info-13_114.txt
- data/sheba/raw/ncar_eol_dee002994255/SHA256SUMS.txt

SHA-256 checksums (NCAR order files):
- prof_file_all6_ed_hd.txt: 278491186f11cd0c83971bc8ca42965e1db63978ad37bd774f1cb11e16604ec9
- readme_ASFG3.0.txt: e7569c69057f75003cb5f2a2d185339411809dd385c28903b1fa94d82597cb79
- README-info-13_114.txt: 1fc8b04a6424fb9b6b0208762be8baf46aa30b3c153946f9d05ed2d8177cadc0

Acquisition note:
- Files were downloaded sequentially (one-at-a-time) to comply with NCAR server guidance.
- The NCAR copy of readme_ASFG3.0 differs in checksum from the NOAA PSL copy, so both are retained.

## Preprocessing Implementation

Script:
- src/julia/preprocess_sheba_main.jl

Input:
- main_file6_hd.txt (hourly ASFG data)

Output schema:
- time, zeta, phi_obs

Core formulas:
- Obukhov length:
  L = -(u*^3 * T_K) / (kappa * g * H), with H = hs / (rho_cp)
- Stable coordinate:
  zeta = z_ref / L, where z_ref = sqrt(2.5 * 10.0)
- Two-level momentum stability function:
  phi_m = (kappa * z_ref / u*) * (ws10 - ws2.5) / (10.0 - 2.5)

QC filters applied:
- u* >= 0.05 m/s
- |hs| >= 2.0 W/m2
- ws10 >= ws2.5
- 0 < zeta <= 10
- 0 < phi_obs <= 30

Column normalization caveat handled:
- CSV.jl normalizenames can map u* -> u_ and ws2.5 -> ws2_5
- Script includes robust candidate matching for column names.

## Executed SHEBA Preprocessing Run

Run folder:
- runs/benchmarks/sheba/ (benchmark artifacts)

Input CSV produced in original workspace:
- output/runs/SHEBA/20260503_sheba_grachev/input/sheba_input.csv

Observed preprocessing counts:
- total rows loaded: 8112
- missing u*: 2074
- missing hs: 6
- missing wind/T: 392
- unstable (zeta <= 0): 1468
- QC failures: 1906
- good stable rows: 2266

Quick file check:
- line count of sheba_input.csv: 2267 (header + 2266 records)

## SHEBA Ultraspherical Fit Run

Driver:
- src/julia/sheba_ultra.jl

Run outputs prefix in original workspace:
- output/runs/SHEBA/20260503_sheba_grachev/fit/sheba_ultra_grachev

Primary benchmark report in this repo:
- runs/benchmarks/sheba/sheba_ultra_grachev_report.md

Metrics from run:
- Grachev baseline test RMSE: 0.3410727610284458
- Grachev+ULTRA test RMSE: 0.3301766276026332
- Relative RMSE gain: 3.19%

Fitted parameters:
- a = 2.49844027746819
- b = 0.6766125007389536
- alpha_xi = 1.7427953628298036
- lambda_star = 0.75
- ridge = 0.0001
- n_ultra = 5
- xi_mode = log
- split_mode = blocked

## Exact Rerun Commands

From repo root:

1) Preprocess SHEBA main file
julia src/julia/preprocess_sheba_main.jl \
  runs/sheba/input/sheba_input.csv \
  data/sheba/raw/main_file6_hd.txt

2) Fit SHEBA ultraspherical model
julia src/julia/sheba_ultra.jl \
  runs/sheba/input/sheba_input.csv \
  runs/sheba/fit/sheba_ultra_grachev \
  SHEBA

3) Fit SHEBA ultraspherical model with zero baseline
julia src/julia/sheba_ultra.jl \
  runs/sheba/input/sheba_input.csv \
  runs/sheba/fit/sheba_ultra_zero \
  SHEBA \
  --baseline=zero

## Additional Public SHEBA Files Worth Future Use

Potential next-step files in the same public directory:
- prof_file_all6_ed_hd.txt (multi-level profile data, better gradient estimates)
- sheba_composite_data.txt
- ASFG_data_10min/ (higher-frequency data, potentially better for HSNBL structure)

Already retained from NCAR order:
- prof_file_all6_ed_hd.txt (5-level hourly tower + turbulence/structure statistics)

## Practical Retention Guidance

- Keep raw snapshots under data/sheba/raw with checksums.
- Keep each run immutable under runs/<run_id>/ or runs/benchmarks/.
- If moving to a dedicated repo, copy this file first, then preserve:
  - data/sheba/raw/
  - src/julia/preprocess_sheba_main.jl
  - src/julia/sheba_ultra.jl
  - runs/benchmarks/sheba/
