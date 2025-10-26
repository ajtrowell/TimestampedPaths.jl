module NestedPrintExample

include(joinpath(@__DIR__, "utility.jl"))

using .TimestampedPathsPretty
using Dates

import Base: show

struct DemoConfig
    root_dir::String
    pre_tag::String
    post_tag::String
    timestamp_template::String
    subfolder_template::Union{Nothing,String}
end

struct DemoState
    recent_datetime::Date
end

struct DemoInterface
    config::DemoConfig
    state::DemoState
end

@define_shower DemoConfig
@define_shower DemoState

function show(io::IO, ::MIME"text/plain", interface::DemoInterface)
    println_indented(io, "DemoInterface")
    inner = indent_context(io)
    ind = indenter(inner)
    ind("config:")
    show(indenter_context(ind), MIME"text/plain"(), interface.config)
    ind("state:")
    show(indenter_context(ind), MIME"text/plain"(), interface.state)
    return nothing
end

function show(io::IO, interface::DemoInterface)
    show(io, MIME"text/plain"(), interface)
    return nothing
end

function run_demo(io::IO=stdout)
    config = DemoConfig(
        "data/output",
        "pre_",
        "_post",
        "yyyy_mmdd_HHMMSS",
        "yyyy_mmdd",
    )
    state = DemoState(Date(2024, 1, 31))
    interface = DemoInterface(config, state)
    show(io, MIME"text/plain"(), interface)
    println(io)
    return interface
end

end # module NestedPrintExample

if abspath(PROGRAM_FILE) == @__FILE__
    using .NestedPrintExample
    NestedPrintExample.run_demo()
end
