# Varrio Seasonal Input Preparation

- station_id: 1
- season label: dead_of_winter_retrytest
- target day-of-year: 15
- years: 2024:2025
- aggregation: NONE
- quality: ANY

## Group row counts

- co2_tracers: 2880 rows
- heat_flux: 96 rows
- humidity_profile: 2880 rows
- momentum_flux: 96 rows
- other_tracers: 96 rows
- temperature_profile: 2880 rows
- wind_profile: 2880 rows

## DCT input

- dct temperature input rows: 2880
- dct status file: varrio_dead_of_winter_retrytest_dct_temperature_status.csv

## Artifacts

- varrio_dead_of_winter_retrytest_all_groups.csv (2880 rows): Union of all seasonal groups on datetime + season keys
- varrio_dead_of_winter_retrytest_fetch_status.csv (14 rows): Per-group and per-year fetch diagnostics
- varrio_dead_of_winter_retrytest_dct_temperature_input.csv (2880 rows): DCT_SMEAR-ready temperature+stability input with source fallback
- varrio_dead_of_winter_retrytest_dct_temperature_status.csv (2 rows): Per-year candidate-source outcome for DCT input
- varrio_dead_of_winter_retrytest_co2_tracers.csv (2880 rows): Seasonal group export
- varrio_dead_of_winter_retrytest_heat_flux.csv (96 rows): Seasonal group export
- varrio_dead_of_winter_retrytest_humidity_profile.csv (2880 rows): Seasonal group export
- varrio_dead_of_winter_retrytest_momentum_flux.csv (96 rows): Seasonal group export
- varrio_dead_of_winter_retrytest_other_tracers.csv (96 rows): Seasonal group export
- varrio_dead_of_winter_retrytest_temperature_profile.csv (2880 rows): Seasonal group export
- varrio_dead_of_winter_retrytest_wind_profile.csv (2880 rows): Seasonal group export
