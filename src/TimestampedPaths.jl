module TimestampedPaths

using Dates
using Logging
using DocStringExtensions

export Config,
       IndexState,
       PathGenerator,
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
       log_debug,
       set_subfolder_template!,
       set_date_template!,
       set_intermediate_stem!,
       set_intermediate_template!

include("logs.jl")


mutable struct IndexState
    current::Int
    highest_seen::Int
    last_scan_date::Union{Nothing,Date}
    active_date::Date
end

mutable struct Config
    root_dir::String
    timestamp_template::String
    subfolder_template::Union{Nothing,String}
    intermediate_template::Union{Nothing,String}
    extension::String
    suffix::Union{Nothing,String}
    start_index::Int
    index_width::Union{Nothing,Int}
    placeholder_range::Union{Nothing,UnitRange{Int}}
    intermediate_prefix::Union{Nothing,String}
    intermediate_suffix::Union{Nothing,String}
    state::IndexState
end

function Config(; root_dir::AbstractString,
                 timestamp_template::AbstractString = "yyyy_mmdd_HHMMSS",
                 subfolder_template::Union{Nothing,AbstractString}= "yyyy_mmdd",
                 intermediate_template::Union{Nothing,AbstractString}=nothing,
                 extension::AbstractString="",
                 suffix::Union{Nothing,AbstractString}=nothing,
                 start_index::Integer=1,
                 index_width::Union{Nothing,Integer}=nothing,
                 now::Dates.AbstractDateTime=Dates.now())
    start_value = Int(start_index)
    start_value < 0 && throw(ArgumentError("start_index must be non-negative"))

    root = abspath(String(root_dir))
    ts_template = String(timestamp_template)
    subfolder_value = subfolder_template === nothing ? nothing : String(subfolder_template)
    inter_template = intermediate_template === nothing ? nothing : String(intermediate_template)
    ext = _normalize_extension(String(extension))
    suffix_value = suffix === nothing ? nothing : String(suffix)

    metadata = _compute_intermediate_metadata(inter_template, index_width)

    mkpath(root)

    initial_date = Date(now)
    initial_state = IndexState(start_value,
                               start_value - 1,
                               nothing,
                               initial_date)

    config = Config(root,
                    ts_template,
                    subfolder_value,
                    inter_template,
                    ext,
                    suffix_value,
                    start_value,
                    metadata.index_width,
                    metadata.placeholder_range,
                    metadata.intermediate_prefix,
                    metadata.intermediate_suffix,
                    initial_state)
    refresh_index!(config; now=now, force=true)
    return config
end

"""
    PathGenerator(config::Config; tag=nothing)

Wrap a `Config` in a callable object that ensures the current collection path and
returns filenames on demand. Provide a default `tag` to reuse it across calls.
The functor accepts optional `tag` (pass `nothing` to suppress a default tag) and
`now` keywords when invoked.
"""
struct PathGenerator
    config::Config
    default_tag::Union{Nothing,String}
end

function PathGenerator(config::Config; tag::Union{Nothing,AbstractString}=nothing)
    stored_tag = tag === nothing ? nothing : String(tag)
    if config.placeholder_range !== nothing
        refresh_index!(config; now=DateTime(config.state.active_date), force=false)
        _promote_to_next_index!(config)
    end
    return PathGenerator(config, stored_tag)
end

function (generator::PathGenerator)(; tag::Union{Missing,Nothing,AbstractString}=missing,
                                    now::Dates.AbstractDateTime=Dates.now())
    tag_value = if tag === missing
        generator.default_tag
    elseif tag === nothing
        nothing
    else
        String(tag)
    end
    ensure_collection_path!(generator.config; now=now)
    return get_file_path(generator.config, generator.config.state;
                         tag=tag_value, now=now, ensure_path=false)
end

function set_intermediate_template!(config::Config,
                                    template::Union{Nothing,AbstractString};
                                    index_width::Union{Nothing,Integer}=nothing,
                                    now::Dates.AbstractDateTime=DateTime(config.state.active_date),
                                    align_state::Bool=true)
    new_template = template === nothing ? nothing : String(template)
    metadata = _compute_intermediate_metadata(new_template, index_width)
    config.intermediate_template = new_template
    config.index_width = metadata.index_width
    config.placeholder_range = metadata.placeholder_range
    config.intermediate_prefix = metadata.intermediate_prefix
    config.intermediate_suffix = metadata.intermediate_suffix
    if align_state
        refresh_index!(config; now=now, force=true)
    end
    return config
end

"""
    set_intermediate_stem!(config::Config, stem; min_index_width=2, now=Dates.now())

Convenience wrapper that derives the intermediate template from a stem (e.g. `"run"`
becomes `"run_##"`). The helper refreshes indexing metadata, preserves the highest
observed index, and advances the active index so subsequent calls pick up the next
slot. Pass `nothing` to remove the intermediate folder entirely.
"""
function set_intermediate_stem!(config::Config,
                                stem::Union{Nothing,AbstractString};
                                min_index_width::Integer=2,
                                now::Dates.AbstractDateTime=DateTime(config.state.active_date),
                                align_state::Bool=true)
    prev_highest = config.state.highest_seen

    result = if stem === nothing
        set_intermediate_template!(config, nothing;
                                   index_width=nothing,
                                   now=now,
                                   align_state=align_state)
    else
        stem_str = String(stem)
        if occursin('#', stem_str)
            set_intermediate_template!(config, stem_str;
                                       index_width=nothing,
                                       now=now,
                                       align_state=align_state)
        else
            width_min = Int(min_index_width)
            width_min < 1 && throw(ArgumentError("min_index_width must be positive"))
            existing_width = config.index_width
            width_hint = existing_width === nothing ? width_min : max(existing_width, width_min)
            template = string(stem_str, "_", repeat("#", width_hint))
            set_intermediate_template!(config, template;
                                       index_width=width_hint,
                                       now=now,
                                       align_state=align_state)
        end
    end

    if align_state
        state = config.state
        state.highest_seen = max(state.highest_seen, prev_highest)
        if config.placeholder_range !== nothing
            _promote_to_next_index!(config)
        end
    end

    return result
end

function set_subfolder_template!(config::Config,
                                 template::Union{Nothing,AbstractString};
                                 now::Dates.AbstractDateTime=DateTime(config.state.active_date),
                                 align_state::Bool=true)
    config.subfolder_template = template === nothing ? nothing : String(template)
    if align_state
        refresh_index!(config; now=now, force=true)
    end
    return config
end

set_date_template! = set_subfolder_template!

function IndexState(config::Config; now::Dates.AbstractDateTime=Dates.now())
    date = Date(now)
    highest = _scan_highest_index(config, date)
    base_highest = highest === nothing ? config.start_index - 1 : max(highest, config.start_index - 1)
    current = max(base_highest, config.start_index)
    return IndexState(current, base_highest, date, date)
end

timestamp(dt::Dates.AbstractDateTime, template::AbstractString) = Dates.format(dt, template)

"""
    current_collection_path(config::Config) -> String
    current_collection_path(config::Config, state::IndexState) -> String

Return the absolute path for the collection directory for `state.active_date`. When an intermediate
template is configured, the current index determines the folder name within the date directory.
"""
function current_collection_path(config::Config, state::IndexState)
    date_folder = _date_folder_component(config, state.active_date)
    parts = String[config.root_dir, date_folder]
    if config.intermediate_template !== nothing
        push!(parts, _format_intermediate(config, state.current))
    end
    return joinpath(parts...)
end

current_collection_path(config::Config) = current_collection_path(config, config.state)

"""
    ensure_collection_path!(config::Config; now=Dates.now()) -> String
    ensure_collection_path!(config::Config, state::IndexState; now=Dates.now()) -> String

Align the index state to the provided time and create (if necessary) the collection directory for
that day and current index. Returns the path that was ensured.
"""
function ensure_collection_path!(config::Config, state::IndexState; now::Dates.AbstractDateTime=Dates.now())
    _align_state_date!(config, state, now)
    path = current_collection_path(config, state)
    mkpath(path)
    state.highest_seen = max(state.highest_seen, state.current)
    return path
end

function ensure_collection_path!(config::Config; now::Dates.AbstractDateTime=Dates.now())
    return ensure_collection_path!(config, config.state; now=now)
end

function increment_index!(state::IndexState)
    state.current += 1
    state.highest_seen = max(state.highest_seen, state.current)
    return state.current
end

increment_index!(config::Config) = increment_index!(config.state)

"""
    create_next_output_directory!(config::Config; now=Dates.now()) -> String
    create_next_output_directory!(config::Config, state::IndexState; now=Dates.now()) -> String

Advance the index to the next available number (scanning the filesystem if needed), update the
state, and ensure the corresponding collection directory exists. Returns the directory path.
"""
function create_next_output_directory!(config::Config, state::IndexState; now::Dates.AbstractDateTime=Dates.now())
    refresh_index!(state, config; now=now, force=false)
    next_index = max(state.highest_seen + 1, config.start_index)
    state.current = next_index
    state.highest_seen = next_index
    return ensure_collection_path!(config, state; now=now)
end

function create_next_output_directory!(config::Config; now::Dates.AbstractDateTime=Dates.now())
    return create_next_output_directory!(config, config.state; now=now)
end

"""
    get_file_path(config::Config; tag=nothing, now=Dates.now()) -> String
    get_file_path(config::Config, state::IndexState; tag=nothing, now=Dates.now()) -> String

Return the full file path for the given time, incorporating the current collection directory,
timestamp, optional suffix, and optional tag. The path is not created on disk.
"""
function get_file_path(config::Config,
                       state::IndexState;
                       tag::Union{Nothing,AbstractString}=nothing,
                       now::Dates.AbstractDateTime=Dates.now(),
                       ensure_path::Bool=false)
    collection_path = if ensure_path
        ensure_collection_path!(config, state; now=now)
    else
        _align_state_date!(config, state, now)
        current_collection_path(config, state)
    end
    ts = timestamp(now, config.timestamp_template)

    parts = String[ts]
    suffix_value = config.suffix
    if suffix_value !== nothing
        push!(parts, suffix_value::String)
    end

    tag_value = tag === nothing ? nothing : String(tag)
    if tag_value !== nothing
        push!(parts, tag_value)
    end

    filename = join(parts, "_")
    if !isempty(config.extension)
        filename *= config.extension
    end
    return joinpath(collection_path, filename)
end
function get_file_path(config::Config;
                       tag::Union{Nothing,AbstractString}=nothing,
                       now::Dates.AbstractDateTime=Dates.now(),
                       ensure_path::Bool=true)
    return get_file_path(config, config.state;
                         tag=tag,
                         now=now,
                         ensure_path=ensure_path)
end

get_file_path(generator::PathGenerator;
              tag::Union{Missing,Nothing,AbstractString}=missing,
              now::Dates.AbstractDateTime=Dates.now()) = generator(; tag=tag, now=now)

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

function refresh_index!(config::Config;
                        now::Dates.AbstractDateTime=Dates.now(),
                        force::Bool=false)
    return refresh_index!(config.state, config; now=now, force=force)
end

sync_to_latest_index!(state::IndexState, config::Config; now::Dates.AbstractDateTime=Dates.now()) =
    refresh_index!(state, config; now=now, force=true)

sync_to_latest_index!(config::Config; now::Dates.AbstractDateTime=Dates.now()) =
    refresh_index!(config; now=now, force=true)

function _align_state_date!(config::Config, state::IndexState, now::Dates.AbstractDateTime)
    current_date = Date(now)
    if state.active_date != current_date
        refresh_index!(state, config; now=now, force=true)
    end
end

_align_state_date!(config::Config, now::Dates.AbstractDateTime) =
    _align_state_date!(config, config.state, now)

function _promote_to_next_index!(config::Config)
    state = config.state
    next_index = max(state.highest_seen + 1, config.start_index)
    state.current = next_index
    return next_index
end

function _normalize_extension(ext::String)
    isempty(ext) && return ""
    startswith(ext, ".") && return ext
    return "." * ext
end

function _compute_intermediate_metadata(inter_template::Union{Nothing,String},
                                        index_width_hint::Union{Nothing,Integer})
    placeholder_range = _find_placeholder_range(inter_template)
    derived_width = index_width_hint === nothing ? nothing : Int(index_width_hint)

    if derived_width !== nothing && placeholder_range === nothing
        throw(ArgumentError("index_width provided but intermediate_template lacks '#' placeholder"))
    end

    intermediate_prefix = nothing
    intermediate_suffix = nothing

    if placeholder_range !== nothing
        template_str = inter_template::String
        if derived_width === nothing
            derived_width = length(placeholder_range)
        elseif derived_width != length(placeholder_range)
            throw(ArgumentError("index_width must match the number of '#' characters in intermediate_template"))
        end
        intermediate_prefix = String(_substring(template_str, firstindex(template_str), first(placeholder_range) - 1))
        intermediate_suffix = String(_substring(template_str, last(placeholder_range) + 1, lastindex(template_str)))
    end

    return (index_width = derived_width,
            placeholder_range = placeholder_range,
            intermediate_prefix = intermediate_prefix,
            intermediate_suffix = intermediate_suffix)
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
    if config.subfolder_template === nothing
        ts = timestamp(dt, config.timestamp_template)
        return _extract_date_component(ts)
    end
    return timestamp(dt, config.subfolder_template::String)
end

function _extract_date_component(ts::String)
    m = match(r"^[^_T\s]+", ts)
    m === nothing && return ts
    return m.match
end



include("api.jl")
end # module TimestampedPaths


