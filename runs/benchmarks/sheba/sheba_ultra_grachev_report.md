# SHEBA Ultraspherical Run Report

## Run

- run name: sheba_ultra_grachev
- dataset: SHEBA
- baseline: Grachev et al. (2007) BLM
- xi-map: tanh(alpha * log1p(zeta))  [log-scale for HSNBL]

## Metrics

| Model | RMSE test | MAE test |
|---|---|---|
| Grachev | 0.3410727610284458 | 0.2610645111520214 |
| Grachev+ULTRA | 0.3301766276026332 | 0.2256491446251999 |

Relative RMSE gain: **3.19%**

## Fitted Grachev Parameters

- a = 2.49844027746819  (canonical Grachev 2007: 5.0)
- b = 0.6766125007389536  (canonical Grachev 2007: 5.0)
- alpha_xi = 1.7427953628298036
- lambda_star = 0.75
- nmax = 5

## Inline Graphics

### Grachev vs Grachev+ULTRA

![comparison](sheba_ultra_grachev_comparison.png)

### Ultraspherical Correction

![correction](sheba_ultra_grachev_correction.png)

## Output Files

- sheba_ultra_grachev_metrics.csv
- sheba_ultra_grachev_params.csv
- sheba_ultra_grachev_pred_test.csv
- sheba_ultra_grachev_coeffs.csv
- sheba_ultra_grachev_curve.csv
- sheba_ultra_grachev_model.jl
- sheba_ultra_grachev_formula.md
- sheba_ultra_grachev_validity_summary.md
