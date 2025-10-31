export set_log_level!, log_info, log_debug

const _LOG_LEVEL = Ref{LogLevel}(Logging.Warn)

set_log_level!(level::LogLevel) = (_LOG_LEVEL[] = level)

@inline function _should_log(level::LogLevel)
    Int(level) >= Int(_LOG_LEVEL[])
end

function log_info(msg)
    _should_log(Logging.Info) && @info msg
    return nothing
end

function log_debug(msg)
    _should_log(Logging.Debug) && @debug msg
    return nothing
end
