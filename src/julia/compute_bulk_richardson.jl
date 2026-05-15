"""
    compute_bulk_richardson(df, z_low, z_high, t_low_col, t_high_col, ws_high_col; ws_low_col=nothing)

Calculates the Bulk Richardson number between two heights.
z: height in meters
t: temperature (Celsius or Kelvin)
ws: wind speed (m/s)
"""
function compute_bulk_richardson(
    df::DataFrame,
    z_low::Real,
    z_high::Real,
    t_low_col::Symbol,
    t_high_col::Symbol,
    ws_high_col::Symbol;
    ws_low_col=nothing # If nothing, assumes ws=0 at surface or uses a lower sensor
)
    g = 9.81              # Gravity (m/s^2)
    T0 = 273.15           # Kelvin offset
    dz = z_high - z_low

    # 1. Calculate Potential Temperature (Approximate for surface layers)
    # theta ≈ T + 0.0098 * z
    theta_low = df[!, t_low_col] .+ T0 .+ (0.0098 * z_low)
    theta_high = df[!, t_high_col] .+ T0 .+ (0.0098 * z_high)
    theta_mean = (theta_low .+ theta_high) ./ 2
    d_theta = theta_high .- theta_low

    # 2. Calculate Wind Shear (ΔU)
    # If no low-level wind sensor, we assume a no-slip condition (0 m/s) at z=0
    u_low = isnothing(ws_low_col) ? zeros(nrow(df)) : df[!, ws_low_col]
    u_high = df[!, ws_high_col]
    du = u_high .- u_low

    # 3. Compute Ri_b
    # Adding a small epsilon to denominator to avoid DivByZero
    ri_b = (g ./ theta_mean) .* (d_theta .* dz) ./ (du.^2 .+ 1e-6)

    return ri_b
end