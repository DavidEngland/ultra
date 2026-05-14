# Varrio Seasonal Input Preparation

- station_id: 1
- season label: dead_of_winter_2012_2025
- target day-of-year: 15
- years: 2012:2025
- aggregation: NONE
- quality: ANY

## Group row counts

- co2_tracers: 20160 rows
- heat_flux: 672 rows
- humidity_profile: 20160 rows
- momentum_flux: 672 rows
- other_tracers: 672 rows
- temperature_profile: 20160 rows
- wind_profile: 20160 rows

## DCT input

- dct temperature input rows: 20160
- dct status file: varrio_dead_of_winter_2012_2025_dct_temperature_status.csv

## Artifacts

- varrio_dead_of_winter_2012_2025_all_groups.csv (20160 rows): Union of all seasonal groups on datetime + season keys
- varrio_dead_of_winter_2012_2025_fetch_status.csv (98 rows): Per-group and per-year fetch diagnostics
- varrio_dead_of_winter_2012_2025_dct_temperature_input.csv (20160 rows): DCT_SMEAR-ready temperature+stability input with source fallback
- varrio_dead_of_winter_2012_2025_dct_temperature_status.csv (14 rows): Per-year candidate-source outcome for DCT input
- varrio_dead_of_winter_2012_2025_co2_tracers.csv (20160 rows): Seasonal group export
- varrio_dead_of_winter_2012_2025_heat_flux.csv (672 rows): Seasonal group export
- varrio_dead_of_winter_2012_2025_humidity_profile.csv (20160 rows): Seasonal group export
- varrio_dead_of_winter_2012_2025_momentum_flux.csv (672 rows): Seasonal group export
- varrio_dead_of_winter_2012_2025_other_tracers.csv (672 rows): Seasonal group export
- varrio_dead_of_winter_2012_2025_temperature_profile.csv (20160 rows): Seasonal group export
- varrio_dead_of_winter_2012_2025_wind_profile.csv (20160 rows): Seasonal group export
