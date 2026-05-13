# SHEBA Fitted Function (Grachev 2007 + Ultraspherical)

$$
\phi(\zeta) = \phi_{base}(\zeta) + \Delta\phi_{ultra}(\zeta)
$$

xi-mapping: tanh(alpha * log1p(zeta)),  alpha = 1.7427953628298036

$$
\Delta\phi_{ultra}(\zeta) = \sum_{n=0}^{5} c_n C_n^{(\lambda_*)}(\xi(\zeta))
$$

- lambda_* = 0.75

Grachev baseline:

$$
\phi_{G07}(\zeta) = 1 + \frac{a\,\zeta\,(1+\zeta)^{1/3}}{1 + b\,\zeta}
$$

- a = 2.49844027746819
- b = 0.6766125007389536

- c_0 = 17.62639820170009
- c_1 = -32.25138311160568
- c_2 = 32.08544081666421
- c_3 = -21.25435028760934
- c_4 = 9.361475163283558
- c_5 = -2.2592738183690266
