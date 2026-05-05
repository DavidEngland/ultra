# Multi-Tracer Preprocess Summary

## Source

- input: runs/20260504_varrio_multitracer/input/varrio_public_overlap_raw.csv
- mode: raw
- stable_only: true  unstable_only: false

## Geometry and Thresholds

- z_m=16.6  d_m=0.0  z_eff=16.6
- wtv_eps=1.0e-12  Ri_c=0.25  ζ_neutral=0.1

## Row Accounting

- total rows read: 47232
- rows written: 19454
- near-neutral transitions flagged: 0

## Regime Counts  (Ri_c = 0.25)

- Unstable  (ζ < 0): 0
- Near-neutral  (|ζ| ≤ 0.1): 15836
- Weakly stable  (0 < ζ, Ri < Ri_c): 2195
- Strongly stable  (Ri ≥ Ri_c): 1423

## ζ Distribution

- range: [0.0, 495.079]
- quantiles 5/50/95%: 0.0012 / 0.0165 / 0.4267

## φ by Tracer

  - Momentum  φ_m:  n_finite=16802  q50=2.655  [q05=1.967, q95=5.008]
  - Heat  φ_h:  n_finite=17565  q50=12.843  [q05=-5.75, q95=127.154]
  - humidity:  n_finite=17229  q50=0.319  [q05=-8.473, q95=7.319]
  - CO2:  n_finite=7346  q50=-16.059  [q05=-144.064, q95=91.768]

## Sign Convention Reminders

- Momentum  φ_m: phi_m is always positive; u_* is always positive — no sign ambiguity.
- Heat  φ_h: θ_* = −w′θ_v′/u_* (positive in stable). Check that your sonic has the correct sign for w′θ_v′.
- humidity: Verify sign convention: both the turbulent flux w′q1′ and the mean gradient dq1/dz must be checked.
- CO2: Verify sign convention: both the turbulent flux w′q2′ and the mean gradient dq2/dz must be checked.

## Artifacts

- data CSV: runs/20260504_varrio_multitracer/input/varrio_multitracer_input.csv
- regime stats: runs/20260504_varrio_multitracer/input/varrio_multitracer_input_regime_stats.csv
- tracer inventory: runs/20260504_varrio_multitracer/input/varrio_multitracer_input_tracer_inventory.csv  /  runs/20260504_varrio_multitracer/input/varrio_multitracer_input_tracer_inventory.md
- summary: runs/20260504_varrio_multitracer/input/varrio_multitracer_input_preprocess_summary.md
