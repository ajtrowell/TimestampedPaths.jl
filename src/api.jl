export NamerConfig, NamerInterface

"""
# NamerConfig
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
    timestamp_template::String="yyyy_mmdd_HHMMSS"
    """
    Date template representing the generated folder prefix.
    Appropriate to automatically create daily collection folders.
    """
    subfolder_template::Union{Nothing,AbstractString}="yyyy_mmdd"
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
    intermediate_template::Union{Nothing,AbstractString}=nothing
end


function Base.show(io::IO, nc::NamerConfig)
    println(io, "Namer Config")
    println(io, "    root_dir: ", nc.root_dir)
    println(io, "    pre_tag: ", nc.pre_tag)
    println(io, "    post_tag: ", nc.post_tag)
    println(io, "    timestamp_template: ", nc.timestamp_template)
    println(io, "    subfolder_template: ", nc.subfolder_template)
    println(io, "    intermediate_template: ", nc.intermediate_template)
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
    generate_path::Function = (tag::AbstractString)->"Undefined: $(tag)"
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
