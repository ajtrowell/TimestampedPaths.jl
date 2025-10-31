export NamerConfig, NamerInterface, NamerState
export path_examples, api_demo, generate_path

"""
# NamerConfig
Path generating
Case 1, no per collection folder.
root_dir   /  date_folder/file_timestamp

./data_root/2025_/ yyyy_mmdd_HHMMSS_ stem
/home/bob  / 2025_0120   / 2025_0120_223455_<pretag><tag><posttag>

Case 2, per collection folder with index
root_dir   /  date_folder/ collection_folder_001 / timestamped_file
For a new collection, the index should be incremented.
Optionally, the collection folder name stem could also be changed to 
give some context for that collection of files.
If the stem name changes, that is a good indication that the 
index should increment.
Handling these folder names and indices helps when making 
collections with changing context. It also adds much of 
the complexity that exists in this system.

eg.
$(TYPEDFIELDS)
"""
@kwdef mutable struct NamerConfig
    "Directory to store timestamped folders in."
    root_dir::String = "./data_folder"
    """
    Filename: timestamp_template+_+pretag+tag+posttag
    The tag is provided when get_path() is run.
    """
    pre_tag::String = ""
    """
    Filename: timestamp_template+_+pretag+tag+posttag
    The tag is provided when get_path() is run.
    """
    post_tag::String = ""
    "Timestamp template representing the generated filename prefix."
    file_timestamp::String = "yyyy_mmdd_HHMMSS"
    """
    Date template representing the generated folder prefix.
    Appropriate to automatically create daily collection folders.
    """
    date_folder::Union{Nothing,AbstractString} = "yyyy_mmdd"
    """
    Optional intermediate folder inside the daily subfolder for 
    collecting multiple files from a single collection.
    This is most helpful when each logical event is generating 
    various data products.
    The intermediate folder would not have a data component. It would 
    be made up of a description, and a auto generated index.

    The logic for picking the initial index, when to increment the index, 
    and how to resume at the latest index, particularly on shared drives, 
    has some subtlety.
    """
    collection_folder::Union{Nothing,AbstractString} = nothing
end

const title_width = 30
function Base.show(io::IO, nc::NamerConfig)
    println(io, rpad("Namer Config  ", title_width, '-'))
    println(io, "    root_dir: ", nc.root_dir)
    println(io, "    pre_tag: ", nc.pre_tag)
    println(io, "    post_tag: ", nc.post_tag)
    println(io, "    file_timestamp: ", nc.file_timestamp)
    println(io, "    date_folder: ", nc.date_folder)
    println(io, "    collection_folder: ", nc.collection_folder)
    return nothing
end




"""
# NamerState
$(TYPEDFIELDS)
"""
@kwdef mutable struct NamerState
    "Most recent date time. Used when cached date time is desired."
    recent_datetime::DateTime = Dates.now()
    "Collection folder index [used only if collection_folder is defined]"
    folder_index::Int64 = 1
end



"""
# NamerInterface
$(TYPEDFIELDS)
"""
@kwdef mutable struct NamerInterface
    "Configuration for Namer."
    config::NamerConfig = NamerConfig()
    "State for Namer."
    state::NamerState = NamerState()
    "Generate new name path with fresh date"
    generate_path =
        (tag::String = ""; kwargs...) -> generate_path_from_config_and_state(
            config,
            state;
            date = Dates.now(),
            tag = tag,
            kwargs...,
        )
    """
    Generate new name path with cached data from previous generate_path().
    This can be helpful when a collection is run, but generates multiple 
    files which will get their own tags or file extensions.
    It can be helpful to have the same timestamp for a group of 
    associated files, and this lets them use a recently cached time.
    """
    generate_path_with_previous_date =
        (tag::String = "") -> generate_path_from_config_and_state(
            config,
            state;
            date = state.recent_datetime,
            tag = tag,
        )
end




function Base.show(io::IO, ni::NamerInterface)
    println(io, rpad("Namer Interface  ", title_width, '-'))
    println(io, "    config: \n", ni.config)
    println(io, "    state: \n", ni.state)
    println(io, "")
    println(io, "    generate_path(tag::String): ")
    println(io, "    generate_path_with_previous_date(tag::String): ")
    return nothing
end



# -------------
# Implementation
# -------------
# Generate folder names.
# Generate full folder path
# Create folder path string
# Create folder + file path string
# Handle intermediate folder

"""
# generate_path_from_config_and_state
Returns a path based on NamerConfig.
Ensures all intervening folder have been created.
"""
function generate_path_from_config_and_state(
    config::NamerConfig,
    state::NamerState;
    date::DateTime = Dates.now(),
    tag::String = "",
    create_folders = true,
)::String
    state.recent_datetime = date
    date_string = Dates.format(date, config.file_timestamp)
    stem = "$(config.pre_tag)$(tag)$(config.post_tag)"
    file_name = date_string * stem

    # Expand user turns ~ to path to user home
    root_folder = expanduser(config.root_dir)
    date_folder = Dates.format(date, config.date_folder)

    # Join paths. Only include collection folder if present.
    if isnothing(config.collection_folder)
        file_path = joinpath(root_folder, date_folder, file_name)
    else
        file_path = joinpath(root_folder, date_folder, config.collection_folder, file_name)
    end

    create_folders && mkpath(dirname(file_path))

    return file_path
end



function path_examples()
    gen = NamerInterface()
    get_date_folder =
        (args...; kwargs...) -> date_folder_name(gen.config, gen.state, args..., kwargs...)

    return () -> (; gen, get_date_folder)
end

function api_demo()
    pathgen::NamerInterface = NamerInterface()
    println("PWD: $(pwd())")
    pathgen.config.root_dir = "./demo_data/"
    pathgen.config.pre_tag = "_pretag_"
    pathgen.config.post_tag = ""
    pathgen.config.collection_folder = nothing

    # println("NamerInterface:")
    show(pathgen)

    @info fp1 = pathgen.generate_path("data_collect.dat")
    @info fp2 = pathgen.generate_path_with_previous_date("meta_data.json")


end
