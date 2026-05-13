using HTTP, CSV, DataFrames, ApproxFun

# 1. API Fetching Function
function fetch_smear_tiled(table_var, start_date, end_date)
    base_url = "https://smear-backend-avaa-smear-prod.2.rahtiapp.fi/search/timeseries/csv"
    query = "?tablevariable=$table_var&from=$start_date&to=$end_date&quality=ANY&aggregation=NONE"
    response = HTTP.get(base_url * query)
    return CSV.read(response.body, DataFrame)
end

# 2. Spectral Analysis Engine
function analyze_spectral_structure(heights, values)
    # Map heights to [-1, 1]
    S = Chebyshev(Interval(minimum(heights), maximum(heights)))
    # Create the spectral object
    f = Fun(S, ApproxFun.transform(S, values))
    # Extract Chebyshev coefficients (The "Fingerprint")
    return coefficients(f)
end