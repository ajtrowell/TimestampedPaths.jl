using Dates
using Logging

using TimestampedPaths

set_log_level!(Logging.Info)

start_time = DateTime(2024, 10, 11, 9, 0)
demo_root = joinpath(pwd(), "demo_data")

primary_config = Config(
    root_dir = demo_root,
    timestamp_template = "yyyy-mm-dd_HHMMSS",
    extension = ".dat",
    suffix = "host",
    start_index = 1,
    now = start_time,
)
set_intermediate_stem!(primary_config, "set"; now = start_time)

secondary_config = Config(
    root_dir = demo_root,
    timestamp_template = primary_config.timestamp_template,
    extension = primary_config.extension,
    suffix = primary_config.suffix,
    start_index = primary_config.start_index,
    now = start_time,
)
set_intermediate_stem!(secondary_config, "set"; now = start_time)

primary_paths = PathGenerator(primary_config)
secondary_paths = PathGenerator(secondary_config)

function print_collection_state(
    name::AbstractString,
    paths::PathGenerator;
    now = Dates.now(),
)
    config = paths.config
    file_example = paths(tag = name, now = now)
    println("[$name] index=$(config.state.current) folder=$(dirname(file_example))")
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
  print_collection_state(name, primary_paths; now=DateTime)
  refresh_index!(config; now=DateTime, force=true/false)
  sync_to_latest_index!(config; now=DateTime)
  create_next_output_directory!(config; now=DateTime)
  set_intermediate_stem!(config, stem; min_index_width=2)
  set_subfolder_template!(config, "yyyymmdd")
  primary_paths(; tag=..., now=DateTime)
""")

print_collection_state("primary", primary_paths; now = start_time)
print_collection_state("secondary", secondary_paths; now = start_time)

println(
    """
  Suggested experiments:
    * create_next_output_directory!(primary_config)
    * sync_to_latest_index!(secondary_config)
    * ensure_collection_path!(primary_config)
    * increment_index!(secondary_config)
    * set_intermediate_stem!(primary_config, "calibration"; now=DateTime(2024, 10, 11, 9, 30))
    * set_subfolder_template!(primary_config, "yyyymmdd"; now=DateTime(2024, 10, 12))

  Use Ctrl+D (or exit()) to leave the REPL.
  """,
)

function write_to_file(filename::String, msg::AbstractString = "File write")
    open((io) -> write(io, msg), filename, "w")
end
