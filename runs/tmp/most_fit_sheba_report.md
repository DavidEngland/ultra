# MOST Branch Fits

- Input: runs/sheba/input/sheba_input_rich.csv
- Dataset: SHEBA_rich
- Ri driver: zeta fallback
- Ri_c: 0.25
- Near-neutral band: |zeta| <= 0.1

## Model Form

Unstable branch:

$$\phi_u(\zeta) = (1 - b\,\zeta)^{-1/\lambda}, \qquad \zeta < 0$$

Weakly stable branch:

$$\phi_{ws}(R) = 1 + s_0 R + c_2 R^2, \qquad s_0 = b/\lambda$$

with $R$ taken from the available Richardson-number driver and otherwise approximated by $\zeta$ near neutral.

The implied thickness scale is

$$Ri_{thick} = 1/s_0 = \lambda / b,$$

so momentum with $\lambda = 4$ reduces to $Ri_{thick} = 4/b$. This is reported for each fit alongside the regime threshold $Ri_c$.

## Fit Summary

### momentum

- BD_CLASSIC: unstable_status=default_no_unstable_data, weak_status=fit_ok, b=16.0000, lambda=4.0000, slope0=4.0000, Ri_thick=0.2500, c2=-0.3542, RMSE_piecewise=0.4040
- BD_PL: unstable_status=default_no_unstable_data, weak_status=fit_ok, b=16.0000, lambda=4.0000, slope0=4.0000, Ri_thick=0.2500, c2=-0.3542, RMSE_piecewise=0.4040

### heat

- BD_CLASSIC: unstable_status=default_no_unstable_data, weak_status=fit_ok, b=16.0000, lambda=2.0000, slope0=8.0000, Ri_thick=0.1250, c2=-49.6941, RMSE_piecewise=1.7311
- BD_PL: unstable_status=default_no_unstable_data, weak_status=fit_ok, b=16.0000, lambda=2.0000, slope0=8.0000, Ri_thick=0.1250, c2=-49.6941, RMSE_piecewise=1.7311

### q

- BD_CLASSIC: unstable_status=default_no_unstable_data, weak_status=fit_ok, b=16.0000, lambda=2.0000, slope0=8.0000, Ri_thick=0.1250, c2=104.9310, RMSE_piecewise=216.1705
- BD_PL: unstable_status=default_no_unstable_data, weak_status=fit_ok, b=16.0000, lambda=2.0000, slope0=8.0000, Ri_thick=0.1250, c2=104.9310, RMSE_piecewise=216.1705

## Artifacts

- fit_params.csv
- fit_predictions.csv
- fit_regime_stats.csv
- fit_curves.csv
