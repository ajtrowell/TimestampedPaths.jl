module TimestampedPathsPretty

export indent_level,
    indent_context,
    print_indent,
    print_indented,
    println_indented,
    show_block,
    Indenter,
    indenter,
    indenter_context,
    @define_shower

const INDENT_KEY = :timestampedpaths_indent
const DEFAULT_STEP = 4

"""
    indent_level(io::IO) -> Int

Return the current indentation level stored on the IO context.
"""
function indent_level(io::IO)
    return Int(get(io, INDENT_KEY, 0))
end

"""
    indent_context(io::IO; extra::Integer=DEFAULT_STEP) -> IO

Create a child `IOContext` with the indentation key increased by `extra`.
"""
function indent_context(io::IO; extra::Integer = DEFAULT_STEP)
    base = indent_level(io)
    new_level = max(base + Int(extra), 0)
    return IOContext(io, INDENT_KEY => new_level)
end

"""
    print_indent(io::IO; extra::Integer=0)

Emit the current indentation (plus `extra`) as spaces on `io`.
"""
function print_indent(io::IO; extra::Integer = 0)
    width = max(indent_level(io) + Int(extra), 0)
    width == 0 && return nothing
    print(io, repeat(" ", width))
    return nothing
end

"""
    print_indented(io::IO, args...; extra::Integer=0)

Print `args...` prefixed by the current indentation (plus `extra`) without a newline.
"""
function print_indented(io::IO, args...; extra::Integer = 0)
    print_indent(io; extra = extra)
    print(io, args...)
    return nothing
end

"""
    println_indented(io::IO, args...; extra::Integer=0)

Print `args...` prefixed by the current indentation (plus `extra`) and terminate the line.
"""
function println_indented(io::IO, args...; extra::Integer = 0)
    print_indent(io; extra = extra)
    println(io, args...)
    return nothing
end

"""
    show_block(io::IO, label::AbstractString, f::Function; extra::Integer=DEFAULT_STEP)

Emit `label` at the current indentation, then call `f` with an IO context whose
indentation is increased by `extra`.
"""
function show_block(
    io::IO,
    label::AbstractString,
    f::Function;
    extra::Integer = DEFAULT_STEP,
)
    println_indented(io, label)
    inner_io = indent_context(io; extra = extra)
    f(inner_io)
    return nothing
end

"""
    Indenter(io::IO; extra::Integer=0)

Capture an IO context (optionally increasing indentation once) and expose a
callable for repeated indented `println`.
"""
struct Indenter
    io::IO
end

"""
    indenter(io::IO; extra::Integer=0) -> Indenter

Helper constructor that bumps indentation once and returns an `Indenter`.
"""
function indenter(io::IO; extra::Integer = 0)
    new_io = indent_context(io; extra = extra)
    return Indenter(new_io)
end

function (ind::Indenter)(args...)
    println_indented(ind.io, args...)
    return nothing
end

"""
    indenter_context(ind::Indenter; extra::Integer=DEFAULT_STEP)

Create a nested context relative to the stored IO.
"""
function indenter_context(ind::Indenter; extra::Integer = DEFAULT_STEP)
    return indent_context(ind.io; extra = extra)
end

"""
    @define_shower TypeName

Emit `show` methods for `TypeName` that list fields with indentation helpers.
"""
macro define_shower(T)
    value_sym = gensym(:value)
    expr = quote
        function Base.show(io::IO, ::MIME"text/plain", $value_sym::$T)
            type_label = nameof(typeof($value_sym))
            TimestampedPathsPretty.println_indented(io, string(type_label))
            inner_io = TimestampedPathsPretty.indent_context(io)
            for fname in fieldnames(typeof($value_sym))
                TimestampedPathsPretty.println_indented(
                    inner_io,
                    string(fname),
                    ": ",
                    getfield($value_sym, fname),
                )
            end
            return nothing
        end
        function Base.show(io::IO, $value_sym::$T)
            show(io, MIME"text/plain"(), $value_sym)
            return nothing
        end
    end
    return esc(expr)
end

end # module TimestampedPathsPretty
