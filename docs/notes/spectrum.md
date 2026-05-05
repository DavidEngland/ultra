This is a strong direction. You are basically describing a unified spectral closure with a physics-informed baseline and an orthogonal correction that works across USL to HSNBL.

**Recommended Core idea**
Use
$$
\phi_x(\zeta)=\phi_{x,\text{base}}(\zeta)+\Delta\phi_{x,\text{ultra}}(\zeta),
$$
with \(x\in\{m,h,q\}\), where baseline handles canonical MOST shape and ultraspherical/Legendre handles residual structure.

For unstable humidity:
$$
\phi_q^{u}(\zeta)=\alpha_q\,(1-b_q\zeta)^{-1/\lambda_q},\quad \zeta<0.
$$
Neutral consistency gives \(\alpha_q=1\).
Neutral slope on unstable side is
$$
\left.\frac{d\phi_q^u}{d\zeta}\right|_{0^-}=\frac{b_q}{\lambda_q}.
$$
If stable near-neutral is \(\phi_q^s\approx 1+\beta_q\zeta\), then \(C^1\) at \(\zeta=0\) implies
$$
\beta_q=\frac{b_q}{\lambda_q}.
$$
So your \(\beta_q=b_q/4\) is exactly the \(\lambda_q=4\) special case.

**Useful special cases**
- Heat/moisture Businger-Dyer-like: \(\lambda_q=2,\; b_q=16 \Rightarrow \phi_q=(1-16\zeta)^{-1/2}\), slope \(=8\).
- Momentum-like: \(\lambda=4,\; b=16 \Rightarrow (1-16\zeta)^{-1/4}\), slope \(=4\).

That gives a clean model-selection axis: free \(\lambda_q\) vs fixed \(2\) vs fixed \(4\).

**“One function to rule them all”**
You can do this without hard breaking at 0 by blending unstable/stable baselines smoothly:
$$
\phi_{x,\text{base}}(\zeta)=\bigl(1-s(\zeta)\bigr)\phi_x^u(\zeta)+s(\zeta)\phi_x^s(\zeta),
\quad
s(\zeta)=\frac{1}{2}\left(1+\tanh\frac{\zeta}{\delta}\right).
$$
Then enforce \(C^1\) either by parameter tying (\(\beta=b/\lambda\)) or with a penalty term during fitting.

**Transform is the key (agree)**
For a single orthogonal basis across strongly unstable to HSNBL, use a map that is linear near 0 and logarithmic in both tails:
$$
\xi(\zeta)=\tanh\!\left(a\,\operatorname{asinh}\!\left(\frac{\zeta}{\zeta_0}\right)\right).
$$
Why this helps:
- Near neutral: \(\xi\sim a\zeta/\zeta_0\) (good for derivative control).
- Large \(|\zeta|\): \(\operatorname{asinh}\) behaves like \(\log|\zeta|\), so both tails compress well.
- One bounded domain \(\xi\in(-1,1)\) for orthogonal polynomials.

Then residual:
$$
\Delta\phi_{x,\text{ultra}}(\zeta)=\sum_{n=0}^{N} c_n\,C_n^{(\lambda_*)}\!\bigl(\xi(\zeta)\bigr).
$$
If you want neutral constraints preserved by construction, enforce:
$$
\Delta\phi(0)=0,\qquad \Delta\phi'(0)=0,
$$
either by constrained solve or by multiplying correction with a neutral-killing factor (for example proportional to \(\xi^2\)).

**Your convolution insight is right**
Product terms in physical space map to modal convolution in polynomial space via Gegenbauer linearization coefficients. That is exactly the right lens for interpreting interaction terms as cross-mode coupling.

**Practical next experiment set**
1. Unstable \(q\): compare \(\lambda_q\in\{2,4,\text{free}\}\) with \(C^1\)-tied stable slope.
2. Fit baseline+ultra for \(m,h,q\) with same \(\xi(\zeta)\) map.
3. Add continuity penalty at neutral:
$$
\mathcal{L}=\text{RMSE}+\eta_0(\phi(0)-1)^2+\eta_1\bigl(\phi'(0^-)-\phi'(0^+)\bigr)^2.
$$
4. Compare piecewise vs smooth-blend baseline; pick by blocked test RMSE and continuity diagnostics.

Turn this into a concrete fitting template (parameter list + objective + constraints) so you can drop it directly into the current Julia workflow.