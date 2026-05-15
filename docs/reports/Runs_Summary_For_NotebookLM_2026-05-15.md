# Ultraspherical ABL Program Run Summary (SHEBA + SMEAR)

**Prepared:** 2026-05-15  
**Repository:** ultra  
**Objective:** Consolidate run outputs across SHEBA and SMEAR into a decision-grade narrative suitable for PDF export and ingestion into NotebookLM.

---

## Executive Summary

This repository now contains two mature analysis streams and one active development stream:

1. **SHEBA modeling stream (high confidence):**
   - DCT two-layer decomposition and ultraspherical residual modeling are internally consistent.
   - Held-out error improvements are robust, especially vs weak baselines.
   - Best all-regime stable fit currently appears to be the **C1-tied unified run** with ~8.74% RMSE gain over the Grachev-C1 baseline.

2. **SMEAR spectral-dynamics stream (medium confidence):**
   - Seasonal DCT fingerprints are reproducible for Varrio temperature-profile inputs.
   - Cross-correlation with flux products is now automated and physically interpretable.
   - Current dead-of-winter sample indicates mostly weakly stable/mixed behavior for available windows (
$Ri_b$ mostly near zero, no laminar $Ri_b > 0.25$ windows in this subset).

3. **Development/sandbox stream (provisional):**
   - Synthetic and test-multi experiments demonstrate method capability, but these are not primary scientific evidence for field conditions.

---

## Confidence Framework

### A. Evidence tiers used in this summary

- **Tier A (Publication-ready internal evidence):** consistent held-out metrics, clear provenance, and physically interpretable outputs.
- **Tier B (Operational but still evolving):** valid outputs with known data-availability or integration caveats.
- **Tier C (Development/sandbox):** useful for method stress-testing, not yet suitable for domain claims.

### B. Key caveat policy

Runs with `status=error` or `no_fingerprints` are treated as **data-availability diagnostics**, not negative scientific results.

---

## SHEBA Program Results (Tier A)

## 1) DCT two-layer structural result

Primary artifact: [runs/sheba/dct_main_file6/report.md](runs/sheba/dct_main_file6/report.md)

- Rows used: **2266**
- Quantile bins: **48**
- DCT modes kept: **8**
- Binned reconstruction RMSE: **0.15298**
- Spectral variance retained: **99.34%**

Interpretation:
- The two-level SHEBA profile is strongly compressible in low-order spectral modes.
- This supports subsequent ultraspherical correction modeling as a compact surrogate representation.

Related figures:
- [runs/sheba/dct_main_file6/plot_sheba_dct_curve.png](runs/sheba/dct_main_file6/plot_sheba_dct_curve.png)
- [runs/sheba/dct_main_file6/plot_sheba_dct_coeffs.png](runs/sheba/dct_main_file6/plot_sheba_dct_coeffs.png)

## 2) Ultraspherical held-out performance

Primary comparison: [runs/sheba/fit/sheba_comparison_summary.md](runs/sheba/fit/sheba_comparison_summary.md)

### Grachev baseline family

From [runs/sheba/fit/sheba_ultra_grachev_report.md](runs/sheba/fit/sheba_ultra_grachev_report.md):

- Baseline RMSE: **0.3411**
- Baseline + ULTRA RMSE: **0.3302**
- Relative gain: **3.19%**

### Zero baseline family

From [runs/sheba/fit/sheba_ultra_zero_report.md](runs/sheba/fit/sheba_ultra_zero_report.md):

- Baseline RMSE: **1.2593**
- Baseline + ULTRA RMSE: **0.3315**
- Relative gain: **73.68%**

Interpretation:
- ULTRA correction adds moderate but stable value over a strong physical baseline.
- ULTRA correction recovers most structure when baseline physics is absent.

### Unified stable-regime variants

- C1 tied variant: [runs/unified_sheba_c1/unified_report.md](runs/unified_sheba_c1/unified_report.md)
  - Relative RMSE gain: **8.74%**
- Free stable-slope variant: [runs/unified_sheba_stable/unified_report.md](runs/unified_sheba_stable/unified_report.md)
  - Relative RMSE gain: **6.06%**
- Log-xi variant: [runs/unified_sheba_logxi/unified_report.md](runs/unified_sheba_logxi/unified_report.md)
  - Relative RMSE gain: **3.26%**

Practical recommendation:
- Use **unified_sheba_c1** as the default reference fit for current external reporting.

---

## SMEAR Program Results (Tier B)

## 1) Seasonal DCT batch status (dead_of_winter)

Batch report: [runs/dct_smear_seasonal_dead_of_winter/report.md](runs/dct_smear_seasonal_dead_of_winter/report.md)  
Per-file status table: [runs/dct_smear_seasonal_dead_of_winter/seasonal_file_summary.csv](runs/dct_smear_seasonal_dead_of_winter/seasonal_file_summary.csv)

Summary:
- Files processed: **8**
- Successful analyses: **2**
- Failed/skipped: **6**

Important distinction:
- Successful runs are concentrated in profile-ready inputs (`temperature_profile`, `dct_temperature_input`).
- Flux-only and non-profile files produce `error`/`no_fingerprints` by design of profile fingerprinting logic.

## 2) Fingerprint × flux coupling (dead_of_winter)

Primary artifact: [runs/dct_smear_seasonal_dead_of_winter/flux_corr/report.md](runs/dct_smear_seasonal_dead_of_winter/flux_corr/report.md)

Coverage:
- Joined rows: **96**
- Flux variables available: **11**
- Correlation pairs: **55**

Strong examples:
- $c_1$ vs $u_*$: $r \approx 0.81$
- $c_4$ vs $u_*$: $r \approx -0.79$
- $c_1$ vs $\tau$: $r \approx -0.76$
- $c_4$ vs $\tau$: $r \approx 0.73$

Interpretation:
- Low-order shape terms correlate strongly with momentum exchange indicators, consistent with dynamic recoupling/decoupling interpretation.

## 3) Cross-correlation and curvature-threshold diagnostics

Temperature-profile subreport: [runs/dct_smear_seasonal_dead_of_winter/varrio_dead_of_winter_temperature_profile/report.md](runs/dct_smear_seasonal_dead_of_winter/varrio_dead_of_winter_temperature_profile/report.md)

Generated artifacts include:
- [runs/dct_smear_seasonal_dead_of_winter/varrio_dead_of_winter_temperature_profile/crosscorr_temp_vs_fc.csv](runs/dct_smear_seasonal_dead_of_winter/varrio_dead_of_winter_temperature_profile/crosscorr_temp_vs_fc.csv)
- [runs/dct_smear_seasonal_dead_of_winter/varrio_dead_of_winter_temperature_profile/plot_crosscorr_temp_vs_fc.png](runs/dct_smear_seasonal_dead_of_winter/varrio_dead_of_winter_temperature_profile/plot_crosscorr_temp_vs_fc.png)
- [runs/dct_smear_seasonal_dead_of_winter/varrio_dead_of_winter_temperature_profile/curvature_at_near_zero_fc_summary.csv](runs/dct_smear_seasonal_dead_of_winter/varrio_dead_of_winter_temperature_profile/curvature_at_near_zero_fc_summary.csv)
- [runs/dct_smear_seasonal_dead_of_winter/varrio_dead_of_winter_temperature_profile/plot_curvature_vs_fc_near_zero.png](runs/dct_smear_seasonal_dead_of_winter/varrio_dead_of_winter_temperature_profile/plot_curvature_vs_fc_near_zero.png)

Current near-zero transport proxy result:
- median curvature metric at near-zero $|F_c|$: **0.4093**

## 4) Bulk Richardson linkage

Ri diagnostics: [runs/dct_smear_seasonal_dead_of_winter/varrio_dead_of_winter_temperature_profile/rib_diagnostics_summary.csv](runs/dct_smear_seasonal_dead_of_winter/varrio_dead_of_winter_temperature_profile/rib_diagnostics_summary.csv)

Current subset:
- $Ri_b$ window count: **96**
- laminar events ($Ri_b > 0.25$): **0**
- $Ri_b$ median: **0.00838**
- $Ri_b$ 90th percentile: **0.02743**

Interpretation:
- This sample is primarily weakly stable/mixed by bulk-Richardson criteria.
- Absence of laminar windows in this slice does not invalidate method; it motivates broader 2012-2025 sweep.

---

## Development and Sandbox Results (Tier C)

## 1) Synthetic ULTRA run

- Report: [runs/tmp/ultra_synth_report.md](runs/tmp/ultra_synth_report.md)
- Validity summary: [runs/tmp/ultra_synth_validity_summary.md](runs/tmp/ultra_synth_validity_summary.md)

Outcome:
- Large RMSE gains on synthetic data (expected in controlled settings).

Use:
- Keep for algorithm demonstration and regression testing, not for physical claims about Arctic/forest ABL.

## 2) Multi-tracer regime diagnostics

- Summary: [runs/test_multi/diag_modeling_summary.md](runs/test_multi/diag_modeling_summary.md)
- Input preprocess summary: [runs/20260504_varrio_multitracer/input/varrio_multitracer_input_preprocess_summary.md](runs/20260504_varrio_multitracer/input/varrio_multitracer_input_preprocess_summary.md)

Use:
- Valuable for preprocessing QA, sign conventions, and regime decomposition strategy.

---

## Equations and Physical Framing for NotebookLM Context

### 1) Bulk Richardson number

$$
Ri_b = \frac{g}{\bar{\theta}}\frac{\Delta \theta\, \Delta z}{(\Delta U)^2 + \varepsilon}
$$

with $\theta \approx T + 273.15 + 0.0098z$ in this implementation.

### 2) Interaction coupling proxy

Rolling coupling metric over a moving window $W$:

$$
\rho_{H,\tau}(t) = \mathrm{corr}\left(H_{t:t+W},\,\tau_{t:t+W}\right)
$$

Interpretation:
- High positive magnitude: stronger heat-momentum coupling.
- Weak/near-zero: potential decoupling/intermittency.

### 3) Spectral-transport linkage

Operationally tested relationships:
- $c_3$ (curvature) vs $F_c$ or CO2 storage flux.
- Cross-correlation $\mathrm{corr}(c_k(t+\ell), F_c(t))$ for lags $\ell$.

---

## What To Put In NotebookLM (Recommended Ingestion Set)

For highest signal-to-noise, ingest these first:

1. [docs/reports/Runs_Summary_For_NotebookLM_2026-05-15.md](docs/reports/Runs_Summary_For_NotebookLM_2026-05-15.md)
2. [runs/sheba/fit/sheba_comparison_summary.md](runs/sheba/fit/sheba_comparison_summary.md)
3. [runs/dct_smear_seasonal_dead_of_winter/flux_corr/report.md](runs/dct_smear_seasonal_dead_of_winter/flux_corr/report.md)
4. [runs/dct_smear_seasonal_dead_of_winter/report.md](runs/dct_smear_seasonal_dead_of_winter/report.md)
5. [runs/sheba/dct_main_file6/report.md](runs/sheba/dct_main_file6/report.md)

Then add selected figures:
- [runs/sheba/fit/sheba_ultra_grachev_comparison.png](runs/sheba/fit/sheba_ultra_grachev_comparison.png)
- [runs/sheba/fit/sheba_ultra_zero_comparison.png](runs/sheba/fit/sheba_ultra_zero_comparison.png)
- [runs/dct_smear_seasonal_dead_of_winter/flux_corr/plot_corr_heatmap.png](runs/dct_smear_seasonal_dead_of_winter/flux_corr/plot_corr_heatmap.png)
- [runs/dct_smear_seasonal_dead_of_winter/varrio_dead_of_winter_temperature_profile/plot_crosscorr_temp_vs_fc.png](runs/dct_smear_seasonal_dead_of_winter/varrio_dead_of_winter_temperature_profile/plot_crosscorr_temp_vs_fc.png)
- [runs/dct_smear_seasonal_dead_of_winter/varrio_dead_of_winter_temperature_profile/plot_rib_vs_c3.png](runs/dct_smear_seasonal_dead_of_winter/varrio_dead_of_winter_temperature_profile/plot_rib_vs_c3.png)

---

## PDF Export Guidance

NotebookLM generally performs best with a **single coherent narrative PDF** rather than many disconnected files.

Recommended workflow:

1. Export this markdown to PDF with embedded figure links rendered.
2. Keep equations in LaTeX form (already included) so OCR preserves scientific semantics.
3. Optionally append one short appendix page with key CSV tables (top-10 correlations, core metrics).

If `pandoc` is available, a practical command is:

```bash
pandoc docs/reports/Runs_Summary_For_NotebookLM_2026-05-15.md \
  -o docs/reports/Runs_Summary_For_NotebookLM_2026-05-15.pdf
```

---

## Integrity Statement

This summary intentionally separates:
- reproducible, physically consistent run outcomes,
- operationally useful but still-evolving diagnostics,
- and sandbox experiments that should not be overinterpreted.

That separation is essential to maintain scientific credibility while moving fast in an active research-engineering codebase.
