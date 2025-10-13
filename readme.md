# TimestampedPaths.jl

Utilities for building reproducible, timestamped directory structures and filenames in Julia. The main goal is to point data acquisition jobs at a single root directory and let the package manage the daily folders, sequential indices, and standardized filenames.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/ashley/TimestampedPaths.jl")
```

The package is lightweight and only depends on the Julia standard library (`Dates` and `Logging`).

## Core ideas

- **Config** – describes how paths are generated (root directory, timestamp format, optional intermediate folder template, file extension, suffixes, etc.). Configs are now mutable so you can adjust settings like the intermediate folder template without rebuilding state.
- **IndexState** – tracks the current index for a particular day and keeps multiple processes in sync by scanning the filesystem on demand.
- **Helper functions** – `current_collection_path`, `ensure_collection_path!`, `get_file_path`, and `create_next_output_directory!` handle the repetitive pieces of path management.

To keep the derived state in sync when you tweak the intermediate template, use `set_intermediate_template!`.

## Usage examples

### Sequential files without an intermediate folder

The simplest workflow relies on a root directory and formatted timestamp. Calling `get_file_path` with an optional tag produces sequential filenames.

```julia
using Dates
using TimestampedPaths

config = Config(
    root_dir = "data",
    timestamp_template = "yyyy-mm-dd_HHMMSS",
    intermediate_template = nothing,  # no intermediate folder
    extension = ".dat"
)

state = IndexState(config)

# Ensure today's folder exists and get the first file path.
path = ensure_collection_path!(config, state)
filepath = get_file_path(config, state; tag="raw")

# -> data/2024-05-25/2024-05-25_103000_raw.dat
```

This pattern is ideal when you only need timestamped files and are comfortable sharing a single directory per day.

### Intermediate folders with sequential numbering

For richer organization, supply an intermediate template with `#` placeholders. You can adjust the template at runtime to reflect the current collection or experiment.

```julia
config = Config(
    root_dir = "data",
    timestamp_template = "yyyy-mm-dd_HHMMSS",
    intermediate_template = "run_##",
    extension = ".bin"
)

state = IndexState(config)

first_dir = ensure_collection_path!(config, state)
# -> data/2024-05-25/run_01

next_dir = create_next_output_directory!(config, state)
# -> data/2024-05-25/run_02

# Highlight a special collection by swapping the intermediate template.
set_intermediate_template!(config, "calibration_##")
state = IndexState(config)  # refresh the state for the new naming
calibration_dir = create_next_output_directory!(config, state)
# -> data/2024-05-25/calibration_01
```

Use `set_intermediate_template!` whenever you need to rename or remove the intermediate folder. The helper recalculates the padding width and prefix/suffix, so subsequent calls keep the numbering consistent.

## Features at a glance

- Timestamp-first directory layout (`root/YYYY-MM-DD[/intermediate]`).
- Coordinated indexing across multiple processes with filesystem discovery.
- Flexible file naming with optional suffixes and ad-hoc tags.
- Mutable configuration for on-the-fly folder template changes.
- Lightweight logging controls via `set_log_level!`, `log_info`, and `log_debug`.

## Recommended workflow

1. Create a single `Config` per data collection root.
2. Initialize an `IndexState` for each worker/process that writes into the collection.
3. Call `ensure_collection_path!` or `create_next_output_directory!` before writing files.
4. Generate filenames with `get_file_path`, optionally passing a tag to categorize the file.
5. When the folder naming scheme changes, call `set_intermediate_template!` and refresh the `IndexState`.

With these steps, you can focus on the data you are capturing while TimestampedPaths.jl keeps the filesystem tidy and predictable.
