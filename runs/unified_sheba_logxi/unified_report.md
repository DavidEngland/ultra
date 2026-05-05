# Unified All-Regime Ultraspherical Run Report

## Run

- run: unified
- dataset: SHEBA
- regime: stable
- blend: soft
- C¹ continuity tie: yes  (a_s = b_u/λ_u = 4.0)
- ξ-map: tanh(a_ξ · log1p(ζ))  [log, stable-range resolution]

## Metrics (held-out test set)

| Model | RMSE | MAE |
|---|---|---|
| Grachev-C1 | 0.33961 | 0.27593 |
| Grachev-C1+ULTRA    | 0.32853 | 0.23263 |

Relative RMSE gain: **3.26%**

## Baseline Parameters

| param | value | meaning |
|---|---|---|
| b_u     | 16.0      | unstable exponent scale       |
| λ_u     | 4.0 | unstable exponent             |
| β_c1    | 4.0  | neutral slope tie = b_u/λ_u   |
| a_s     | 4.0      | stable linear slope (=β_c1 if tied) |
| b_s     | 1.42711      | Grachev curvature             |

## Gegenbauer Hyperparameters

| param | value |
|---|---|
| a_ξ   | 0.3         |
| ζ₀    | (n/a — log map)           |
| λ_*   | 0.25   |
| nmax  | 2                           |
| ridge | 0.05                          |

## Plots

![comparison](unified_comparison.png)

![correction](unified_correction.png)

## Output Files

- unified_metrics.csv
- unified_params.csv
- unified_pred_test.csv
- unified_coeffs.csv
- unified_curve.csv
- unified_model.jl
- unified_formula.md
- unified_report.md
