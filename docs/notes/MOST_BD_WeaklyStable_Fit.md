# MOST Branch Fitting: Businger-Dyer And Weakly Stable Continuation

This note documents the branch-fitting convention used by [src/julia/fit_most_profiles.jl](src/julia/fit_most_profiles.jl).

## Purpose

The script is intended for preprocessed CSV inputs that already contain at least:

- `zeta`
- `phi_m`
- `phi_h`
- optionally `phi_q`

It fits:

- an unstable Businger-Dyer style branch for `zeta < 0`
- a weakly stable branch for `0 < Ri < Ri_c`
- an implicit near-neutral join by matching value and slope at neutral

It does not fit the strongly stable branch. That remains the domain of the existing Grachev and ultraspherical paths.

## Unstable Branch

The unstable branch is written as

$$
\phi_u(\zeta) = (1 - b\,\zeta)^{-1/\lambda}, \qquad \zeta < 0.
$$

Two families are supported:

- `BD_CLASSIC`: fit `b` only and keep `lambda` fixed by tracer convention
- `BD_PL`: fit both `b` and `lambda`

Default tracer conventions follow the existing registry in [src/julia/tracer_registry.jl](src/julia/tracer_registry.jl):

- momentum: `lambda = 4`
- heat and scalar-like tracers: `lambda = 2`

## Weakly Stable Branch

The weakly stable continuation is fit as

$$
\phi_{ws}(R) = 1 + s_0 R + c_2 R^2,
$$

with

$$
s_0 = \frac{b}{\lambda}.
$$

Here `R` is the available Richardson-number driver. If the input CSV does not provide a Richardson-number column, the script falls back to `zeta` on the stable side. Near neutral this is acceptable because $Ri \approx \zeta$ to leading order.

This construction enforces:

- `phi(0) = 1`
- a matched first derivative at neutral to leading order

So the unstable and weakly stable branches join with an approximate $C^1$ tie at neutral.

## Thickness Scale

The matched neutral slope implies an intrinsic thickness scale

$$
Ri_{thick} = \frac{1}{s_0} = \frac{\lambda}{b}.
$$

For momentum, where `lambda = 4`, this becomes

$$
Ri_{thick} = \frac{4}{b}.
$$

That is the origin of the `4/b` relation referenced in discussion. It is not a replacement for the regime threshold `Ri_c`; it is a slope-derived transition thickness implied by the unstable fit.

Interpretation:

- `Ri_c` is the user-chosen regime boundary between weakly and strongly stable flow
- `Ri_thick` is the neutral-tie thickness implied by the fitted unstable branch

When `Ri_thick` and `Ri_c` are similar, the unstable neutral slope and the chosen weakly-stable regime width are mutually consistent.

## Current Limitation

Current SHEBA rich preprocess files are still stable-only, so [src/julia/fit_most_profiles.jl](src/julia/fit_most_profiles.jl) will report `default_no_unstable_data` for the unstable branch on those files. That is expected until unstable rows are retained in [src/julia/preprocess_sheba_main.jl](src/julia/preprocess_sheba_main.jl).