# DCT Fingerprint × Flux Correlation Report

- Season: dead_of_winter
- Fingerprints from: /Users/davidengland/Documents/GitHub/ultra/runs/dct_smear_seasonal_dead_of_winter/varrio_dead_of_winter_temperature_profile
- Heat flux CSV: /Users/davidengland/Documents/GitHub/ultra/runs/seasonal_varrio_station1/dead_of_winter/varrio_dead_of_winter_heat_flux.csv
- Momentum flux CSV: /Users/davidengland/Documents/GitHub/ultra/runs/seasonal_varrio_station1/dead_of_winter/varrio_dead_of_winter_momentum_flux.csv
- CO₂ tracers CSV: /Users/davidengland/Documents/GitHub/ultra/runs/seasonal_varrio_station1/dead_of_winter/varrio_dead_of_winter_co2_tracers.csv
- Quality control: Qc ≤ 1
- Joined rows: 96
- Flux variables available: 11
- Correlation threshold for scatter plots: |r| ≥ 0.2

## Correlation Summary

| Predictor | Flux variable | tablevariable | Pearson r | Spearman ρ | N |
|-----------|--------------|--------------|-----------|------------|---|
| c1 | Friction velocity | VAR_EDDY.u_star | 0.8097 | 0.7390 | 95 |
| c4 | Friction velocity | VAR_EDDY.u_star | -0.7916 | -0.8731 | 95 |
| c1 | Momentum flux | VAR_EDDY.tau | -0.7567 | -0.7337 | 95 |
| c4 | Momentum flux | VAR_EDDY.tau | 0.7344 | 0.8723 | 95 |
| c2 | Momentum flux | VAR_EDDY.tau | 0.6845 | 0.6664 | 95 |
| c2 | Friction velocity | VAR_EDDY.u_star | -0.6753 | -0.6697 | 95 |
| c4 | Wind speed | VAR_EDDY.U | -0.6682 | -0.7303 | 95 |
| c3 | Friction velocity | VAR_EDDY.u_star | -0.5830 | -0.6746 | 95 |
| c3 | Latent heat storage flux | VAR_EDDY.LE_storage_flux | -0.5601 | -0.5199 | 96 |
| c4 | Sensible heat storage flux | VAR_EDDY.H_storage_flux | -0.5555 | -0.5653 | 96 |
| c4 | Latent heat storage flux | VAR_EDDY.LE_storage_flux | -0.5541 | -0.5859 | 96 |
| c3 | Sensible heat storage flux | VAR_EDDY.H_storage_flux | -0.5454 | -0.5656 | 96 |
| c3 | Momentum flux | VAR_EDDY.tau | 0.5374 | 0.6711 | 95 |
| c1 | Wind speed | VAR_EDDY.U | 0.5299 | 0.4570 | 95 |
| c2 | Wind speed | VAR_EDDY.U | -0.4855 | -0.4586 | 95 |
| c1 | Monin-Obukhov length | VAR_EDDY.MO_length | 0.4563 | 0.5574 | 95 |
| c4 | Monin-Obukhov length | VAR_EDDY.MO_length | -0.4421 | -0.6860 | 95 |
| c1 | Latent heat storage flux | VAR_EDDY.LE_storage_flux | 0.4355 | 0.4260 | 96 |
| c2 | Monin-Obukhov length | VAR_EDDY.MO_length | -0.4244 | -0.4648 | 95 |
| c3 | Wind speed | VAR_EDDY.U | -0.4223 | -0.4723 | 95 |
| c2 | CO₂ flux | VAR_EDDY.F_c | 0.4056 | 0.1926 | 74 |
| shape_ratio | Latent heat storage flux | VAR_EDDY.LE_storage_flux | -0.3609 | -0.5914 | 96 |
| c4 | Sensible heat flux | VAR_EDDY.H | 0.3509 | 0.3522 | 80 |
| c3 | Monin-Obukhov length | VAR_EDDY.MO_length | -0.3459 | -0.5933 | 95 |
| c1 | Sensible heat storage flux | VAR_EDDY.H_storage_flux | 0.3388 | 0.3795 | 96 |
| c2 | Sensible heat flux | VAR_EDDY.H | -0.3114 | -0.2202 | 80 |
| c1 | Latent heat flux | VAR_EDDY.LE | 0.3090 | 0.3513 | 57 |
| c1 | CO₂ flux | VAR_EDDY.F_c | -0.3002 | -0.1841 | 74 |
| c4 | Latent heat flux | VAR_EDDY.LE | -0.2803 | -0.3218 | 57 |
| c2 | Latent heat storage flux | VAR_EDDY.LE_storage_flux | -0.2771 | -0.3201 | 96 |
| c3 | Latent heat flux | VAR_EDDY.LE | -0.2765 | -0.3022 | 57 |
| c3 | Sensible heat flux | VAR_EDDY.H | 0.2572 | 0.2985 | 80 |
| c2 | Latent heat flux | VAR_EDDY.LE | -0.2386 | -0.4205 | 57 |
| shape_ratio | Sensible heat storage flux | VAR_EDDY.H_storage_flux | -0.2370 | -0.5186 | 96 |
| c3 | CO₂ flux | VAR_EDDY.F_c | 0.1991 | 0.0603 | 74 |
| shape_ratio | Wind speed | VAR_EDDY.U | -0.1698 | -0.5109 | 95 |
| shape_ratio | Monin-Obukhov length | VAR_EDDY.MO_length | -0.1509 | -0.5612 | 95 |
| shape_ratio | Momentum flux | VAR_EDDY.tau | 0.1483 | 0.4645 | 95 |
| c4 | CO₂ storage flux | VAR_EDDY.CO2_storage_flux | 0.1406 | 0.0869 | 96 |
| shape_ratio | Sensible heat flux | VAR_EDDY.H | 0.1390 | 0.3103 | 80 |
| c2 | Sensible heat storage flux | VAR_EDDY.H_storage_flux | -0.1369 | -0.2906 | 96 |
| shape_ratio | Friction velocity | VAR_EDDY.u_star | -0.1341 | -0.4669 | 95 |
| c3 | CO₂ storage flux | VAR_EDDY.CO2_storage_flux | 0.1302 | 0.0962 | 96 |
| c4 | CO₂ flux | VAR_EDDY.F_c | 0.1197 | -0.1023 | 74 |
| shape_ratio | Latent heat flux | VAR_EDDY.LE | -0.1042 | -0.0408 | 57 |
| shape_ratio | CO₂ storage flux | VAR_EDDY.CO2_storage_flux | 0.1005 | 0.0667 | 96 |
| c1 | Sensible heat flux | VAR_EDDY.H | -0.0669 | -0.0140 | 80 |
| c2 | CO₂ storage flux | VAR_EDDY.CO2_storage_flux | -0.0634 | -0.0322 | 96 |
| c3 | H₂O flux  | VAR_EDDY.E | 0.0591 | -0.0106 | 95 |
| c1 | H₂O flux  | VAR_EDDY.E | -0.0414 | -0.0196 | 95 |
| c1 | CO₂ storage flux | VAR_EDDY.CO2_storage_flux | -0.0328 | -0.0152 | 96 |
| shape_ratio | CO₂ flux | VAR_EDDY.F_c | -0.0264 | -0.0766 | 74 |
| shape_ratio | H₂O flux  | VAR_EDDY.E | -0.0234 | -0.0197 | 95 |
| c4 | H₂O flux  | VAR_EDDY.E | -0.0190 | -0.0469 | 95 |
| c2 | H₂O flux  | VAR_EDDY.E | 0.0174 | -0.0793 | 95 |

## Strongest Associations (|r| ≥ 0.3)

- **c₁ (mean level)** × **Friction velocity** (`VAR_EDDY.u_star`): r = 0.810 (positive), N = 95
- **c₄ (fine structure)** × **Friction velocity** (`VAR_EDDY.u_star`): r = -0.792 (negative), N = 95
- **c₁ (mean level)** × **Momentum flux** (`VAR_EDDY.tau`): r = -0.757 (negative), N = 95
- **c₄ (fine structure)** × **Momentum flux** (`VAR_EDDY.tau`): r = 0.734 (positive), N = 95
- **c₂ (gradient)** × **Momentum flux** (`VAR_EDDY.tau`): r = 0.685 (positive), N = 95
- **c₂ (gradient)** × **Friction velocity** (`VAR_EDDY.u_star`): r = -0.675 (negative), N = 95
- **c₄ (fine structure)** × **Wind speed** (`VAR_EDDY.U`): r = -0.668 (negative), N = 95
- **c₃ (curvature)** × **Friction velocity** (`VAR_EDDY.u_star`): r = -0.583 (negative), N = 95
- **c₃ (curvature)** × **Latent heat storage flux** (`VAR_EDDY.LE_storage_flux`): r = -0.560 (negative), N = 96
- **c₄ (fine structure)** × **Sensible heat storage flux** (`VAR_EDDY.H_storage_flux`): r = -0.555 (negative), N = 96
- **c₄ (fine structure)** × **Latent heat storage flux** (`VAR_EDDY.LE_storage_flux`): r = -0.554 (negative), N = 96
- **c₃ (curvature)** × **Sensible heat storage flux** (`VAR_EDDY.H_storage_flux`): r = -0.545 (negative), N = 96
- **c₃ (curvature)** × **Momentum flux** (`VAR_EDDY.tau`): r = 0.537 (positive), N = 95
- **c₁ (mean level)** × **Wind speed** (`VAR_EDDY.U`): r = 0.530 (positive), N = 95
- **c₂ (gradient)** × **Wind speed** (`VAR_EDDY.U`): r = -0.485 (negative), N = 95
- **c₁ (mean level)** × **Monin-Obukhov length** (`VAR_EDDY.MO_length`): r = 0.456 (positive), N = 95
- **c₄ (fine structure)** × **Monin-Obukhov length** (`VAR_EDDY.MO_length`): r = -0.442 (negative), N = 95
- **c₁ (mean level)** × **Latent heat storage flux** (`VAR_EDDY.LE_storage_flux`): r = 0.436 (positive), N = 96
- **c₂ (gradient)** × **Monin-Obukhov length** (`VAR_EDDY.MO_length`): r = -0.424 (negative), N = 95
- **c₃ (curvature)** × **Wind speed** (`VAR_EDDY.U`): r = -0.422 (negative), N = 95
- **c₂ (gradient)** × **CO₂ flux** (`VAR_EDDY.F_c`): r = 0.406 (positive), N = 74
- **Shape ratio (c₂/c₁)** × **Latent heat storage flux** (`VAR_EDDY.LE_storage_flux`): r = -0.361 (negative), N = 96
- **c₄ (fine structure)** × **Sensible heat flux** (`VAR_EDDY.H`): r = 0.351 (positive), N = 80
- **c₃ (curvature)** × **Monin-Obukhov length** (`VAR_EDDY.MO_length`): r = -0.346 (negative), N = 95
- **c₁ (mean level)** × **Sensible heat storage flux** (`VAR_EDDY.H_storage_flux`): r = 0.339 (positive), N = 96
- **c₂ (gradient)** × **Sensible heat flux** (`VAR_EDDY.H`): r = -0.311 (negative), N = 80
- **c₁ (mean level)** × **Latent heat flux** (`VAR_EDDY.LE`): r = 0.309 (positive), N = 57
- **c₁ (mean level)** × **CO₂ flux** (`VAR_EDDY.F_c`): r = -0.300 (negative), N = 74

## Output Files

- `flux_fingerprint_joined.csv`
- `flux_correlation_matrix.csv`
- `plot_corr_heatmap.png`
- 34 scatter plot(s) for |r| ≥ 0.2
