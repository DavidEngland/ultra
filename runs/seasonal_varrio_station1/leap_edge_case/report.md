# Varrio Seasonal Input Preparation

- station_id: 1
- season label: leap_edge_case
- target day-of-year: 366
- years: 2023:2024
- aggregation: NONE
- quality: ANY

## Group row counts

- co2_tracers: 1440 rows
- heat_flux: 48 rows
- humidity_profile: 1440 rows
- momentum_flux: 48 rows
- other_tracers: 48 rows
- temperature_profile: 1440 rows
- wind_profile: 1440 rows

## DCT input

- dct temperature input rows: 1440
- dct status file: varrio_leap_edge_case_dct_temperature_status.csv

## Artifacts

- varrio_leap_edge_case_all_groups.csv (1440 rows): Union of all seasonal groups on datetime + season keys
- varrio_leap_edge_case_fetch_status.csv (14 rows): Per-group and per-year fetch diagnostics
- varrio_leap_edge_case_dct_temperature_input.csv (1440 rows): DCT_SMEAR-ready temperature+stability input with source fallback
- varrio_leap_edge_case_dct_temperature_status.csv (4 rows): Per-year candidate-source outcome for DCT input
- varrio_leap_edge_case_co2_tracers.csv (1440 rows): Seasonal group export
- varrio_leap_edge_case_heat_flux.csv (48 rows): Seasonal group export
- varrio_leap_edge_case_humidity_profile.csv (1440 rows): Seasonal group export
- varrio_leap_edge_case_momentum_flux.csv (48 rows): Seasonal group export
- varrio_leap_edge_case_other_tracers.csv (48 rows): Seasonal group export
- varrio_leap_edge_case_temperature_profile.csv (1440 rows): Seasonal group export
- varrio_leap_edge_case_wind_profile.csv (1440 rows): Seasonal group export
