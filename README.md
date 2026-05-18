# Ultraspherical Gegenbauer PBL

Focused repository for ultraspherical harmonics (Gegenbauer) modeling of PBL/ABL stability functions, with emphasis on highly stable nocturnal boundary layers (HSNBL).

## Scope

- Julia-first runnable workflows for preprocessing and fitting
- SMEAR rerun path (API/tower preprocessing to zeta and phi_obs)
- SHEBA retained public raw data and provenance
- SHEBA variable metadata for labeling, plotting, and future lookup helpers
- Benchmark reports for SHEBA and SMEAR runs

## Repository Layout

- src/julia: Julia scripts and Julia markdown notes copied from the parent workspace
- data/sheba/raw: retained SHEBA raw files and checksums
- data/sheba/vars.json: SHEBA variable catalog derived from ASFG readmes and raw headers
- data/smear: SMEAR station metadata
- docs/notes: conceptual notes
- docs/implementations: implementation notes and API status
- docs/reports: provenance and status reports
- docs/SHEBA_Variable_Catalog.md: guide to the SHEBA variable catalog and naming rules
- runs/benchmarks: benchmark metrics and reports
- scripts: runnable command templates
- migration: curation and delete-review manifests

## Quick Start

See docs/QUICKSTART.md.

## Canonical Scripts

- src/julia/preprocess_tower_to_ultra_input.jl
- src/julia/preprocess_sheba_main.jl
- src/julia/ultraspherical_practical_run.jl
- src/julia/sheba_ultra.jl

## Data Provenance

SHEBA provenance and checksums are documented in:
- docs/reports/SHEBA_Data_Provenance_and_Runbook_2026-05-03.md
- data/sheba/raw/SHA256SUMS.txt

## Git Hygiene and Data Tracking

Repository ignore rules are defined in `.gitignore` to avoid uploading large, regenerable run outputs.

Data retention policy:
- Ignore generated PNG plot artifacts under `runs/`
- Keep SHEBA raw text assets: `data/sheba/raw/*.txt`
- Keep SHEBA processed tables: `data/sheba/processed/*.csv`
- Ignore other files in those two SHEBA folders unless explicitly needed

Metadata references:
- `data/sheba/vars.json`
- `docs/SHEBA_Variable_Catalog.md`

For release-style change history, see `CHANGELOG.md`.

## Notes

This repository was seeded from a larger ABL workspace to isolate the ultraspherical workstream and make reruns easier for external users.
