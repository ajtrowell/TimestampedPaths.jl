import TimestampedPaths
const TP = TimestampedPaths
using Logging

TP.set_log_level!(Logging.Info)

demo_root = joinpath(pwd(), "demo_data")

namer_config = TP.Config(
    root_dir = demo_root,
    subfolder_template = "yyyy_mmdd",
    timestamp_template = "yyyy_mmdd_HHMMSS",
    intermediate_template = nothing,
    extension = ".beve",
    start_index = 1,
);

path_generator = TP.PathGenerator(namer_config)

function write_to_file(filename::String, msg::AbstractString = "File write")
    open((io) -> write(io, msg), filename, "w")
end
