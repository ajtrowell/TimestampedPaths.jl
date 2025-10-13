using Dates
using Logging

using TimestampedPaths

set_log_level!(Logging.Info)

demo_root = joinpath(pwd(), "demo_outputs")

demo_config = Config(
    root_dir = demo_root,
    timestamp_template = "yyyy-mm-dd_HHMMSS",
    intermediate_template = "set_##",
    extension = ".dat",
    suffix = "host",
    start_index = 1,
)

primary_state = IndexState(demo_config; now = DateTime(2024, 10, 11, 9, 0))
secondary_state = IndexState(demo_config; now = DateTime(2024, 10, 11, 9, 0))

function print_collection_state(name::AbstractString, state::IndexState; now = Dates.now())
    path = current_collection_path(demo_config, state)
    file_example = get_file_path(demo_config, state; tag = name, now = now)
    println("[$name] index=$(state.current) path=$path")
    println("[$name] sample file -> $file_example")
end

println("""
TimestampedPaths demo
=====================
Variables now available in the session:
  demo_config        → shared Config rooted at $(demo_root)
  primary_state      → IndexState simulating the coordinating host
  secondary_state    → IndexState simulating a follower host
Helper utilities:
  print_collection_state(name, state; now=DateTime)
  refresh_index!(state, demo_config; now=DateTime, force=true/false)
  sync_to_latest_index!(state, demo_config; now=DateTime)
  create_next_output_directory!(demo_config, state; now=DateTime)
""")

print_collection_state("primary", primary_state; now = DateTime(2024, 10, 11, 9, 0))
print_collection_state("secondary", secondary_state; now = DateTime(2024, 10, 11, 9, 0))

println("""
Suggested experiments:
  * create_next_output_directory!(demo_config, primary_state)
  * sync_to_latest_index!(secondary_state, demo_config)
  * ensure_collection_path!(demo_config, primary_state)
  * increment_index!(secondary_state)

Use Ctrl+D (or exit()) to leave the REPL.
""")


function write_to_file(filename::String, msg::AbstractString = "File write")
    open((io)->write(io, msg), filename, "w")
end
