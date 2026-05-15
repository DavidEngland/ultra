### Legendre coefficients \(A_1, A_2\) for Businger–Dyer profiles

Let’s first do this cleanly in **three steps**:
1) map the physical profile to the Legendre coordinate,
2) express \(A_1, A_2\) in terms of physical derivatives,
3) plug in Businger–Dyer (BD) \(\phi_m,\phi_h\).

---

### 1. Geometry: mapping \(z \leftrightarrow x\) and derivatives

Define the spectral coordinate \(x \in [-1,1]\) over a grid cell of thickness \(\Delta z\) centered at \(z_0\):
\[
z = z_0 + \frac{\Delta z}{2} x.
\]

Then, for any mean field \(f(z)\) (e.g. \(U,\Theta\)):
\[
f(x) = f\!\left(z_0 + \tfrac{\Delta z}{2}x\right).
\]

Derivatives transform as:
- **First derivative at the midpoint**:
  \[
  \left.\frac{\partial f}{\partial x}\right|_{x=0}
  = \frac{\Delta z}{2}\left.\frac{\partial f}{\partial z}\right|_{z=z_0}
  \]
- **Second derivative at the midpoint**:
  \[
  \left.\frac{\partial^2 f}{\partial x^2}\right|_{x=0}
  = \left(\frac{\Delta z}{2}\right)^2
    \left.\frac{\partial^2 f}{\partial z^2}\right|_{z=z_0}.
  \]

With the truncated Legendre expansion
\[
f(x) = A_0 P_0(x) + A_1 P_1(x) + A_2 P_2(x),
\]
we have at \(x=0\):
\[
f'(0) = A_1,\qquad f''(0) = 3A_2.
\]

So:
\[
A_1 = \left.\frac{\partial f}{\partial x}\right|_{0}
    = \frac{\Delta z}{2} f_z'(z_0),
\]
\[
A_2 = \frac{1}{3}\left.\frac{\partial^2 f}{\partial x^2}\right|_{0}
    = \frac{1}{3}\left(\frac{\Delta z}{2}\right)^2 f_z''(z_0).
\]

Hence the **ratio** that enters \(\chi\) is:
\[
\frac{A_2}{A_1}
= \frac{\left(\frac{\Delta z}{2}\right)^2 f_z''/3}{\left(\frac{\Delta z}{2}\right) f_z'}
= \frac{\Delta z}{6}\,\frac{f_z''}{f_z'}\Bigg|_{z_0}.
\]

This is the key simplification:
\[
\boxed{\displaystyle
\frac{A_2^{(f)}}{A_1^{(f)}} = \frac{\Delta z}{6}\,\frac{f''(z_0)}{f'(z_0)}
}
\]

---

### 2. MOST + BD: derivatives of \(U(z)\) and \(\Theta(z)\)

Work in standard MOST form with displacement height \(d\) and Obukhov length \(L\):
\[
\zeta = \frac{z-d}{L}.
\]

For momentum:
\[
\frac{\partial U}{\partial z}
= \frac{u_*}{\kappa (z-d)}\,\phi_m(\zeta).
\]

For heat:
\[
\frac{\partial \Theta}{\partial z}
= \frac{\theta_*}{\kappa (z-d)}\,\phi_h(\zeta).
\]

We need the **second derivatives**. Differentiate w.r.t. \(z\):

#### 2.1 General form for \(U''(z)\)

Let
\[
g_m(z) = \frac{\phi_m(\zeta)}{z-d},\quad \zeta = \frac{z-d}{L}.
\]

Then
\[
\frac{\partial U}{\partial z} = \frac{u_*}{\kappa} g_m(z),
\]
\[
\frac{\partial^2 U}{\partial z^2}
= \frac{u_*}{\kappa} g_m'(z).
\]

Compute \(g_m'(z)\):
\[
g_m'(z)
= \frac{(z-d)\,\phi_m'(\zeta)\,\frac{\partial \zeta}{\partial z} - \phi_m(\zeta)}{(z-d)^2}
= \frac{(z-d)\,\phi_m'(\zeta)\,\frac{1}{L} - \phi_m(\zeta)}{(z-d)^2}.
\]

So:
\[
\frac{\partial^2 U}{\partial z^2}
= \frac{u_*}{\kappa}
  \frac{(z-d)\,\phi_m'(\zeta)/L - \phi_m(\zeta)}{(z-d)^2}.
\]

The **ratio** at \(z_0\) is:
\[
\frac{U''(z_0)}{U'(z_0)}
= \frac{\frac{u_*}{\kappa}\frac{(z_0-d)\phi_m'(\zeta_0)/L - \phi_m(\zeta_0)}{(z_0-d)^2}}
       {\frac{u_*}{\kappa}\frac{\phi_m(\zeta_0)}{(z_0-d)}}
= \frac{(z_0-d)\phi_m'(\zeta_0)/L - \phi_m(\zeta_0)}
       {(z_0-d)\phi_m(\zeta_0)}.
\]

Using \(\zeta_0 = (z_0-d)/L\):
\[
\boxed{\displaystyle
\frac{U''(z_0)}{U'(z_0)}
= \frac{\zeta_0\,\phi_m'(\zeta_0) - \phi_m(\zeta_0)}
       {(z_0-d)\,\phi_m(\zeta_0)}
}
\]

#### 2.2 General form for \(\Theta''(z)\)

Exactly analogously:
\[
\frac{\partial \Theta}{\partial z}
= \frac{\theta_*}{\kappa (z-d)}\,\phi_h(\zeta),
\]
\[
\frac{\partial^2 \Theta}{\partial z^2}
= \frac{\theta_*}{\kappa}
  \frac{(z-d)\,\phi_h'(\zeta)/L - \phi_h(\zeta)}{(z-d)^2},
\]
so
\[
\boxed{\displaystyle
\frac{\Theta''(z_0)}{\Theta'(z_0)}
= \frac{\zeta_0\,\phi_h'(\zeta_0) - \phi_h(\zeta_0)}
       {(z_0-d)\,\phi_h(\zeta_0)}
}
\]

---

### 3. \(A_1, A_2\) for BD: stable case (clean closed form)

Let’s first do **stable Businger–Dyer**, where the algebra collapses nicely.

For stable conditions, BD typically uses:
\[
\phi_m(\zeta) = 1 + \beta_m \zeta,\qquad
\phi_h(\zeta) = 1 + \beta_h \zeta,\qquad \zeta>0,
\]
with constants \(\beta_m,\beta_h\) (e.g. \(\beta_m\approx 5,\beta_h\approx 5\) in classic BD).

Then:
\[
\phi_m'(\zeta) = \beta_m,\qquad
\phi_h'(\zeta) = \beta_h.
\]

Plug into the general ratios.

#### 3.1 Momentum

\[
\frac{U''}{U'}(z_0)
= \frac{\zeta_0 \beta_m - (1+\beta_m\zeta_0)}
       {(z_0-d)(1+\beta_m\zeta_0)}
= \frac{-1}{(z_0-d)(1+\beta_m\zeta_0)}.
\]

So:
\[
\boxed{\displaystyle
\frac{A_2^{(U)}}{A_1^{(U)}}
= \frac{\Delta z}{6}\,\frac{U''(z_0)}{U'(z_0)}
= -\frac{\Delta z}{6}\,
  \frac{1}{(z_0-d)\,[1+\beta_m\zeta_0]}
}
\]

#### 3.2 Temperature

Similarly:
\[
\frac{\Theta''}{\Theta'}(z_0)
= \frac{\zeta_0 \beta_h - (1+\beta_h\zeta_0)}
       {(z_0-d)(1+\beta_h\zeta_0)}
= \frac{-1}{(z_0-d)(1+\beta_h\zeta_0)},
\]
so
\[
\boxed{\displaystyle
\frac{A_2^{(\Theta)}}{A_1^{(\Theta)}}
= -\frac{\Delta z}{6}\,
  \frac{1}{(z_0-d)\,[1+\beta_h\zeta_0]}
}
\]

And the **first‑order coefficients** themselves are:
\[
A_1^{(U)} = \frac{\Delta z}{2}\,U'(z_0)
= \frac{\Delta z}{2}\,\frac{u_*}{\kappa(z_0-d)}\,[1+\beta_m\zeta_0],
\]
\[
A_1^{(\Theta)} = \frac{\Delta z}{2}\,\Theta'(z_0)
= \frac{\Delta z}{2}\,\frac{\theta_*}{\kappa(z_0-d)}\,[1+\beta_h\zeta_0].
\]

For completeness, the second‑order coefficients:
\[
A_2^{(U)} = \frac{\Delta z}{6}\,A_1^{(U)}\,\frac{U''}{U'}
= -\left(\frac{\Delta z}{2}\right)^2
   \frac{u_*}{6\kappa(z_0-d)^2},
\]
\[
A_2^{(\Theta)} = -\left(\frac{\Delta z}{2}\right)^2
   \frac{\theta_*}{6\kappa(z_0-d)^2},
\]
where the BD stability dependence is carried by the \(A_1\) factors.

---

### 4. General BD (unstable) forms: plug‑and‑play

For **unstable** BD, you can drop in the standard forms, e.g.
\[
\phi_m(\zeta) = (1 - \gamma_m \zeta)^{-1/4},\qquad
\phi_h(\zeta) = \text{Pr}_0\,(1 - \gamma_h \zeta)^{-1/2},\qquad \zeta<0,
\]
with \(\gamma_m,\gamma_h>0\) and \(\text{Pr}_0\) the neutral Prandtl number.

Then:
\[
\phi_m'(\zeta)
= \frac{\gamma_m}{4}(1-\gamma_m\zeta)^{-5/4},
\]
\[
\phi_h'(\zeta)
= \frac{\text{Pr}_0\,\gamma_h}{2}(1-\gamma_h\zeta)^{-3/2}.
\]

You just plug these into the general ratios:
\[
\frac{U''}{U'}(z_0)
= \frac{\zeta_0\,\phi_m'(\zeta_0) - \phi_m(\zeta_0)}
       {(z_0-d)\,\phi_m(\zeta_0)},
\quad
\frac{\Theta''}{\Theta'}(z_0)
= \frac{\zeta_0\,\phi_h'(\zeta_0) - \phi_h(\zeta_0)}
       {(z_0-d)\,\phi_h(\zeta_0)},
\]
and then
\[
\frac{A_2^{(U)}}{A_1^{(U)}} = \frac{\Delta z}{6}\frac{U''}{U'}(z_0),
\quad
\frac{A_2^{(\Theta)}}{A_1^{(\Theta)}} = \frac{\Delta z}{6}\frac{\Theta''}{\Theta'}(z_0).
\]

That gives you **closed‑form \(A_1,A_2\)** for any BD flavor you like.

---

### 5. Curvature parameter (\(\chi\)) in terms of BD functions

Using your spectral definition:
\[
\chi = 3\left(\frac{A_2^{(\Theta)}}{A_1^{(\Theta)}} - 2\frac{A_2^{(U)}}{A_1^{(U)}}
\right),
\]
and the general ratio formula, we get:
\[
\chi = 3\cdot\frac{\Delta z}{6}
\left(\frac{\Theta''}{\Theta'}(z_0) - 2\frac{U''}{U'}(z_0)\right)= \frac{\Delta z}{2}
\left(\frac{\Theta''}{\Theta'}(z_0) - 2\frac{U''}{U'}(z_0)
\right).
\]

So in **fully general MOST+BD form**:
\[
\chi = \frac{\Delta z}{2(z_0-d)}\left[\frac{\zeta_0\,\phi_h'(\zeta_0) - \phi_h(\zeta_0)}{\phi_h(\zeta_0)} - 2\frac{\zeta_0\,\phi_m'(\zeta_0) - \phi_m(\zeta_0)}{\phi_m(\zeta_0)}
\right]
\]

For **stable BD** with \(\phi_m=1+\beta_m\zeta,\phi_h=1+\beta_h\zeta\), this simplifies to:
\[
\chi = \frac{\Delta z}{2(z_0-d)}
\left[\frac{2}{1+\beta_m\zeta_0}-\frac{1}{1+\beta_h\zeta_0}
\right].
\]

That’s a very compact, implementation‑ready expression.

