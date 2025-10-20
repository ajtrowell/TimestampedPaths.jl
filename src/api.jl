export NamerConfig

# API
"""
# NamerConfig
$(TYPEDFIELDS)
"""
@kwdef mutable struct NamerConfig
    "Directory to store timestamped folders in."
    root_dir::String = "./data_folder"
    pre_tag::String = ""
    post_tag::String = ""
    timestamp_template::String="yyyy_mmdd_HHMMSS"
    subfolder_template::Union{Nothing,AbstractString}="yyyy_mmdd"
    intermediate_template::Union{Nothing,AbstractString}=nothing
end

