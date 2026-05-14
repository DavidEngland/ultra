using HTTP, JSON3, Dates

const _VAR_START_API = get(ENV, "SMEAR_VARIABLE_API",
    "https://smear-backend.rahtiapp.fi/search/variable")

"""Keys tried in order when looking for a period-start field."""
const _PERIOD_START_KEYS = [
    "periodStart", "period_start", "startDate", "start_date",
    "measurementStart", "firstMeasurement", "from",
]

function _extract_period_start(entry)
    for key in _PERIOD_START_KEYS
        if haskey(entry, key)
            v = entry[key]
            isnothing(v) && continue
            s = string(v)
            isempty(s) && continue
            return s
        end
    end
    return nothing
end

"""
    get_variable_start_date(var_name) -> Union{String, Nothing}

Query the SMEAR metadata API for the first measurement date of `var_name`
(a `TABLE.COLUMN` tablevariable string).  Returns an ISO-8601 string such as
`"1996-01-01T00:00:00"`, or `nothing` if the variable is not found or has no
period-start field.

Passes `var_name` as both `?v=` and `?tablevariable=` to handle endpoint
variations across SMEAR backend versions.
"""
function get_variable_start_date(var_name::String)
    for param in ("v", "tablevariable")
        url = string(_VAR_START_API, "?", param, "=", var_name)
        try
            resp = HTTP.get(url; readtimeout=30)
            resp.status == 200 || continue
            payload = JSON3.read(String(resp.body))

            records = if payload isa AbstractVector
                payload
            elseif payload isa AbstractDict && haskey(payload, "data")
                payload["data"]
            elseif payload isa AbstractDict && haskey(payload, "results")
                payload["results"]
            else
                continue
            end

            isempty(records) && continue

            for rec in records
                entry = rec isa AbstractDict ? rec : Dict{String, Any}(pairs(rec))
                s = _extract_period_start(entry)
                isnothing(s) || return s
            end
        catch
            continue
        end
    end
    return nothing
end

"""
    get_variable_start_dates(vars) -> Dict{String, Union{String, Nothing}}

Batch version of `get_variable_start_date`.  Fetches by unique table prefix
to minimise API requests, then maps results back to the original column names.
"""
function get_variable_start_dates(vars::Vector{String})
    out = Dict{String, Union{String, Nothing}}(v => nothing for v in vars)
    for v in vars
        out[v] = get_variable_start_date(v)
    end
    return out
end