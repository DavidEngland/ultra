module SHEBAVarLookup

using JSON3

const REPO_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const CATALOG_PATH = joinpath(REPO_ROOT, "data", "sheba", "vars.json")
const _CATALOG_CACHE = Ref{Any}(nothing)
const _LOOKUP_CACHE = Ref{Any}(nothing)
const DERIVED_LOOKUP = Dict(
    "zeta" => (
        column = "zeta",
        raw_column = "zeta",
        source_id = "derived",
        source_path = "derived",
        category_id = "derived_stability",
        category_name = "Derived Stability Diagnostics",
        title = "Stability parameter zeta",
        plotLabel = "zeta",
        unit = "",
        description = "Derived Monin-Obukhov stability parameter used for DCT and regime summaries.",
    ),
    "phi_obs" => (
        column = "phi_obs",
        raw_column = "phi_obs",
        source_id = "derived",
        source_path = "derived",
        category_id = "derived_stability",
        category_name = "Derived Stability Diagnostics",
        title = "Observed momentum stability function",
        plotLabel = "phi_m",
        unit = "",
        description = "Backward-compatible observed stability function; currently equal to phi_m.",
    ),
    "phi_m" => (
        column = "phi_m",
        raw_column = "phi_m",
        source_id = "derived",
        source_path = "derived",
        category_id = "derived_stability",
        category_name = "Derived Stability Diagnostics",
        title = "Momentum stability function",
        plotLabel = "phi_m",
        unit = "",
        description = "Derived momentum stability function based on wind shear, zeta, and Obukhov length.",
    ),
    "phi_h" => (
        column = "phi_h",
        raw_column = "phi_h",
        source_id = "derived",
        source_path = "derived",
        category_id = "derived_stability",
        category_name = "Derived Stability Diagnostics",
        title = "Heat stability function",
        plotLabel = "phi_h",
        unit = "",
        description = "Derived heat stability function based on the temperature gradient and sensible heat flux.",
    ),
    "phi_q" => (
        column = "phi_q",
        raw_column = "phi_q",
        source_id = "derived",
        source_path = "derived",
        category_id = "derived_stability",
        category_name = "Derived Stability Diagnostics",
        title = "Humidity stability function",
        plotLabel = "phi_q",
        unit = "",
        description = "Derived humidity stability function based on the moisture gradient and latent heat flux.",
    ),
)

function _lookup_get(obj, key::AbstractString, default=nothing)
    if haskey(obj, key)
        return obj[key]
    end
    sym = Symbol(key)
    if haskey(obj, sym)
        return obj[sym]
    end
    return default
end

function _with_index(template, idx::Integer)
    return replace(String(template), "{index}" => string(idx))
end

function _expand_raw_pattern(pattern, idx::Integer)
    return replace(String(pattern), "[1-5]" => string(idx))
end

function load_catalog(path::AbstractString=CATALOG_PATH)
    if path == CATALOG_PATH && _CATALOG_CACHE[] !== nothing
        return _CATALOG_CACHE[]
    end
    catalog = JSON3.read(read(path, String))
    if path == CATALOG_PATH
        _CATALOG_CACHE[] = catalog
    end
    return catalog
end

function _store_entry!(lookup::Dict{String, NamedTuple}, key::AbstractString, entry::NamedTuple)
    lookup[String(key)] = entry
    return lookup
end

function _flatten_variable!(lookup::Dict{String, NamedTuple}, source, category, variable)
    source_id = String(source.id)
    source_path = String(source.path)
    category_id = String(category.id)
    category_name = String(category.name)

    if _lookup_get(variable, "members", nothing) !== nothing
        members = [String(member) for member in variable.members]
        raw_pattern = _lookup_get(variable, "rawPattern", nothing)
        for (idx, member) in enumerate(members)
            raw_column = isnothing(raw_pattern) ? member : _expand_raw_pattern(raw_pattern, idx)
            entry = (
                column = member,
                raw_column = String(raw_column),
                source_id = source_id,
                source_path = source_path,
                category_id = category_id,
                category_name = category_name,
                title = _with_index(_lookup_get(variable, "titleTemplate", member), idx),
                plotLabel = _with_index(_lookup_get(variable, "plotLabelTemplate", member), idx),
                unit = String(_lookup_get(variable, "unit", "")),
                description = _with_index(_lookup_get(variable, "description", ""), idx),
            )
            _store_entry!(lookup, member, entry)
            if raw_column != member
                _store_entry!(lookup, raw_column, entry)
            end
        end
        return lookup
    end

    column = String(variable.column)
    raw_column = String(_lookup_get(variable, "rawColumn", column))
    entry = (
        column = column,
        raw_column = raw_column,
        source_id = source_id,
        source_path = source_path,
        category_id = category_id,
        category_name = category_name,
        title = String(_lookup_get(variable, "title", column)),
        plotLabel = String(_lookup_get(variable, "plotLabel", _lookup_get(variable, "title", column))),
        unit = String(_lookup_get(variable, "unit", "")),
        description = String(_lookup_get(variable, "description", "")),
    )
    _store_entry!(lookup, column, entry)
    if raw_column != column
        _store_entry!(lookup, raw_column, entry)
    end
    return lookup
end

function flattened_lookup(catalog=load_catalog())
    if catalog === load_catalog() && _LOOKUP_CACHE[] !== nothing
        return _LOOKUP_CACHE[]
    end

    lookup = Dict{String, NamedTuple}()
    for source in catalog.sources
        for category in source.categories
            for variable in category.variables
                _flatten_variable!(lookup, source, category, variable)
            end
        end
    end

    merge!(lookup, DERIVED_LOOKUP)

    if catalog === load_catalog()
        _LOOKUP_CACHE[] = lookup
    end
    return lookup
end

function source_ids(catalog=load_catalog())
    return [String(source.id) for source in catalog.sources]
end

function source_categories(source_id::AbstractString; catalog=load_catalog())
    for source in catalog.sources
        if String(source.id) == source_id
            return [String(category.id) for category in source.categories]
        end
    end
    error("Source id not found in SHEBA catalog: $(source_id)")
end

function source_variables(source_id::AbstractString, category_id::AbstractString; catalog=load_catalog())
    for source in catalog.sources
        if String(source.id) != source_id
            continue
        end
        for category in source.categories
            if String(category.id) == category_id
                out = String[]
                for variable in category.variables
                    members = _lookup_get(variable, "members", nothing)
                    if isnothing(members)
                        push!(out, String(variable.column))
                    else
                        append!(out, [String(member) for member in members])
                    end
                end
                return out
            end
        end
        error("Category id not found for source $(source_id): $(category_id)")
    end
    error("Source id not found in SHEBA catalog: $(source_id)")
end

function sheba_var_entry(column::AbstractString; lookup=flattened_lookup())
    key = String(column)
    return get(lookup, key, nothing)
end

function sheba_title(column::AbstractString; lookup=flattened_lookup())
    entry = sheba_var_entry(column; lookup=lookup)
    return isnothing(entry) ? String(column) : entry.title
end

function sheba_plot_label(column::AbstractString; lookup=flattened_lookup())
    entry = sheba_var_entry(column; lookup=lookup)
    return isnothing(entry) ? String(column) : entry.plotLabel
end

function sheba_unit(column::AbstractString; lookup=flattened_lookup())
    entry = sheba_var_entry(column; lookup=lookup)
    return isnothing(entry) ? "" : entry.unit
end

function sheba_label_with_unit(column::AbstractString; lookup=flattened_lookup())
    label = sheba_plot_label(column; lookup=lookup)
    unit = sheba_unit(column; lookup=lookup)
    isempty(unit) && return label
    return "$(label) [$(unit)]"
end

function sheba_description(column::AbstractString; lookup=flattened_lookup())
    entry = sheba_var_entry(column; lookup=lookup)
    return isnothing(entry) ? "" : entry.description
end

function sheba_source_id(column::AbstractString; lookup=flattened_lookup())
    entry = sheba_var_entry(column; lookup=lookup)
    return isnothing(entry) ? "unknown" : entry.source_id
end

export CATALOG_PATH,
       load_catalog,
       flattened_lookup,
       source_ids,
       source_categories,
       source_variables,
       sheba_var_entry,
       sheba_title,
       sheba_plot_label,
       sheba_unit,
       sheba_label_with_unit,
       sheba_description,
       sheba_source_id

end