# TimestampedPaths.jl Implementation Plan

## Objectives
- Provide a synchronous, dependency-light Julia package for timestamped output management.
- Support configurable folder and file naming templates with date/time tokens and optional index digit placeholders.
- Replace prior thread-based monitoring with explicit helper calls so callers control when indices advance or directories are created.

## Core Configuration
- Introduce a `TimestampedPaths.Config` struct capturing:
  - `root_dir::String`
  - `timestamp_template::String` for filenames (strftime-like via `Dates.format`)
  - `intermediate_template::Union{Nothing,String}` for optional subfolders; treat `#` as the index digit placeholder.
  - `extension::String`
  - `suffix::Union{Nothing,String}` and per-call `tag::Union{Nothing,String}`
  - `start_index::Int` and `index_width::Union{Nothing,Int}` (derived from placeholder count when template supplied).
- Provide constructor validation:
  - Ensure root exists or is creatable.
  - Infer `index_width` from contiguous placeholder characters in `intermediate_template`; absence implies no automatic index usage.

## Utility Replacements
- `get_host_name()` → `TimestampedPaths.host_name()` using `gethostname()` from `Sockets` (cross-platform).
- `get_date_time_string()` → `TimestampedPaths.timestamp(::Dates.DateTime, template)` wrapping `Dates.format`.
- `highest_collection_index()` → `TimestampedPaths.highest_index(path, prefix, width)` scanning directory contents synchronously.
- Logging → minimal `TimestampedPaths.log_info(msg)` / `log_debug(msg)` wrappers delegating to `Logging` macros with configurable level thresholds; default output stays terse.

## Directory Lifecycle
- `current_collection_path(config, idx_state)`:
  - Build date-derived folder (always included) and optional intermediate subfolder by applying template with current index.
  - Do not create directories yet; return intended path.
- `ensure_collection_path!(...)`:
  - Create root/date/intermediate folders only when explicitly invoked (e.g., before writing a file).
  - Guard with `mkpath` and handle concurrent creation by wrapping in `try`; ignore `EEXIST`.
- `create_next_output_directory!(...)`:
  - Helper for multi-host scenarios; increments index state, materializes the folder, and returns the new path.
  - Treat existing directories as success so concurrent creators converge without hard errors.

## Index Management
- Maintain mutable state via `TimestampedPaths.IndexState`:
  - Fields: `current::Int`, `last_scanned::Union{Nothing,Dates.Date}` etc.
  - `refresh_index!(state, config; now=Dates.now(), force::Bool=false)` scans filesystem to recalc highest index; `force=true` guarantees a rescan even when the date has not rolled.
  - `refresh_index!` updates `state.current` to the highest observed index so collaborators can attach to an existing directory without incrementing.
  - `sync_to_latest_index!(state, config; now=Dates.now())` convenience wrapper that calls `refresh_index!` with `force=true`.
  - `increment_index!(state)` increments manually; caller decides when logical collection is complete.
- Determine initial index on load by scanning target directory once (`highest_index`).

## Filename Generation Workflow
1. Caller invokes `TimestampedPaths.get_file_path(config, state; tag=nothing, now=Dates.now())`.
2. Function:
   - Formats `now` using timestamp template.
   - Builds intermediate folder path using `state.current` and template (if defined).
   - Combines root, date folder (from timestamp parts), intermediate folder, and file name (timestamp + optional suffix/tag + extension).
   - Returns full path without creating directories.
3. Caller may call `ensure_collection_path!` before writing to guarantee folders exist.

## Public API Sketch
- `TimestampedPaths.Config(...)`
- `TimestampedPaths.IndexState(config; now=Dates.now())`
- `TimestampedPaths.get_file_path(config, state; tag=nothing, now=Dates.now())`
- `TimestampedPaths.ensure_collection_path!(config, state; now=Dates.now())`
- `TimestampedPaths.increment_index!(state)`
- `TimestampedPaths.create_next_output_directory!(config, state; now=Dates.now())`
- `TimestampedPaths.sync_to_latest_index!(state, config; now=Dates.now())`
- `TimestampedPaths.host_name()` / `TimestampedPaths.timestamp(...)`

## Testing Strategy
- Unit tests covering:
  - Template parsing and index width inference.
  - Filename/folder paths with and without intermediate placeholders.
  - Manual index increments reflected in generated paths.
  - `create_next_output_directory!` only touching filesystem when invoked.
- Integration-style test that simulates multi-machine scenario by racing `ensure_collection_path!` calls (use temporary dirs).

## Multi-System Coordination Scenario
- Coordinate shared network-drive writes by designating a primary host to call `create_next_output_directory!`, then broadcast the resulting index.
- Secondary hosts invoke `sync_to_latest_index!` (or `refresh_index!(; force=true)`) after the broadcast to align `state.current` with the on-disk highest index and write into the shared folder.
- For resilience, allow every host to attempt `create_next_output_directory!`; those that lose the race will see the directory already present, treat it as success, rescan with `sync_to_latest_index!`, and still share the same collection directory.
## Resolved Decisions
- Index digit placeholders use `#`; no additional symbol support planned for v1.
- Date-based folder component is required and always derived from the timestamp template output.
- Logging integrates with Julia logging levels; default behavior emits only level-appropriate messages.
