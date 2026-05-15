# Changelog

All notable changes to this repository are documented in this file.

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
