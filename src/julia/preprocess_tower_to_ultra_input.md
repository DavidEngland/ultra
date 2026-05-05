This Julia script is a **data preprocessing engine** designed to transform raw meteorological tower observations into a standardized format for Monin-Obukhov Similarity Theory (MOST) analysis. It is specifically built to prepare data for "Ultraspherical" fitting — a method used to improve turbulence closure models in stable and near-neutral boundary layers.

---

### 1. Geometric and Physical Constants
The script relies on the fundamental constants of the Surface Layer:
* **Von Kármán constant ($\kappa \approx 0.4$):** The empirical proportionality constant relating vertical wind shear to surface friction. It appears in every MOST flux-gradient relationship.
* **Effective height ($z_\mathrm{eff}$):** Calculated as $z_m - d_m$, where $z_m$ is the measurement height and $d_m$ is the zero-plane displacement height (non-zero above rough surfaces such as forest canopies). This is the height above the apparent momentum sink, not above the ground.

---

### 2. The Three Operating Modes
The script supports three ways to acquire or calculate the required gradients:
1.  **`raw` mode:** Reads pre-computed gradients (e.g. $dU/dz$) directly from the CSV.
2.  **`two-level` mode:** Estimates gradients from measurements at two heights $z_1 < z_2$:
    $$\frac{dU}{dz} \approx \frac{U_2 - U_1}{z_2 - z_1}$$
    This finite-difference approximation is valid when the layer is thin and the profile is approximately linear over the interval.
3.  **`api-smear` mode:** Fetches data automatically from the **SmartSMEAR API** (Station for Measuring Ecosystem-Atmosphere Relations, Finland), handling download and ingestion in one step.

---

### 3. Core Calculations (MOST)

#### Friction velocity ($u_*$)
The friction velocity characterises the intensity of turbulent momentum exchange at the surface. It is derived from the two horizontal components of the turbulent momentum flux (Reynolds stresses):

$$\frac{\tau}{\rho} = \sqrt{\overline{u'w'}^2 + \overline{v'w'}^2}$$

The friction velocity is then $u_* \equiv \sqrt{\tau/\rho}$, which combines the two steps into a single expression:

$$\boxed{u_* = \left(\overline{u'w'}^2 + \overline{v'w'}^2\right)^{1/4}}$$

The **4th root** is not a typo. It arises because:
1. The stress magnitude $\tau/\rho$ is the Euclidean norm of the 2-D flux vector — a square root of sum of squares.
2. Then $u_* = \sqrt{\tau/\rho}$ takes another square root.

Composing both steps gives the 4th root. When only the streamwise flux is available (i.e. $\overline{v'w'} \approx 0$ in a well-aligned sonic), this reduces to the familiar $u_* = |\overline{u'w'}|^{1/2}$.

#### Obukhov length ($L$)
The Obukhov length $L$ is the height above the surface at which buoyant production of turbulence equals mechanical (shear) production:

$$L = -\frac{u_*^3 \,\bar{\theta}_v}{\kappa\, g\, \overline{w'\theta_v'}}$$

where $\bar{\theta}_v$ is the mean virtual potential temperature (K), $g$ is gravitational acceleration, and $\overline{w'\theta_v'}$ is the kinematic virtual heat flux (K m s$^{-1}$). The leading minus sign ensures the conventional sign:
* $L > 0$: stable (surface cooling, $\overline{w'\theta_v'} < 0$, turbulence suppressed by buoyancy).
* $L < 0$: unstable (surface heating, $\overline{w'\theta_v'} > 0$, turbulence enhanced by buoyancy).
* $|L| \to \infty$: near-neutral (flux vanishes; the script guards against division by zero using a threshold `wtv_eps`).

#### Stability parameter ($\zeta$)
The dimensionless stability parameter normalises height by the Obukhov length:

$$\zeta = \frac{z_\mathrm{eff}}{L}$$

This is the central independent variable for all MOST functions $\phi(\zeta)$.

---

### 4. Dimensionless Gradients ($\phi$)
MOST postulates that, when non-dimensionalised appropriately, turbulent flux-gradient relationships collapse to universal functions of $\zeta$ alone. These are the targets for the Ultraspherical fit.

#### Friction temperature ($\theta_*$)
Before writing the $\phi$ equations, note the **friction temperature**:

$$\theta_* = -\frac{\overline{w'\theta_v'}}{u_*}$$

It plays the same role for heat that $u_*$ plays for momentum — it scales the temperature profile in the surface layer. The sign convention makes $\theta_* > 0$ in stable conditions.

#### Momentum ($\phi_m$)

$$\phi_m(\zeta) = \frac{\kappa\, z_\mathrm{eff}}{u_*} \frac{dU}{dz}$$

In neutral conditions ($\zeta = 0$), MOST requires $\phi_m = 1$, recovering the classical log-law $dU/dz = u_*/(\kappa z)$.

#### Heat / scalars ($\phi_h$)

$$\phi_h(\zeta) = \frac{\kappa\, z_\mathrm{eff}}{\theta_*} \frac{d\theta_v}{dz}$$

Similarly, $\phi_h(0) = 1$ (or Pr$_t^{-1}$ depending on the convention; the script uses the neutral-limit-unity convention).

---

### 5. Robustness Features
* **Near-neutral guard:** A threshold `wtv_eps` on $|\overline{w'\theta_v'}|$ prevents $L \to \infty$ from causing numerical issues.
* **Column aliasing:** Maps common variant names (`u_star`, `ustar`, `uStar`, …) to internal variable names, so the script can handle data from different instruments and logging software without manual renaming.
* **Output artefacts:** Alongside the processed CSV, the script writes a Markdown summary report and a statistics file showing how many rows were retained, filtered for quality, or dropped at each stage.

---

### How to use it
To process a tower file and retain only stable data for momentum analysis:
```bash
julia preprocess_tower_to_ultra_input.jl tower_data.csv ultra_input.csv 10.0 0.0 --stable-only --phi=phi_m
```
Arguments: input CSV, output CSV, measurement height $z_m$ (m), displacement height $d_m$ (m).
