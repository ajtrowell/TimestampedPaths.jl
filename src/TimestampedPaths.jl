module TimestampedPaths

using Dates
using Logging
using Sockets

export Config,
       IndexState,
       host_name,
       timestamp,
       current_collection_path,
       ensure_collection_path!,
       increment_index!,
       create_next_output_directory!,
       get_file_path,
       refresh_index!,
       sync_to_latest_index!,
       set_log_level!,
       log_info,
       log_debug

const _LOG_LEVEL = Ref{LogLevel}(Logging.Warn)

set_log_level!(level::LogLevel) = (_LOG_LEVEL[] = level)

@inline function _should_log(level::LogLevel)
    Int(level) >= Int(_LOG_LEVEL[])
end

function log_info(msg)
    _should_log(Logging.Info) && @info msg
    return nothing
end

function log_debug(msg)
    _should_log(Logging.Debug) && @debug msg
    return nothing
end

struct Config
    root_dir::String
    timestamp_template::String
    intermediate_template::Union{Nothing,String}
    extension::String
    suffix::Union{Nothing,String}
    start_index::Int
    index_width::Union{Nothing,Int}
    placeholder_range::Union{Nothing,UnitRange{Int}}
    intermediate_prefix::Union{Nothing,String}
    intermediate_suffix::Union{Nothing,String}
end

function Config(; root_dir::AbstractString,
                 timestamp_template::AbstractString,
                 intermediate_template::Union{Nothing,AbstractString}=nothing,
                 extension::AbstractString="",
                 suffix::Union{Nothing,AbstractString}=nothing,
                 start_index::Integer=1,
                 index_width::Union{Nothing,Integer}=nothing)
    start_value = Int(start_index)
    start_value < 0 && throw(ArgumentError("start_index must be non-negative"))

    root = abspath(String(root_dir))
    ts_template = String(timestamp_template)
    inter_template = intermediate_template === nothing ? nothing : String(intermediate_template)
    ext = _normalize_extension(String(extension))
    suffix_value = suffix === nothing ? nothing : String(suffix)

    placeholder_range = _find_placeholder_range(inter_template)
    derived_width = index_width === nothing ? nothing : Int(index_width)

    if derived_width !== nothing
        placeholder_range === nothing && throw(ArgumentError("index_width provided but intermediate_template lacks '#' placeholder"))
    end

    if placeholder_range !== nothing && derived_width === nothing
        derived_width = length(placeholder_range)
    end

    if placeholder_range !== nothing && derived_width !== nothing && derived_width != length(placeholder_range)
        throw(ArgumentError("index_width must match the number of '#' characters in intermediate_template"))
    end

    prefix = placeholder_range === nothing ? nothing :
        String(_substring(inter_template::String, firstindex(inter_template), first(placeholder_range) - 1))
    suffix_part = placeholder_range === nothing ? nothing :
        String(_substring(inter_template::String, last(placeholder_range) + 1, lastindex(inter_template)))

    mkpath(root)

    return Config(root,
                  ts_template,
                  inter_template,
                  ext,
                  suffix_value,
                  start_value,
                  derived_width,
                  placeholder_range,
                  prefix,
                  suffix_part)
end

mutable struct IndexState
    current::Int
    highest_seen::Int
    last_scan_date::Union{Nothing,Date}
    active_date::Date
end

function IndexState(config::Config; now::Dates.AbstractDateTime=Dates.now())
    date = Date(now)
    highest = _scan_highest_index(config, date)
    base_highest = highest === nothing ? config.start_index - 1 : max(highest, config.start_index - 1)
    current = max(base_highest, config.start_index)
    return IndexState(current, base_highest, date, date)
end

timestamp(dt::Dates.AbstractDateTime, template::AbstractString) = Dates.format(dt, template)

host_name() = gethostname()

function current_collection_path(config::Config, state::IndexState)
    date_folder = _date_folder_component(config, state.active_date)
    parts = String[config.root_dir, date_folder]
    if config.intermediate_template !== nothing
        push!(parts, _format_intermediate(config, state.current))
    end
    return joinpath(parts...)
end

function ensure_collection_path!(config::Config, state::IndexState; now::Dates.AbstractDateTime=Dates.now())
    _align_state_date!(config, state, now)
    path = current_collection_path(config, state)
    mkpath(path)
    return path
end

function increment_index!(state::IndexState)
    state.current += 1
    state.highest_seen = max(state.highest_seen, state.current)
    return state.current
end

function create_next_output_directory!(config::Config, state::IndexState; now::Dates.AbstractDateTime=Dates.now())
    refresh_index!(state, config; now=now, force=false)
    next_index = max(state.highest_seen + 1, config.start_index)
    state.current = next_index
    state.highest_seen = next_index
    return ensure_collection_path!(config, state; now=now)
end

function get_file_path(config::Config,
                       state::IndexState;
                       tag::Union{Nothing,AbstractString}=nothing,
                       now::Dates.AbstractDateTime=Dates.now())
    _align_state_date!(config, state, now)
    collection_path = current_collection_path(config, state)
    ts = timestamp(now, config.timestamp_template)

    parts = String[ts]
    if config.suffix !== nothing
        push!(parts, config.suffix::String)
    end
    if tag !== nothing
        push!(parts, String(tag))
    end
    filename = join(parts, "_")
    if !isempty(config.extension)
        filename *= config.extension
    end
    return joinpath(collection_path, filename)
end

function refresh_index!(state::IndexState,
                        config::Config;
                        now::Dates.AbstractDateTime=Dates.now(),
                        force::Bool=false)
    current_date = Date(now)
    needs_scan = force ||
                 state.last_scan_date === nothing ||
                 state.last_scan_date != current_date ||
                 state.active_date != current_date
    if needs_scan
        highest = _scan_highest_index(config, current_date)
        base_highest = highest === nothing ? config.start_index - 1 : max(highest, config.start_index - 1)
        state.highest_seen = base_highest
        state.current = max(base_highest, config.start_index)
        state.last_scan_date = current_date
        state.active_date = current_date
    end
    return state
end

sync_to_latest_index!(state::IndexState, config::Config; now::Dates.AbstractDateTime=Dates.now()) =
    refresh_index!(state, config; now=now, force=true)

function _align_state_date!(config::Config, state::IndexState, now::Dates.AbstractDateTime)
    current_date = Date(now)
    if state.active_date != current_date
        refresh_index!(state, config; now=now, force=true)
    end
end

function _normalize_extension(ext::String)
    isempty(ext) && return ""
    startswith(ext, ".") && return ext
    return "." * ext
end

_find_placeholder_range(::Nothing) = nothing

function _find_placeholder_range(template::String)
    first_idx = findfirst(isequal('#'), template)
    first_idx === nothing && return nothing

    last_idx = first_idx
    while last_idx < lastindex(template) && template[last_idx + 1] == '#'
        last_idx += 1
    end

    extra = findnext(isequal('#'), template, last_idx + 1)
    if extra !== nothing
        throw(ArgumentError("intermediate_template may contain only one contiguous run of '#' characters"))
    end

    return first_idx:last_idx
end

function _substring(template::String, start::Int, stop::Int)
    stop < start && return ""
    return template[start:stop]
end

function _format_intermediate(config::Config, index::Int)
    template = config.intermediate_template
    template === nothing && return ""
    range = config.placeholder_range
    range === nothing && return template

    width = config.index_width
    width === nothing && return template

    digits = lpad(string(index), width, '0')
    prefix = config.intermediate_prefix === nothing ? "" : config.intermediate_prefix::String
    suffix = config.intermediate_suffix === nothing ? "" : config.intermediate_suffix::String
    return string(prefix, digits, suffix)
end

function _scan_highest_index(config::Config, date::Date)
    range = config.placeholder_range
    range === nothing && return nothing
    width = config.index_width
    width === nothing && return nothing

    date_root = _date_root(config, date)
    isdir(date_root) || return nothing

    prefix = config.intermediate_prefix === nothing ? "" : config.intermediate_prefix::String
    suffix = config.intermediate_suffix === nothing ? "" : config.intermediate_suffix::String

    highest::Int = config.start_index - 1
    found = false

    for entry in readdir(date_root)
        full_path = joinpath(date_root, entry)
        isdir(full_path) || continue
        idx = _parse_index_from_name(entry, prefix, suffix, width)
        idx === nothing && continue
        found = true
        highest = max(highest, idx)
    end

    return found ? highest : nothing
end

function _parse_index_from_name(name::String, prefix::String, suffix::String, width::Int)
    starts_with_prefix = isempty(prefix) || startswith(name, prefix)
    starts_with_prefix || return nothing

    suffix_length = length(suffix)
    required_length = length(prefix) + width + suffix_length
    length(name) == required_length || return nothing

    digit_start = length(prefix) + 1
    digit_stop = digit_start + width - 1
    digits = name[digit_start:digit_stop]

    all(isdigit, digits) || return nothing

    if !isempty(suffix)
        name[digit_stop + 1:end] == suffix || return nothing
    end

    return parse(Int, digits)
end

function _date_root(config::Config, date::Date)
    joinpath(config.root_dir, _date_folder_component(config, date))
end

function _date_folder_component(config::Config, date::Date)
    dt = DateTime(date)
    ts = timestamp(dt, config.timestamp_template)
    return _extract_date_component(ts)
end

function _extract_date_component(ts::String)
    m = match(r"^[^_T\s]+", ts)
    m === nothing && return ts
    return m.match
end

end # module TimestampedPaths
