# DCT-SMEAR Results

- Time range: 2025-05-01T00:00:00 to 2025-06-01T00:00:00
- Temperature fetch source: preprocessed_csv:metadata_tdry_dynamic
- Interaction flux source: embedded
- Raw rows fetched: 1488
- Profiles fingerprinted: 1488
- Stable events: 421 (28.3%)

## Stability Counts

- stable: 421
- strongly_stable: 418
- near_neutral: 340
- unstable: 173
- strongly_unstable: 81
- unknown: 55

## Key Diagnostics

- n_profiles: 1488
- n_stable: 421
- stable_fraction: 0.28293
- mean_c2: -0.146561
- mean_c3: 0.0472134
- mean_shape_ratio: 0.72474
- median_ustar: NaN
- fetch_source: NaN
- flux_source: NaN

## c1-c3 Relationship

- all: n=1488, corr=0.7192, slope=0.0141, intercept=0.0484, mean(c1)=-0.0865, mean(c3)=0.0472, skew(c1)=-0.1402, skew(c3)=-0.4179
- near_neutral: n=340, corr=0.6677, slope=0.0106, intercept=0.0497, mean(c1)=-0.4332, mean(c3)=0.0451, skew(c1)=0.1190, skew(c3)=-0.0978
- non_neutral: n=1148, corr=0.7382, slope=0.0154, intercept=0.0476, mean(c1)=0.0162, mean(c3)=0.0478, skew(c1)=-0.2178, skew(c3)=-0.4751

## Output Files

- fingerprints.csv
- stable_events.csv
- stability_counts.csv
- diagnostics_summary.csv
- c1_c3_relationship_summary.csv
- plot_stability_counts.png
- plot_shape_ratio_vs_zeta.png
- plot_coeff_distributions.png
- plot_c3_c1_hist.png
- plot_phase_c1_c3.png
- plot_c1_c3_trend.png
- interaction_joined.csv
- interaction_rolling_corr.csv
- plot_rolling_corr_H_tau.png
- plot_c3_vs_co2_storage_flux.png
