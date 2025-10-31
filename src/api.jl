# Primary Interface
export NamerConfig, NamerInterface, NamerState
export set_next_collection_index!

# Demos
export api_demo

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
    "Minimum width of index appended to collection folder."
    width_of_collection_index::Int = 2
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
    println(io, "    width_of_collection_index: ", nc.width_of_collection_index)
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
    folder_index::Int = 1
end



"""
# NamerInterface
$(TYPEDFIELDS)
"""
@kwdef mutable struct NamerInterface
    "Configuration for Namer."
    config::NamerConfig = NamerConfig()
    "State for Namer."
    state::NamerState = NamerState(folder_index = find_next_collection_index(config))
    "Generate new name path with fresh date"
    generate_path =
        (tag::String = ""; kwargs...) ->
            generate_path_from_config_and_state(config, state; tag = tag, kwargs...)
    """
    Generate new name path with cached data from previous generate_path().
    This can be helpful when a collection is run, but generates multiple 
    files which will get their own tags or file extensions.
    It can be helpful to have the same timestamp for a group of 
    associated files, and this lets them use a recently cached time.
    """
    generate_path_with_previous_date =
        (tag::String = ""; kwargs...) -> generate_path_from_config_and_state(
            config,
            state;
            reuse_cached_datetime = true,
            tag = tag,
            kwargs...,
        )
    "Manually advance collection folder index"
    increment_collection_index = () -> state.folder_index += 1
    ""
    scan_and_set_collection_index = () -> set_next_collection_index!(state, config)
end




function Base.show(io::IO, ni::NamerInterface)
    println(io, rpad("Namer Interface  ", title_width, '-'))
    println(io, "    config: \n", ni.config)
    println(io, "    state: \n", ni.state)
    println(io, "")
    println(io, "    generate_path(tag::String): ")
    println(io, "    generate_path_with_previous_date(tag::String): ")
    println(io, "    increment_collection_index(): ")
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

Combines lots of options for different use cases, 
somewhat confusing for that. Intended to be a lower level helper 
that functions are defined around to expose a particular 
subset of these functions, consisten with a workflow.

Returns a path based on NamerConfig.
Ensures all intervening folder have been created. [option]
`tag` is the easy to change part of the name.
<timestamp><pretag><tag><posttag>
`reuse_cached_datetime` defaults to false.  
When reuse is false, it checks the current Dates.now() on each call. 
When reuse is it is true, it uses the cached date.
Useful when caller wants a group of files with the same timestamp.
"""
function generate_path_from_config_and_state(
    config::NamerConfig,
    state::NamerState;
    reuse_cached_datetime = false,
    tag::String = "",
    create_folders = true,
)::String

    # Date: cached or new?
    # Nice if caller wants a group of files with the same timestamp.
    if reuse_cached_datetime
        date = state.recent_datetime
    else
        date = Dates.now()
        state.recent_datetime = date
    end


    # file_name
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
        collection_folder =
            config.collection_folder *
            "_" *
            lpad(state.folder_index, config.width_of_collection_index, '0')
        file_path = joinpath(root_folder, date_folder, collection_folder, file_name)
    end

    create_folders && mkpath(dirname(file_path))

    return file_path
end




"""
# get_date_folder_path
Returns a date folder path based on NamerConfig.
Ensures all intervening folder have been created.
Used when the date folder path is desired, not a file path.
"""
function get_date_folder_path(config::NamerConfig, create_folders = true)::String

    date = Dates.now()

    # Expand user turns ~ to path to user home
    root_folder = expanduser(config.root_dir)
    date_folder = Dates.format(date, config.date_folder)

    # Join paths. Only include collection folder if present.
    date_folder_path = joinpath(root_folder, date_folder)
    # Conditionally create folders
    create_folders && mkpath(date_folder_path)

    return date_folder_path
end


# Collection Folder Index Utilities
# A little trickier since the stem could change, and the indices could be 
# duplicated if there is an error or a race.
# Also, the initial NamerState.folder_index needs to be determied by 
# scanning the folder.
# If multiple systems are writting to a folder, there could be race conditions.

"""
# find_highest_collection_index_info(parent::AbstractString)
Search folders in given path for any ending in the pattern
<base>_<index>
Return the highest index found, and a list of the bases.
In general, the max_index is all we need to know, as we 
typically just want to set our folder_index to one higher.
It may be useful to know in some cases whether there is a 
duplicate index on a different base.
"""
function find_highest_collection_index_info(parent::AbstractString)

    pattern = r"^(.*)_(\d+)$"
    # We'll track:
    # max_idx::Int or nothing if none found
    # bases_for_max::Set{String} of bases that use max_idx
    max_idx = nothing
    bases_for_max = Set{String}()

    for path in filter(isdir, readdir(expanduser(parent); join = true))
        name = basename(path)
        m = match(pattern, name)
        m === nothing && continue

        base = m.captures[1]
        idx = parse(Int, m.captures[2])

        if max_idx === nothing || idx > max_idx
            # new global max → reset the set
            max_idx = idx
            empty!(bases_for_max)
            push!(bases_for_max, base)
        elseif idx == max_idx
            # same as current max → add this base too
            push!(bases_for_max, base)
        end
    end

    # Build a nice result struct/dict
    if max_idx === nothing
        return (
            found_any = false,
            max_index = nothing,
            bases = String[],
            multi_base = false,
        )
    else
        bases_vec = collect(bases_for_max)
        return (
            found_any = true,
            max_index = max_idx,
            bases = bases_vec,
            multi_base = length(bases_vec) > 1,
        )
    end
end


"Return 1 + highest collection index found in given path."
function find_next_collection_index(parent::AbstractString)::Int
    (; max_index) = find_highest_collection_index_info(parent)
    if isnothing(max_index)
        return 1
    else
        return 1 + max_index
    end
end

"""
Return 1 + highest collection index found in given path.
"""
function find_next_collection_index(config::NamerConfig)::Int
    date_folder_path = get_date_folder_path(config)
    next_index = find_next_collection_index(date_folder_path)
    return next_index
end

"""
# set_next_collection_index!(NamerInterface)
# set_next_collection_index!(NamerState, NamerConfig)
If config root_dir path is adjusted, the index 
may be invalidated.  Run to scan new folder for the highest index, 
and set the state.folder_index to one more.
"""
function set_next_collection_index!(state::NamerState, config::NamerConfig)
    next_index = find_next_collection_index(config)
    state.folder_index = next_index
end

set_next_collection_index!(interface::NamerInterface) =
    set_next_collection_index!(interface.state, interface.config)




# Example code

function touch_file(file_path::AbstractString)
    open(file_path, "w") do io
        println(io, "")
    end
end


function api_demo()
    pathgen::NamerInterface = NamerInterface()
    println("PWD: $(pwd())")
    pathgen.config.root_dir = "./demo_data/"
    pathgen.config.pre_tag = "_pretag_"
    pathgen.config.post_tag = ""
    pathgen.config.collection_folder = nothing
    set_next_collection_index!(pathgen)

    # println("NamerInterface:")
    show(pathgen)

    files = String[]
    push!(files, pathgen.generate_path("data_collect.dat"))
    sleep(2)
    push!(files, pathgen.generate_path_with_previous_date("meta_data.json"))

    @info "Starting collection_folder"
    pathgen.config.collection_folder = "collection"
    push!(files, pathgen.generate_path("data_collect.dat"))
    sleep(1)
    push!(files, pathgen.generate_path("data_collect.dat"))
    sleep(1)
    pathgen.increment_collection_index()
    push!(files, pathgen.generate_path("data_collect.dat"))

    # Display and save
    for file in files
        @info file
        touch_file(file)
    end

    date_folder_path = get_date_folder_path(pathgen.config)
    next_index = find_next_collection_index(date_folder_path)
    #next_index = find_next_collection_index(pathgen.config)
    @info "Next Index: $(next_index)"


    other_next_index = find_next_collection_index(pathgen.config)
    @info "Other Next Index: $(other_next_index)"
end
