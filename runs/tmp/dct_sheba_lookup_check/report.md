# SHEBA DCT Two-Layer Analysis

- Input: runs/sheba/input/sheba_input_rich.csv
- Output dir: runs/tmp/dct_sheba_lookup_check
- Observable: phi_h
- Observable label: phi_h
- Observable source family: derived
- Observable description: Derived heat stability function based on the temperature gradient and sensible heat flux.
- Time range: 1998-10-31T01:00:02.880 to 1999-09-25T16:59:57.120
- Rows used: 1264
- Quantile bins: 48
- DCT modes kept: 8
- Binned reconstruction RMSE: 0.11881
- Binned reconstruction MAE: 0.08956
- Spectral variance kept: 99.14%

- Fingerprints: 48
- Stable events: 31

## Regime Summary

- weak_stable: n=967, median(zeta)=0.11571667289127832, median(phi_h)=0.7381073012955817, mean(phi_h)=0.8507612627912425
- moderate_stable: n=246, median(zeta)=0.899773256658267, median(phi_h)=1.9537145051319182, mean(phi_h)=2.1971601010580124
- very_stable: n=51, median(zeta)=2.578634171004165, median(phi_h)=2.3290161459509067, mean(phi_h)=2.662703933848696

## c1-c3 Relationship

- all: n=48, corr=-0.0686, slope=-76.8810, intercept=81.7612, mean(c1)=1.0898, mean(c3)=-2.0250, skew(c1)=1.0481, skew(c3)=0.1504
- near_neutral: n=17, corr=-0.6363, slope=-6848.0518, intercept=3722.9138, mean(c1)=0.5415, mean(c3)=14.8366, skew(c1)=0.1253, skew(c3)=0.0499
- non_neutral: n=31, corr=0.0979, slope=13.8896, intercept=-30.5854, mean(c1)=1.3905, mean(c3)=-11.2716, skew(c1)=0.6774, skew(c3)=-2.3502

## Artifacts

- fingerprints.csv
- stable_events.csv
- stability_counts.csv
- diagnostics_summary.csv
- c1_c3_relationship_summary.csv
- plot_stability_counts.png
- sheba_binned_profile.csv
- sheba_dct_coeffs.csv
- sheba_dct_reconstruction.csv
- sheba_regime_stats.csv
- sheba_dct_diagnostics.csv
- plot_coeff_distributions.png
- plot_c3_c1_hist.png
- plot_phase_c1_c3.png
- plot_c1_c3_trend.png
- rib_diagnostics_summary.csv
- rib_laminar_events.csv
- plot_sheba_dct_curve.png
- plot_sheba_dct_coeffs.png
