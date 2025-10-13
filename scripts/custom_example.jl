import TimestampedPaths
const TP = TimestampedPaths
using Logging

set_log_level!(Logging.Info)

demo_root = joinpath(pwd(), "demo_outputs")

namer_config = TP.Config(
    root_dir = demo_root,
    subfolder_template = "yyyy_mmdd",
    timestamp_template = "yyyy_mmdd_HHMMSS",
    intermediate_template = "collection_##",
    suffix = "suffix",
    extension = ".beve",
    suffix = nothing,
    start_index = 1,
);

namer_state = IndexState(namer_config; now = Dates.now())

function write_to_file(filename::String, msg::AbstractString = "File write")
    open((io)->write(io, msg), filename, "w")
end

