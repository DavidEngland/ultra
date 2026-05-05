# Unified All-Regime Ultraspherical φ — Fitted Formula

## Unstable Baseline  (ζ < 0)

$$
\phi_u(\zeta) = (1 - b_u\,\zeta)^{-1/\lambda_u}
$$

- b_u = 16.0
- λ_u = 4.0
- Neutral slope: b_u/λ_u = 4.0

## Stable Baseline  (ζ > 0)

$$
\phi_s(\zeta) = 1 + \frac{a_s\,\zeta\,(1+\zeta)^{1/3}}{1 + b_s\,\zeta}
$$

- a_s = 2.49844   [free fit]
- b_s = 0.67661

## Blend  (regime=stable)

$$
s(\zeta) = \tfrac{1}{2}\Bigl(1 + \tanh\tfrac{\zeta}{\delta}\Bigr),\quad \delta = 0.1
$$
$$
\phi_{\mathrm{base}}(\zeta) = [1-s(\zeta)]\,\phi_u + s(\zeta)\,\phi_s
$$

## All-Regime ξ-Map

$$
\xi = \tanh\!\Bigl(a_\xi\,\operatorname{asinh}\!\bigl(\zeta/\zeta_0\bigr)\Bigr)
$$

- a_ξ = 1.8
- ζ₀  = 0.1

## Gegenbauer Correction

$$
\Delta\phi(\zeta) = \sum_{n=0}^{2} c_n\,C_n^{(\lambda_*)}(\xi(\zeta))
$$

- λ_* = 0.25

- c_0 = 0.10570645588813
- c_1 = -1.2407165728613991
- c_2 = 1.2997015266675818

## Total

$$
\phi(\zeta) = \phi_{\mathrm{base}}(\zeta) + \Delta\phi(\zeta)
$$
