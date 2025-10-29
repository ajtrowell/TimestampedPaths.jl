# TimestampedPaths.jl

Utilities for building reproducible, timestamped directory structures and filenames in Julia. The main goal is to point data acquisition jobs at a single root directory and let the package manage the daily folders, sequential indices, and standardized filenames.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/ashley/TimestampedPaths.jl")
```

The package is lightweight and only depends on the Julia standard library (`Dates` and `Logging`).

## TLDR; simple workflow - in development
To just get date stamped folders with time stamped files, 
here is a minimal workflow.
```julia
using TimestampedPaths
TP = TimestampedPaths

path_generator = TP.PathGenerator(TP.Config(root_dir="./data",extension=".dat"))
new_path = path_generator(tag="file_name_stem");
```

## Core ideas

- **Config** – describes how paths are generated (root directory, timestamp format, optional intermediate folder template, file extension, suffixes, etc.) and owns a mutable indexing state accessible as `config.state`.
- **IndexState** – still available when you need additional independent state objects (for example, a bespoke synchronization strategy), but most code can rely on the state that ships with each `Config`.
- **Helper functions** – `current_collection_path`, `ensure_collection_path!`, `get_file_path`, and `create_next_output_directory!` handle the repetitive pieces of path management. `PathGenerator` wraps a `Config` and exposes a callable that yields fresh paths on demand.

To keep the derived state in sync when you tweak the intermediate template, use `set_intermediate_stem!` for stem-based names (it builds the padding for you) or `set_intermediate_template!` if you need full control over the placeholder string. Use `set_subfolder_template!` only when you want to change the date folder format.

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

paths = PathGenerator(config)

# Ensure today's folder exists and get the first file path.
filepath = paths()
tagged = paths(tag="raw")

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

paths = PathGenerator(config)

first_dir = ensure_collection_path!(config)
# -> data/2024-05-25/run_01

next_dir = create_next_output_directory!(config)
# -> data/2024-05-25/run_02

# Highlight a special collection by swapping the intermediate template.
set_intermediate_stem!(config, "calibration")
calibration_dir = create_next_output_directory!(config)
# -> data/2024-05-25/calibration_01
```

Use `set_intermediate_stem!` to rename or remove the intermediate folder without thinking about `#` placeholders (pass `nothing` to disable it). The helper recalculates the padding width, bumps the index so the next run picks up cleanly, and keeps subsequent calls consistent. For bespoke patterns, fall back to `set_intermediate_template!`. Reach for `set_subfolder_template!` if you only need to change the outer date folder.

## Features at a glance

- Timestamp-first directory layout (`root/YYYY-MM-DD[/intermediate]`).
- Coordinated indexing across multiple processes with filesystem discovery.
- Flexible file naming with optional suffixes and ad-hoc tags.
- Mutable configuration for on-the-fly folder template changes.
- Lightweight logging controls via `set_log_level!`, `log_info`, and `log_debug`.

## Recommended workflow

1. Create a `Config` per data collection root (or per worker if you prefer isolated state). Each `Config` carries its active `IndexState` at `config.state`.
2. Call `ensure_collection_path!` or `create_next_output_directory!` before writing files.
3. Generate filenames with `get_file_path` (it now ensures directories automatically) or keep a `PathGenerator` handy for repeated calls; optionally pass a tag to categorize the file.
4. When the intermediate folder naming scheme changes, call `set_intermediate_stem!` (or `set_intermediate_template!` for bespoke patterns). Supply `now=` if you need to anchor the change to a specific timestamp. Use `set_subfolder_template!` to reformat the date folder if needed.

With these steps, you can focus on the data you are capturing while TimestampedPaths.jl keeps the filesystem tidy and predictable.

## Sandaboxing
Provisioned with
https://github.com/ajtrowell/shared_julia_depot
