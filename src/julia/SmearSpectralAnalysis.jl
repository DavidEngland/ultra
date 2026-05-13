module SmearSpectralAnalysis

using HTTP, CSV, DataFrames, ApproxFun, Optim, SpecialFunctions, Dates

# --- Configuration & Constants ---
const SMEAR_API = "https://smear-backend-avaa-smear-prod.2.rahtiapp.fi/search/timeseries/csv"
const KAPPA = 0.4

# --- Data Ingestion Layer ---
"""
Fetches vertical profile data from SmartSMEAR.
Example table_vars: ["HYY_META.Pamb0", "HYY_META.T168", ...]
"""
function fetch_smear_data(table_vars::Vector{String}, start_dt::DateTime, end_dt::DateTime)
    params = Dict(
        "tablevariable" => table_vars,
        "from" => Dates.format(start_dt, "yyyy-mm-ddTHH:MM:SS"),
        "to" => Dates.format(end_dt, "yyyy-mm-ddTHH:MM:SS"),
        "quality" => "ANY",
        "aggregation" => "NONE"
    )

    # Constructing query string manually for multiple tablevariables
    query_str = join(["$k=$v" for (k,v) in params if k != "tablevariable"], "&")
    tv_str = join(["tablevariable=$v" for v in table_vars], "&")

    url = "$SMEAR_API?$tv_str&$query_str"
    println("Fetching: $url")

    response = HTTP.get(url)
    return CSV.read(response.body, DataFrame)
end

# --- Spectral Core ---
"""
Maps physical heights to Chebyshev domain [-1, 1] and returns coefficients.
"""
function get_chebyshev_fingerprint(heights::Vector{Float64}, values::Vector{Float64}, order::Int=4)
    # Define the domain based on the tower span
    domain = Interval(minimum(heights), maximum(heights))
    S = Chebyshev(domain)

    # Transform values to spectral space
    f = Fun(S, ApproxFun.transform(S, values))

    # Return the first 'order' coefficients
    return coefficients(f)[1:min(end, order)]
end

"""
The 'Gegenbauer Objective': Finds the lambda that makes the observed
phi profile most consistent with the Ultraspherical generating function.
"""
function optimize_lambda(zeta::Float64, phi_obs::Float64)
    # Objective: Minimize residual of phi = (1 - b*zeta)^(-lambda)
    # This is a simplified point-wise search; in practice, use a time-window.
    loss(p) = (phi_obs - (1 - p[1]*zeta)^(-p[2]))^2

    # p[1] is 'b' (scaling), p[2] is 'lambda' (fractal exponent)
    res = optimize(loss, [15.0, 0.5], LBFGS())
    return Optim.minimizer(res) # returns [b, lambda]
end

# --- Workflow Execution ---
function run_analysis_pipeline()
    # 1. Define Variables (Example: Värriö Temp profile)
    # SMEAR-I Heights: 2, 4, 6.6, 9, 15m
    vars = ["VAR_META.T15", "VAR_META.T9", "VAR_META.T66", "VAR_META.T4", "VAR_META.T2"]
    t_start = now() - Day(7)
    t_end = now()

    # 2. Pull Data
    df = fetch_smear_data(vars, t_start, t_end)

    # 3. Process Profiles
    # This loop would iterate through rows (time steps)
    spectral_results = []
    height_vec = [15.0, 9.0, 6.6, 4.0, 2.0]

    for row in eachrow(df)
        temp_vals = [row[Symbol(v)] for v in vars]

        # Check for NaNs
        if any(isnan, temp_vals) continue end

        # Get the Chebyshev 'fingerprint'
        coeffs = get_chebyshev_fingerprint(height_vec, temp_vals)

        # Store for analysis
        push!(spectral_results, (time=row.T, c1=coeffs[1], c2=coeffs[2]))
    end

    return DataFrame(spectral_results)
end

end # module