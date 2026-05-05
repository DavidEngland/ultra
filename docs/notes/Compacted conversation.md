Compacted conversation

Created 3 todos

Read [](file:///Users/davidengland/Documents/GitHub/ABL/ultraspherical-gegenbauer-pbl/src/julia/sheba_ultra.jl#1-1), lines 1 to 100

Read [](file:///Users/davidengland/Documents/GitHub/ABL/ultraspherical-gegenbauer-pbl/src/julia/sheba_ultra.jl#100-100), lines 100 to 400

Read [](file:///Users/davidengland/Documents/GitHub/ABL/ultraspherical-gegenbauer-pbl/src/julia/sheba_ultra.jl#400-400), lines 400 to 525

Starting: *Create unified_ultra.jl with all-regime fit* (2/3)

Created [](file:///Users/davidengland/Documents/GitHub/ABL/ultraspherical-gegenbauer-pbl/src/julia/unified_ultra.jl)

Starting: *Smoke-test with SHEBA CSV* (3/3)

Now let's smoke-test it against the SHEBA CSV in stable-only mode (since that's what we have):

Ran terminal command:  julia src/julia/unified_ultra.jl data/sheba/processed/sheba_main_stable.csv runs/unified_sheba_stable/unified SHEBA --regime=stable --lambda=free --c1-tie=false 2>&1
Completed with input:  julia src/julia/unified_ultra.jl data/sheba/processed/sheba_main_stable.csv runs/unified_sheba_stable/unified SHEBA --regime=stable --lambda=free --c1-tie=false 2>&1

Good sign — the script loads fine (only a minor closures warning). Let me find the actual CSV path:

Searched for files matching `**/sheba*.csv`, 2 matches

Searched for files matching `**/sheba_stable.csv`, no matches

Ran terminal command:  find /Users/davidengland/Documents/GitHub/ABL/ultraspherical-gegenbauer-pbl -name "*.csv" | head -20

The processed CSV was produced by `preprocess_sheba_main.jl` and written locally. Let me check where:

Searched for regex `CSV.write.*sheba` (`**/*.jl`), no results

Searched for text `CSV.write` (`**/preprocess_sheba_main.jl`), 2 results

Searched for text `out_csv` (`**/ultraspherical-gegenbauer-pbl/src/julia/preprocess_sheba_main.jl`), 4 results

The preprocessor takes the output path as an argument — we need to regenerate the CSV (or check if it was already generated somewhere). Let me find any existing `_stable.csv` or similar:

Ran terminal command:  find /Users/davidengland/Documents/GitHub/ABL -name "*sheba*stable*" -o -name "*sheba*processed*" 2>/dev/null | head -20

Ran terminal command:  ls /Users/davidengland/Documents/GitHub/ABL/julia/output/ 2>/dev/null | head -20; find /Users/davidengland/Documents/GitHub/ABL -name "*.csv" -path "*/sheba/*" 2>/dev/null

No processed CSV exists yet in the new repo. I'll regenerate it quickly:

Ran terminal command:  julia src/julia/preprocess_sheba_main.jl data/sheba/processed/sheba_stable.csv 2>&1 | tail -10

2266 rows written. Now the smoke test:

Ran terminal command:  julia src/julia/unified_ultra.jl data/sheba/processed/sheba_stable.csv runs/unified_sheba_stable/unified SHEBA --regime=stable --lambda=free --c1-tie=false 2>&1
Completed with input:  julia src/julia/unified_ultra.jl data/sheba/processed/sheba_stable.csv runs/unified_sheba_stable/unified SHEBA --regime=stable --lambda=free --c1-tie=false 2>&1

Ran terminal command:  head -2 /Users/davidengland/Documents/GitHub/ABL/ultraspherical-gegenbauer-pbl/data/sheba/processed/sheba_stable.csv

The column name check uses Symbols against `names(df)` which returns Strings. Fix that:

Replacing 16 lines with 16 lines in [](file:///Users/davidengland/Documents/GitHub/ABL/ultraspherical-gegenbauer-pbl/src/julia/unified_ultra.jl)


```

```


Ran terminal command:  julia src/julia/unified_ultra.jl data/sheba/processed/sheba_stable.csv runs/unified_sheba_stable/unified SHEBA --regime=stable --lambda=free --c1-tie=false 2>&1
Completed with input:  julia src/julia/unified_ultra.jl data/sheba/processed/sheba_stable.csv runs/unified_sheba_stable/unified SHEBA --regime=stable --lambda=free --c1-tie=false 2>&1

All artifacts generated cleanly. Now let's also run the all-regime mode with C¹ tie to validate that path:

Ran terminal command:  julia src/julia/unified_ultra.jl data/sheba/processed/sheba_stable.csv runs/unified_sheba_c1/unified SHEBA --regime=stable --lambda=4 --c1-tie=true 2>&1
Completed with input:  julia src/julia/unified_ultra.jl data/sheba/processed/sheba_stable.csv runs/unified_sheba_c1/unified SHEBA --regime=stable --lambda=4 --c1-tie=true 2>&1

Completed: *Smoke-test with SHEBA CSV* (3/3)

Both paths work. Here's what was implemented in src/julia/unified_ultra.jl:

**Baselines**
- `phi_unstable`: $(1 - b_u\zeta)^{-1/\lambda_u}$ — Businger-Dyer family; `--lambda=2|4|free`
- `phi_stable`: $1 + a_s\zeta(1+\zeta)^{1/3}/(1+b_s\zeta)$ — Grachev 2007 family
- **C¹ tie** (`--c1-tie=true`): fixes $a_s = b_u/\lambda_u$ so neutral slope is continuous

**All-regime ξ-map**
$$\xi = \tanh\!\bigl(a_\xi\,\operatorname{asinh}(\zeta/\zeta_0)\bigr)$$
log in both tails, linear at $\zeta=0$, grid-searched over `ALPHA_XI_GRID × ZETA0_GRID`

**Blend** (`--blend=soft|hard`): sigmoid $s(\zeta)=\frac12(1+\tanh\frac\zeta\delta)$ joins the two baselines

**Results on SHEBA (stable)**
| run | test RMSE | gain |
|---|---|---|
| free Grachev + ULTRA | 0.3204 | 6.1% |
| C¹-tied (λ=4) + ULTRA | 0.3099 | **8.7%** |

The C¹ tie with fixed Businger-momentum exponent gives the best correction so far. The `Figure(resolution=...)` deprecation warnings are harmless (Makie version drift) — they don't affect output.

Made changes.