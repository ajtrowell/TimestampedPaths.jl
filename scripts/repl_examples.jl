using Dates
using Logging

using TimestampedPaths

set_log_level!(Logging.Info)

demo_root = joinpath(pwd(), "demo_outputs")
start_time = DateTime(2024, 10, 11, 9, 0)

primary_config = Config(
    root_dir = demo_root,
    timestamp_template = "yyyy-mm-dd_HHMMSS",
    intermediate_template = "set_##",
    extension = ".dat",
    suffix = "host",
    start_index = 1,
    now = start_time,
)

secondary_config = Config(
    root_dir = demo_root,
    timestamp_template = primary_config.timestamp_template,
    intermediate_template = primary_config.intermediate_template,
    extension = primary_config.extension,
    suffix = primary_config.suffix,
    start_index = primary_config.start_index,
    now = start_time,
)

primary_paths = PathGenerator(primary_config)
secondary_paths = PathGenerator(secondary_config)

function print_collection_state(name::AbstractString, config::Config; now = Dates.now())
    path = current_collection_path(config)
    file_example = get_file_path(config; tag = name, now = now)
    println("[$name] index=$(config.state.current) path=$path")
    println("[$name] sample file -> $file_example")
end

println("""
TimestampedPaths demo
=====================
Variables now available in the session:
  primary_config      → Config simulating the coordinating host
  primary_paths       → Callable path generator bound to primary_config
  secondary_config    → Config simulating a follower host
  secondary_paths     → Callable path generator bound to secondary_config
Helper utilities:
  print_collection_state(name, config; now=DateTime)
  refresh_index!(config; now=DateTime, force=true/false)
  sync_to_latest_index!(config; now=DateTime)
  create_next_output_directory!(config; now=DateTime)
  primary_paths(; tag=..., now=DateTime)
""")

print_collection_state("primary", primary_config; now = start_time)
print_collection_state("secondary", secondary_config; now = start_time)

println("""
Suggested experiments:
  * create_next_output_directory!(primary_config)
  * sync_to_latest_index!(secondary_config)
  * ensure_collection_path!(primary_config)
  * increment_index!(secondary_config)

Use Ctrl+D (or exit()) to leave the REPL.
""")

function write_to_file(filename::String, msg::AbstractString = "File write")
    open((io)->write(io, msg), filename, "w")
end
