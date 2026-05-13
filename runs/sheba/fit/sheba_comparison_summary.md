# SHEBA Model Comparison Summary

Input dataset: runs/sheba/input/sheba_input.csv

## Preprocessing

- Total source rows: 8112
- Good stable rows retained: 2266
- Construction: two-level profile from main_file6_hd.txt (2.5 m and 10 m)

## Held-out Test Metrics

### Grachev baseline family

- Grachev RMSE: 0.3411
- Grachev+ULTRA RMSE: 0.3302
- Relative RMSE gain: 3.19%
- Grachev MAE: 0.2611
- Grachev+ULTRA MAE: 0.2256

### Zero baseline family

- Zero RMSE: 1.2593
- Zero+ULTRA RMSE: 0.3315
- Relative RMSE gain: 73.68%
- Zero MAE: 1.1313
- Zero+ULTRA MAE: 0.2264

## Interpretation

- A physically informed baseline (Grachev) already performs strongly.
- Adding ULTRA still improves held-out skill modestly and consistently.
- With no baseline, ULTRA recovers most structure and dramatically reduces error.

## Generated Artifacts

- runs/sheba/fit/sheba_ultra_grachev_report.md
- runs/sheba/fit/sheba_ultra_grachev_comparison.png
- runs/sheba/fit/sheba_ultra_zero_report.md
- runs/sheba/fit/sheba_ultra_zero_comparison.png
