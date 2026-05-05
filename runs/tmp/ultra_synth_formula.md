# Exported MOST + Ultraspherical Function

The fitted function is

$$
\phi(\zeta) = \phi_{MOST}(\zeta) + \Delta \phi_{ultra}(\zeta)
$$

with baseline

$$
\phi_{MOST}(\zeta) = a (1 + b \zeta)^{-1/\lambda_p}
$$

where

- a = 1.0
- b = 4.7
- \lambda_p = -1.0

The ultraspherical correction uses

$$
\xi(\zeta) = \tanh(\alpha_\xi \zeta)
$$

with

- \alpha_\xi = 1.2751110483723245
- \lambda_* = 0.25

and residual correction

$$
\Delta \phi_{ultra}(\zeta) = \sum_{n=0}^{6} c_n C_n^{(\lambda_*)}(\xi(\zeta))
$$

with fitted coefficients

- c_0 = -1.0404372673195514
- c_1 = -7.22625088659016
- c_2 = -5.220756746677391
- c_3 = -1.809620208708425
- c_4 = -1.67863956281399
- c_5 = -2.1206235480975173
- c_6 = -1.0714267811057017
