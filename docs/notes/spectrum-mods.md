You’ve basically sketched a really clean, scalable architecture. Let me tighten it into something “implementation‑ready” and highlight a couple of subtle knobs you can exploit.

1. Baseline family and neutral tying

For unstable humidity

\phi_q^{u}(\zeta)=\alpha_q(1-b_q\zeta)^{-1/\lambda_q},\quad \zeta<0,


neutral consistency forces \(\alpha_q=1\), and

\left.\frac{d\phi_q^u}{d\zeta}\right|_{0^-}=\frac{b_q}{\lambda_q}.


Stable near‑neutral

\phi_q^s(\zeta)\approx 1+\beta_q\zeta,\quad \zeta>0,


with \(C^1\) at \(\zeta=0\) gives

\beta_q=\frac{b_q}{\lambda_q}.


So your “Businger–Dyer‑like” vs “momentum‑like” axis is exactly:

• Heat/moisture‑like: \(\lambda_q=2,\; b_q=16\Rightarrow \phi_q^u=(1-16\zeta)^{-1/2},\; \beta_q=8.\)
• Momentum‑like: \(\lambda_q=4,\; b_q=16\Rightarrow \phi_q^u=(1-16\zeta)^{-1/4},\; \beta_q=4.\)
• Free family: treat \(\lambda_q\) (and possibly \(b_q\)) as fit parameters, with \(\beta_q=b_q/\lambda_q\) tied.


That gives you a very interpretable model‑selection axis: fixed \(\lambda_q\in\{2,4\}\) vs free \(\lambda_q\), with the neutral slope as the diagnostic.

2. Smooth blend vs piecewise baseline

Your “one function to rule them all” blend

\phi_{x,\text{base}}(\zeta)=(1-s(\zeta))\phi_x^u(\zeta)+s(\zeta)\phi_x^s(\zeta),
\quad
s(\zeta)=\frac{1}{2}\left(1+\tanh\frac{\zeta}{\delta}\right)


is nice because:

• Near neutral: if \(\phi_x^u,\phi_x^s\) are both \(C^1\) and tied at 0, then \(\phi_{x,\text{base}}\) is automatically \(C^1\) for any \(\delta\).
• Control knob: \(\delta\) becomes a “transition sharpness” parameter you can either fix (e.g. from canonical MOST intuition) or fit with a weak prior.


Your step 4—comparing this smooth blend to a hard piecewise baseline with explicit continuity penalty—is exactly the right experiment. I’d also log the implied “effective” neutral slope from each fit and see how it clusters across regimes/sites.

3. Transform and ultraspherical residual

The map

\xi(\zeta)=\tanh\!\left(a\,\operatorname{asinh}\!\left(\frac{\zeta}{\zeta_0}\right)\right),\quad \xi\in(-1,1),


gives you:

• Local: \(\xi\sim (a/\zeta_0)\zeta\) near 0 → clean control of neutral derivatives.
• Global: logarithmic tails via \(\operatorname{asinh}\), then bounded via \(\tanh\) → good for a single orthogonal basis across strongly unstable to HSNBL.


Residual:

\Delta\phi_{x,\text{ultra}}(\zeta)=\sum_{n=0}^{N} c_n\,C_n^{(\lambda_*)}\!(\xi(\zeta)).


If you want neutral constraints built in, a simple construction is:

\Delta\phi_{x,\text{ultra}}(\zeta)
=
\xi(\zeta)^2
\sum_{n=0}^{N} \tilde c_n\,C_n^{(\lambda_*)}\!(\xi(\zeta)),


since \(\xi(0)=0\) and \(\xi^\prime (0)\neq 0\) give \(\Delta\phi(0)=0\), \(\Delta\phi^\prime(0)=0\) automatically. Then you don’t need explicit neutral constraints in the optimizer for the residual—only for the baseline.

Choice of \(\lambda_*\) can be:

• Legendre: \(\lambda_*=\frac12\) for simplicity and existing numerics.
• Tuned: pick \(\lambda_*\) to match the effective weight \(w(\xi)=(1-\xi^2)^{\lambda_*-1/2}\) to your empirical density in \(\xi\) (e.g. via a rough moment match).


4. Loss and identifiability

Your proposed loss

\mathcal{L}=\text{RMSE}+\eta_0(\phi(0)-1)^2+\eta_1(\phi^\prime(0^-)-\phi^\prime(0^+))^2


is a good starting point. A couple of refinements you might consider:

• Parameter tying vs penalty: for the baseline, I’d prefer hard tying (\(\alpha=1\), \(\beta=b/\lambda\)) and use the continuity penalty mainly to keep the total \(\phi\) smooth when the residual is active.
• Regularization on residual: add \(\eta_{\text{ultra}}\sum_n n^p c_n^2\) (e.g. \(p=2\)) to discourage high‑order wiggles unless strongly demanded by data.
• Shared transform: as you suggested, fit \(a,\zeta_0\) shared across \(m,h,q\). That forces the ultraspherical modes to live in a common “geometry” and makes cross‑variable comparisons of modal content meaningful.


5. Convolution / interaction lens

Your convolution remark is exactly the right mental model: if

\phi_x(\xi)=\sum_n c_n C_n^{(\lambda_*)}(\xi),\quad
\phi_y(\xi)=\sum_m d_m C_m^{(\lambda_*)}(\xi),


then products like \(\phi_x\phi_y\) expand via Gegenbauer linearization coefficients

C_n^{(\lambda_*)}(\xi)C_m^{(\lambda_*)}(\xi)
=
\sum_k L_{nmk}^{(\lambda_*)} C_k^{(\lambda_*)}(\xi),


so interaction terms correspond to structured cross‑mode coupling in coefficient space. That’s a really nice way to interpret “nonlinear similarity” corrections or flux‑ratio models.

---

If you want, next step we can:

• Write down a concrete parameter vector for experiment (1)–(4) and a minimal fitting pipeline (e.g. which parameters global vs site‑specific vs regime‑specific).
• Or derive explicit expressions for \(\phi^\prime(0^\pm)\) for the full baseline+ultra model under the \(\xi\) map, so you can monitor continuity analytically rather than numerically.