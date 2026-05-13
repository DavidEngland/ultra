module SMEARVarLookup

using JSON3

const REPO_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const COMPACT_LOOKUP_PATH = joinpath(REPO_ROOT, "data", "smear", "vars_compact_lookup.json")
const VARRIO_SUBSET_PATH = joinpath(REPO_ROOT, "data", "smear", "varrio_dct_subset.json")

const VARRIO_DCT_TEMP_PROFILE = [
    "VAR_META.TDRY0",
    "VAR_META.TDRY1",
    "VAR_META.TDRY2",
    "VAR_META.TDRY3",
    "VAR_META.TDRY4",
]

const VARRIO_DCT_WIND_PROFILE = [
    "VAR_META.WS0",
    "VAR_META.WS1",
    "VAR_META.WS2",
    "VAR_META.WS3",
    "VAR_META.WS4",
    "VAR_META.WDIR",
]

const VARRIO_DCT_TEMP_PROFILE_LEGACY = [
    "VAR_META.T2",
    "VAR_META.T4",
    "VAR_META.T66",
    "VAR_META.T9",
    "VAR_META.T15",
]

const VARRIO_DCT_WIND_PROFILE_LEGACY = [
    "VAR_META.WS2",
    "VAR_META.WS4",
    "VAR_META.WS66",
    "VAR_META.WS9",
    "VAR_META.WS15",
    "VAR_META.WD2",
    "VAR_META.WD4",
    "VAR_META.WD66",
    "VAR_META.WD9",
    "VAR_META.WD15",
]

const VARRIO_DCT_FLUX_CORE = [
    "VAR_EDDY.H",
    "VAR_EDDY.LE",
    "VAR_EDDY.E",
    "VAR_EDDY.F_c",
    "VAR_EDDY.tau",
    "VAR_EDDY.u_star",
    "VAR_EDDY.MO_length",
    "VAR_EDDY.U",
    "VAR_EDDY.wind_dir",
]

const VARRIO_DCT_FLUX_QUALITY = [
    "VAR_EDDY.Qc_H",
    "VAR_EDDY.Qc_LE",
    "VAR_EDDY.Qc_F_c",
    "VAR_EDDY.Qc_tau",
]

const VARRIO_DCT_FLUX_STORAGE = [
    "VAR_EDDY.CO2_storage_flux",
    "VAR_EDDY.H_storage_flux",
    "VAR_EDDY.LE_storage_flux",
]

const VARRIO_DCT_ALL = vcat(
    VARRIO_DCT_TEMP_PROFILE,
    VARRIO_DCT_WIND_PROFILE,
    VARRIO_DCT_FLUX_CORE,
    VARRIO_DCT_FLUX_QUALITY,
    VARRIO_DCT_FLUX_STORAGE,
)

function load_compact_lookup(path::AbstractString=COMPACT_LOOKUP_PATH)
    return JSON3.read(read(path, String))
end

function load_varrio_subset(path::AbstractString=VARRIO_SUBSET_PATH)
    return JSON3.read(read(path, String))
end

function station_categories(station_id::Integer; lookup=load_compact_lookup())
    sid = string(station_id)
    haskey(lookup, sid) || error("Station id not found in lookup: $(station_id)")
    return collect(keys(lookup[sid].categories))
end

function station_tablevariables(station_id::Integer, category::AbstractString; lookup=load_compact_lookup())
    sid = string(station_id)
    haskey(lookup, sid) || error("Station id not found in lookup: $(station_id)")
    categories = lookup[sid].categories
    haskey(categories, category) || error("Category not found for station $(station_id): $(category)")
    return String.(collect(categories[category]))
end

function varrio_dct_vars(group::Symbol=:temperature_profile)
    if group == :temperature_profile
        return copy(VARRIO_DCT_TEMP_PROFILE)
    elseif group == :temperature_profile_legacy
        return copy(VARRIO_DCT_TEMP_PROFILE_LEGACY)
    elseif group == :wind_profile
        return copy(VARRIO_DCT_WIND_PROFILE)
    elseif group == :wind_profile_legacy
        return copy(VARRIO_DCT_WIND_PROFILE_LEGACY)
    elseif group == :flux_core
        return copy(VARRIO_DCT_FLUX_CORE)
    elseif group == :flux_quality
        return copy(VARRIO_DCT_FLUX_QUALITY)
    elseif group == :flux_storage
        return copy(VARRIO_DCT_FLUX_STORAGE)
    elseif group == :all
        return copy(VARRIO_DCT_ALL)
    end
    error("Unknown Varrio DCT variable group: $(group)")
end

export COMPACT_LOOKUP_PATH,
       VARRIO_SUBSET_PATH,
       VARRIO_DCT_TEMP_PROFILE,
       VARRIO_DCT_WIND_PROFILE,
    VARRIO_DCT_TEMP_PROFILE_LEGACY,
    VARRIO_DCT_WIND_PROFILE_LEGACY,
       VARRIO_DCT_FLUX_CORE,
       VARRIO_DCT_FLUX_QUALITY,
       VARRIO_DCT_FLUX_STORAGE,
       VARRIO_DCT_ALL,
       load_compact_lookup,
       load_varrio_subset,
       station_categories,
       station_tablevariables,
       varrio_dct_vars

end