# Ultraspherical Run Report

## Run

- run name: varrio_ultra_linearfit
- dataset label: observed

## Metrics

- MOST test RMSE: 0.8342888174337197
- MOST+ULTRA test RMSE: 0.6769012227541137
- absolute RMSE gain: 0.15738759467960606
- relative RMSE gain: 18.864881248646217%

## Parameters

- baseline a: 1.0
- baseline b: 0.09999999999999964
- baseline lambda_profile: -1.0
- alpha_xi: 28.132900277521436
- lambda_star: 0.25
- ridge: 0.0001
- n_ultra: 2
- regime: all
- split_mode: blocked

## Inline Graphics

### MOST vs MOST+ULTRA

![MOST vs MOST+ULTRA](varrio_ultra_linearfit_comparison.png)

### Ultraspherical Correction

![Ultraspherical Correction](varrio_ultra_linearfit_correction.png)

## Run Files

- varrio_ultra_linearfit_metrics.csv
- varrio_ultra_linearfit_params.csv
- varrio_ultra_linearfit_coeffs.csv
- varrio_ultra_linearfit_pred_test.csv
- varrio_ultra_linearfit_curve.csv
- varrio_ultra_linearfit_model.jl
- varrio_ultra_linearfit_formula.md
- varrio_ultra_linearfit_validity_summary.md
