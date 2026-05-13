include(joinpath(@__DIR__, "SmearPipeline.jl"))
using .SmearPipeline
using Dates

# 1. Pull Temperature and CO2 data
vars = [SmearPipeline.HYY_VARS[:T_2m], SmearPipeline.HYY_VARS[:T_4m],
        SmearPipeline.HYY_VARS[:T_8m], SmearPipeline.HYY_VARS[:T_16m],
        SmearPipeline.HYY_VARS[:L_obukhov], SmearPipeline.HYY_VARS[:ustar]]

raw_df = fetch_smear_tiled(vars, DateTime(2025, 5, 1), DateTime(2025, 6, 1))

# 2. Build 30-min median profiles
profiles = build_vertical_profiles(raw_df, :T)

# 3. Transform to Spectral Space
fingerprints = batch_fingerprint(profiles, :T)

# 4. Classify and Analyze
SmearPipeline.add_stability_class!(fingerprints)

# Look for the "Fractal" signature in Stable regimes
stable_events = filter(r -> r.stability == :stable, fingerprints)