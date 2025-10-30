export NamerConfig, NamerInterface, NamerState
export date_folder_name, path_examples, api_demo, generate_new_path

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
    file_timestamp::String="yyyy_mmdd_HHMMSS"
    """
    Date template representing the generated folder prefix.
    Appropriate to automatically create daily collection folders.
    """
    date_folder::Union{Nothing,AbstractString}="yyyy_mmdd"
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
    collection_folder::Union{Nothing,AbstractString}=nothing
end


function Base.show(io::IO, nc::NamerConfig)
    println(io, "Namer Config")
    println(io, "    root_dir: ", nc.root_dir)
    println(io, "    pre_tag: ", nc.pre_tag)
    println(io, "    post_tag: ", nc.post_tag)
    println(io, "file_timestamp: ", nc.file_timestamp)
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
    recent_datetime::Date = Dates.now()
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
    generate_path = (this_tag::String)-> generate_new_path(
        config, state, date = Dates.now(), tag = this_tag)
    """
    Generate new name path with cached data from previous generate_path().
    This can be helpful when a collection is run, but generates multiple 
    files which will get their own tags or file extensions.
    It can be helpful to have the same timestamp for a group of 
    associated files, and this lets them use a recently cached time.
    """
    generate_path_with_previous_date::Function = (tag::AbstractString)->"Undefined: $(tag)  $(state.recent_datetime)"
end




function Base.show(io::IO, ni::NamerInterface)
    println(io, "Namer Interface")
    println(io, "    config: ", ni.config)
    println(io, "    state: ", ni.state)
    println(io, "    generate_path(tag::String): ")
    println(io, "    generate_path_with_previous_date(tag::String): ")
#=
    println(io, "    RPC: ",
        REPE.isconnected(sh.embedded) ? "Connected" : "Disconnected"
    )
    println(io, "    RDMA: ",
        is_running(sh.rdma_adapter) ? "Connected" : "Disconnected"
    )
=#
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
# generate_new_path()
Returns a path based on NamerConfig.
Ensures all intervening folder have been created.
"""
function generate_new_path(config::NamerConfig,state::NamerState; date::DateTime = Dates.now(), tag::String = "")::String
    date_string = Dates.format(date, config.file_timestamp)
    stem = "$(config.pre_tag)$(tag)$(config.post_tag)"
    filename = date_string * stem 
    
    return filename
end

"Returns the date folder name, not the entire path."
function date_folder_name(config::NamerConfig,state::NamerState; date::DateTime = Dates.now())::String
    return ""
end

function path_examples()
    gen = NamerInterface()
    get_date_folder = (args...;kwargs...) -> date_folder_name(gen.config, gen.state, args..., kwargs...);

    return () -> (;gen, get_date_folder)
end

function api_demo()



end
