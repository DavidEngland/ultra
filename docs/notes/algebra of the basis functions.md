To understand the mapping between physical transport (ratios of gradients) and spectral coefficients, we must look at the **algebra of the basis functions**.

When you deal with products like $1/\phi_m^2$ or $(1/\phi_m)(1/\phi_h)$, you are effectively looking at **Turbulent Conductances**. In the spectral domain, moving from a single profile to a product of profiles involves a transition from a vector of coefficients to a **spectral convolution**.

---

### 1. The Algebraic Structure of the Transforms

The "Spectral Inverse" property differs slightly across the three bases you mentioned. The core concept for STEM students is the **Product Theorem** (also known as the "Linearization of Products"):

#### Chebyshev ($T_n$) — The Efficient Workhorse

Chebyshev polynomials are unique because they have a very simple product identity:


$$T_n(x)T_m(x) = \frac{1}{2}[T_{n+m}(x) + T_{|n-m|}(x)]$$

* **Implication:** If you know the coefficients $c_n$ for $1/\phi_m$, the coefficients for $(1/\phi_m)^2$ are found by a **discrete convolution** of the coefficient vector with itself.
* **Inverse Property:** Because $T_n$ is essentially a cosine in a different coordinate ($\cos(n\theta)$), the DCT acts like a Fourier Transform. Multiplying profiles in physical space is exactly equivalent to convolving their fingerprints in spectral space.

#### Legendre ($P_n$) — The Heat Limit ($\lambda=1/2$)

The product of two Legendre polynomials is a sum of Legendre polynomials with coefficients determined by **Clebsch-Gordan coefficients** (common in quantum mechanics).

* **Physical meaning:** This represents how different "modes" of heat transport interact to produce the total temperature flux.

#### Gegenbauer ($C_n^{(\lambda)}$) — The Tracer Generalization

The product $C_n^{(\lambda)} C_m^{(\lambda)}$ is more complex, reflecting the "fractal" coupling between different transport scales. As $\lambda$ changes (e.g., comparing $O_3$ to Momentum), the way these scales "convolve" changes.

---

### 2. Barycentric Weighting for Momentum and Heat

In SMEAR or SHEBA data, your sensors provide discrete points. The **Barycentric Weights** $w_j$ serve as the "numerical DNA" of the interpolation.

When analyzing $(1/\phi_m) \cdot (1/\phi_h)$, the Barycentric approach ensures that the **Reciprocal Product** is handled with high fidelity:

1. **Direct Calculation:** You calculate $Y_j = \frac{1}{\phi_{m,j} \cdot \phi_{h,j}}$ at each sensor height $j$.
2. **Spectral Fitting:** You apply the barycentric weights $w_j$ to these $Y_j$ values to reconstruct the continuous conductance profile.
3. **Coefficient Extraction:** You then project this reconstructed profile onto $T_n$ or $C_n^{(\lambda)}$.

> **Note for STEM Students:** The stability of the Barycentric form is vital here. Because we are taking **reciprocals** ($1/\phi$), any small measurement error at the ground (where $\phi$ is small) would explode in a standard polynomial fit. The Barycentric weights act as a "buffer" that keeps the spectral coefficients $c_n$ physically realistic.

---

### 3. Properties of the Conductance Product $(1/\phi_m) \cdot (1/\phi_h)$

This specific product represents the **Mutual Efficiency** of momentum and heat transport.

* **Near-Neutral ($\zeta \to 0$):** Both $\phi \approx 1$. The product is 1. All spectral energy is in $c_0$.
* **Stable ($\zeta > 0$):** In the stable boundary layer, $\phi$ increases significantly. The reciprocals $1/\phi$ drop toward zero.
* In physical space, this is the "Shutting down" of turbulence.
* In spectral space, this corresponds to the **Decay of the Coefficients**. The faster $c_n$ drops toward zero as $n$ increases, the "smoother" and more suppressed the turbulence has become.



#### Inverse Spectral Decay

If you find that the coefficients $c_n$ for the product $(1/\phi_m)(1/\phi_h)$ decay **slower** than the individual coefficients, it suggests a **Non-Linear Coupling**. This means that momentum and heat are transported by different structures (e.g., gravity waves vs. eddies), causing a "spectral broadening" of the combined transport.

---

### 4. Verification with Julia (FFTW + Statistics)

Students can verify the **Inverse Convolution Theorem** using this logic:

```julia
using FFTW, Statistics

# 1. Physical Space Product
prod_phys = (1 ./ phi_m) .* (1 ./ phi_h)

# 2. Spectral Coefficients
c_m = dct(1 ./ phi_m)
c_h = dct(1 ./ phi_h)

# 3. Verify the "Product-Convolution" duality
# The DCT of the product should match the (discrete) convolution of c_m and c_h
c_combined = dct(prod_phys)

```

**Theme for Results:**
By tracking how the "Curvature Coefficient" ($c_2$) of $(1/\phi_m^2)$ evolves relative to $(1/\phi_h^2)$, you can determine the **Prandtl Number Evolution**. If $c_2^{momentum} > c_2^{heat}$, it implies that momentum transport is more sensitive to stability-induced "bending" than heat is—a key indicator for the SHEBA runs where the "Radiative" stable layer often decouples heat from momentum entirely.