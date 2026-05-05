#!/usr/bin/env bash
set -euo pipefail

RUN_ID=${1:-$(date +%Y%m%d)_sheba}
mkdir -p runs/${RUN_ID}/input runs/${RUN_ID}/fit

julia src/julia/preprocess_sheba_main.jl runs/${RUN_ID}/input/sheba_input.csv data/sheba/raw/main_file6_hd.txt

julia src/julia/sheba_ultra.jl \
  runs/${RUN_ID}/input/sheba_input.csv \
  runs/${RUN_ID}/fit/sheba_ultra_grachev \
  SHEBA \
  --baseline=grachev

julia src/julia/sheba_ultra.jl \
  runs/${RUN_ID}/input/sheba_input.csv \
  runs/${RUN_ID}/fit/sheba_ultra_zero \
  SHEBA \
  --baseline=zero

echo "SHEBA run complete: runs/${RUN_ID}/fit"
