#!/usr/bin/env bash
set -euo pipefail

RUN_ID=${1:-$(date +%Y%m%d)_varrio}
mkdir -p runs/${RUN_ID}/input runs/${RUN_ID}/fit

# Update table-variable names as needed from SmartSMEAR metadata.
julia src/julia/preprocess_tower_to_ultra_input.jl \
  VRR \
  runs/${RUN_ID}/input/varrio_input.csv \
  24.0 \
  0.0 \
  --mode=api-smear \
  --profile-mode=two-level \
  --from=2018-01-01T00:00:00 \
  --to=2018-02-01T00:00:00 \
  --interval=30 \
  --aggregation=ARITHMETIC \
  --quality=ANY \
  --tv-uw=VAR_EDDY233.uw \
  --tv-vw=VAR_EDDY233.vw \
  --tv-wthetav=VAR_EDDY233.wtheta_v \
  --tv-thetav=VAR_EDDY233.theta_v \
  --tv-u1=VAR_META.WSU168 \
  --tv-u2=VAR_EDDY233.U \
  --tv-theta1=VAR_META.T168 \
  --tv-theta2=VAR_EDDY233.av_t \
  --z1=16.8 \
  --z2=24.0 \
  --phi=phi_m \
  --stable-only

julia src/julia/ultraspherical_practical_run.jl \
  runs/${RUN_ID}/input/varrio_input.csv \
  runs/${RUN_ID}/fit/varrio_ultra

echo "SMEAR template run complete: runs/${RUN_ID}/fit"
