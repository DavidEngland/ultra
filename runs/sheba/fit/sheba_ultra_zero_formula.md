# SHEBA Fitted Function (Zero Baseline + Ultraspherical)

$$
\phi(\zeta) = \phi_{base}(\zeta) + \Delta\phi_{ultra}(\zeta)
$$

xi-mapping: tanh(alpha * log1p(zeta)),  alpha = 1.7427953628298036

$$
\Delta\phi_{ultra}(\zeta) = \sum_{n=0}^{6} c_n C_n^{(\lambda_*)}(\xi(\zeta))
$$

- lambda_* = 0.25

Zero baseline:

$$
\phi_{base}(\zeta) = 0
$$

- c_0 = 1.3185223804715362
- c_1 = 3.460085956728704
- c_2 = 2.8806009805544757
- c_3 = 0.8943489402886594
- c_4 = 1.0953766211607543
- c_5 = 1.018548120765397
- c_6 = 0.6702198204626669
