# SHEBA DCT Two-Layer Analysis

- Input: runs/sheba/input/sheba_input_rich.csv
- Output dir: runs/sheba/dct_phi_q
- Observable: phi_q
- Rows used: 590
- Quantile bins: 48
- DCT modes kept: 8
- Binned reconstruction RMSE: 6.66172
- Binned reconstruction MAE: 4.50493
- Spectral variance kept: 87.41%

- Fingerprints: 48
- Stable events: 25

## Regime Summary

- weak_stable: n=501, median(zeta)=0.07733177064497149, median(phi_q)=8.122714728676058, mean(phi_q)=28.012449414892476
- moderate_stable: n=77, median(zeta)=0.8165064038985984, median(phi_q)=39.114605503835065, mean(phi_q)=47.5419141549837
- very_stable: n=12, median(zeta)=2.373799281383156, median(phi_q)=44.77837316140639, mean(phi_q)=50.942227738754646

## Artifacts

- fingerprints.csv
- stable_events.csv
- stability_counts.csv
- diagnostics_summary.csv
- sheba_binned_profile.csv
- sheba_dct_coeffs.csv
- sheba_dct_reconstruction.csv
- sheba_regime_stats.csv
- sheba_dct_diagnostics.csv
- rib_diagnostics_summary.csv
- rib_laminar_events.csv
- plot_sheba_dct_curve.png
- plot_sheba_dct_coeffs.png
