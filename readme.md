# TimestampedPaths.jl

`NamerInterface` provides a compact workflow for building timestamped folder structures and filenames. Point it at a root directory, configure optional prefixes/suffixes, and it will keep the daily folders and collection indices tidy while you focus on writing data.

## Installation

```julia
using Pkg
Pkg.add(url = "https://github.com/ashley/TimestampedPaths.jl")
```

## Path anatomy

Each generated path is composed of four pieces:

1. **Root directory** – `config.root_dir`, expanded with `~` if present.
2. **Date folder** – formatted with `config.date_folder` (defaults to `"yyyy_mmdd"`). Set to `nothing` to skip the date layer.
3. **Optional collection folder** – only present when `config.collection_folder` is a string. The name is `"<collection_folder>_<index>"` where the index is zero-padded to `config.width_of_collection_index`.
4. **Filename** – `Dates.format(now, config.file_timestamp) * config.pre_tag * tag * config.post_tag`. The `tag` argument is supplied when you request a path, and the timestamp can be cached for follow-up files.

Example layout:

```
/data_root/
└── 2025_0120/
    └── capture_003/
        └── 2025_0120_223455_pre_temperature_post.dat
```

## Quick start

```julia
using TimestampedPaths

namer = NamerInterface(
    config = NamerConfig(
        root_dir = "./data",
        pre_tag = "_pre_",
        post_tag = "_post.dat",
        collection_folder = "capture",
        width_of_collection_index = 3,
    ),
)

path = namer.generate_path("thermocouple")
```

This will create any missing directories and return a full path such as
`./data/2025_0120/capture_001/2025_0120_223455_pre_thermocouple_post.dat`.

### Reusing timestamps within a collection

`generate_path_with_cached_timestamp` keeps the most recent timestamp so related files share the same prefix.

```julia
first = namer.generate_path("raw")
second = namer.generate_path_with_cached_timestamp("metadata")
```

### Managing collection indices

`NamerState` tracks `folder_index`. Call `namer.increment_collection_index()` to advance manually, or `namer.scan_and_set_collection_index()` to rescan the filesystem and resume after the highest existing suffix. Construction performs one scan automatically when a collection folder is configured.

## Configuration reference

- `root_dir` – where all dated folders live. Use absolute paths or strings with `~`.
- `file_timestamp` – timestamp pattern for filenames (`"yyyy_mmdd_HHMMSS"` by default).
- `date_folder` – pattern for the date layer (always required).
- `collection_folder` – base name for per-collection folders; omit or set to `nothing` to write files directly inside the date folder.
- `width_of_collection_index` – padding for the numeric suffix that follows the collection folder base.
- `pre_tag` / `post_tag` – static text wrapped around the per-file `tag` argument.

## Logging helpers

`set_log_level!(Logging.Info)` adjusts the module-wide log threshold. `log_info("message")` and `log_debug("...")` only emit when the requested level meets the current threshold (wrapping Julia’s `@info` / `@debug`).

## Developing / testing

Run the test suite via the repo helper script:

```bash
scripts/agent/run-tests.sh
```

## Sandbox

This repository vendors a Julia depot via [`scripts/agent/run-julia.sh`](scripts/agent/run-julia.sh), keeping dependencies local to the project.
