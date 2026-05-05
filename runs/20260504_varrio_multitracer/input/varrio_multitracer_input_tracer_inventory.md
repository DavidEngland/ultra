# Tracer Inventory

- source: runs/20260504_varrio_multitracer/input/varrio_public_overlap_raw.csv
- mode: raw
- tracers selected: momentum, heat, q1, q2

| tracer | φ column | scale | λ_u | b_u | φ bounds | sign note |
|---|---|---|---|---|---|---|
| Momentum  φ_m | phi_m | u_* | 4.0 | 16.0 | [0.5, 100.0] | phi_m is always positive; u_* is always positive — no sign ambiguity. |
| Heat  φ_h | phi_h | θ_* | 2.0 | 16.0 | [0.5, 100.0] | θ_* = −w′θ_v′/u_* (positive in stable). Check that your sonic has the correct sign for w′θ_v′. |
| humidity | phi_q1 | q1_* | 2.0 | 16.0 | [0.1, 200.0] | Verify sign convention: both the turbulent flux w′q1′ and the mean gradient dq1/dz must be checked. |
| CO2 | phi_q2 | q2_* | 2.0 | 16.0 | [0.1, 200.0] | Verify sign convention: both the turbulent flux w′q2′ and the mean gradient dq2/dz must be checked. |
