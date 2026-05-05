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

- a_s = 4.0   [C¹ tie: a_s = b_u/λ_u = 4.0]
- b_s = 1.42711

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

- a_ξ = 0.3
- ζ₀  = NaN

## Gegenbauer Correction

$$
\Delta\phi(\zeta) = \sum_{n=0}^{2} c_n\,C_n^{(\lambda_*)}(\xi(\zeta))
$$

- λ_* = 0.25

- c_0 = -0.5542835877475171
- c_1 = 3.235301100797095
- c_2 = -0.7283405152814774

## Total

$$
\phi(\zeta) = \phi_{\mathrm{base}}(\zeta) + \Delta\phi(\zeta)
$$
