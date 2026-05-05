# SHEBA Ultraspherical Run Report

## Run

- run name: sheba_ultra_zero
- dataset: SHEBA
- baseline: Zero (no MOST profile)
- xi-map: tanh(alpha * log1p(zeta))  [log-scale for HSNBL]

## Metrics

| Model | RMSE test | MAE test |
|---|---|---|
| Zero | 1.2593415819876834 | 1.1312852395511366 |
| Zero+ULTRA | 0.3314652044141475 | 0.2263532339790299 |

Relative RMSE gain: **73.68%**

## Fitted Parameters

- baseline_mode = zero
- a = 0.0
- b = 0.0
- alpha_xi = 1.7427953628298036
- lambda_star = 0.25
- nmax = 6

## Coefficient Physical Meaning (HSNBL heuristics)

- c0 (mode 0 offset): 1.3185223804715362
- c1 (mode 1 tilt): 3.460085956728704
- c2 (mode 2 curvature): 2.8806009805544757
- Neutral-core slope in xi (2*lambda_* * c1): 1.730042978364352
- Core curvature proxy in xi (2*lambda_*(lambda_*+1)*c2): 1.8003756128465473
- Dominant |coeff| mode: n=1 (fraction=30.52%)

Interpretation guide:
- n=0: bulk level shift relative to baseline.
- n=1: first-order monotonic tilt across stability (often tied to shear/jet strengthening tendency).
- n=2: primary curvature/inversion structure (how sharply phi bends with stability).
- n>=3: higher-order intermittency/wave-like structure and regime transitions.

## Inline Graphics

### Zero vs Zero+ULTRA

![comparison](sheba_ultra_zero_comparison.png)

### Ultraspherical Correction

![correction](sheba_ultra_zero_correction.png)

## Output Files

- sheba_ultra_zero_metrics.csv
- sheba_ultra_zero_params.csv
- sheba_ultra_zero_pred_test.csv
- sheba_ultra_zero_coeffs.csv
- sheba_ultra_zero_curve.csv
- sheba_ultra_zero_model.jl
- sheba_ultra_zero_formula.md
- sheba_ultra_zero_validity_summary.md
