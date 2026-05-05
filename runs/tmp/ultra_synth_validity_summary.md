# Fit Validity Summary

## Scope

- dataset: synthetic
- total samples used: 320
- training samples: 240
- test samples: 80

## Recommended Validity Range

Use the exported function primarily within the fitted stability interval:

- full fitted zeta range: [-1.5, 1.734780252940856]
- robust central zeta range (5%-95%): [-1.2139511385146806, 1.1742934773940163]

## Held-out Skill

- MOST test RMSE: 1.5465880642803642
- MOST+ULTRA test RMSE: 0.06253918294680291
- absolute RMSE improvement: 1.4840488813335613
- relative RMSE improvement: 95.95631284171958%

## Fitted Function Settings

- baseline a: 1.0
- baseline b: 4.7
- baseline lambda_profile: -1.0
- alpha_xi: 1.2751110483723245
- lambda_star: 0.25
- n_ultra: 6
- ridge: 0.0001

## Usage Notes

- The exported ultraspherical correction is a data-fitted residual term added to the baseline MOST function.
- Interpret the correction curve directly before interpreting individual spectral coefficients.
- Avoid extrapolating far outside the fitted zeta range unless additional validation is performed.
