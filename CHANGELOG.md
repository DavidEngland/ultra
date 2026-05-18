# Changelog

All notable changes to this repository are documented in this file.

## 2026-05-17

### Added
- Added `data/sheba/vars.json`, a SHEBA variable catalog covering the hourly two-level and five-level ASFG files with units, descriptions, normalized column names, and grouped level-family metadata.
- Added `docs/SHEBA_Variable_Catalog.md` to document provenance, naming normalization, grouped variables, plotting guidance, and known caveats in the SHEBA catalog.
- Added `src/julia/SHEBAVarLookup.jl` to resolve SHEBA variable metadata from `data/sheba/vars.json`, including derived `phi_m`, `phi_h`, and `phi_q` observables used in the SHEBA DCT pipeline.
- Added `src/julia/summarize_dct_reports.jl` to aggregate per-run and per-year DCT report metrics across `runs/`.
- Added `src/julia/fit_most_profiles.jl` for generic preprocessed MOST branch fitting with unstable `BD_CLASSIC` / `BD_PL` fits plus a weakly stable continuation tied at neutral.
- Added `docs/notes/MOST_BD_WeaklyStable_Fit.md` to document the neutral-slope match and the `Ri_{thick} = \lambda / b` relation, including the momentum case `4/b`.

### Changed
- Updated README and quickstart documentation to point to the SHEBA variable catalog and its intended use in future plotting and lookup code.
- Narrowed `.gitignore` so generated PNG plot artifacts under `runs/` are ignored without ignoring the entire `runs/` tree.
- Updated `src/julia/DCT_SHEBA.jl` to use SHEBA metadata labels in reports and plots and to emit SMEAR-parity stability-count and coefficient-distribution histograms.
- Updated quickstart guidance to include the new generic MOST branch-fitting path for standardized preprocessed CSVs.

## 2026-05-15

### Added
- Added lagged cross-correlation analysis in `src/julia/DCT_SMEAR_Seasonal.jl` for `temperature_profile` DCT coefficients against `co2_tracers` `VAR_EDDY.F_c`.
- Added per-run artifacts for temperature-profile analyses:
  - `crosscorr_temp_vs_fc.csv`
  - `plot_crosscorr_temp_vs_fc.png`
  - `curvature_at_near_zero_fc_summary.csv`
  - `plot_curvature_vs_fc_near_zero.png`
- Added variable-title labeling support in `src/julia/DCT_SMEAR_FluxCorr.jl` using `data/smear/vars.json` for plot/report readability.

### Changed
- Updated `src/julia/DCT_SMEAR_FluxCorr.jl` to include stability-class legends in scatter plots and friendlier axis labels.
- Updated repository hygiene with a new `.gitignore` to prevent uploading large, regenerable run outputs.
- Set data retention rules to keep SHEBA files in version control as:
  - `data/sheba/raw/*.txt`
  - `data/sheba/processed/*.csv`
