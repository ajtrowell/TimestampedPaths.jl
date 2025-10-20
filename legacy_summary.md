# TimestampedPaths.jl Legacy Summary

## High-Level Flow
- The `Config` object encapsulates all runtime settings, including filesystem layout, naming templates, index state, and suffix/extension handling.
- `IndexState` tracks the current index number, the highest index observed on disk, the date of the last scan, and the date considered "active" for naming and directory creation.
- Construction of `Config` precomputes template metadata, normalizes input, initializes state, and immediately calls `refresh_index!` to synchronize against existing directories.
- `PathGenerator` wraps a `Config` and lazily produces file paths while maintaining state alignment; it ensures indexes advance correctly when placeholder ranges are used.

## Directory & Filename Derivation
- `current_collection_path` combines the root directory with the current date folder (derived from `subfolder_template` or timestamp template) plus an optional intermediate folder if index placeholders exist.
- `ensure_collection_path!` and `create_next_output_directory!` coordinate state alignment and directory creation, invoking `_align_state_date!`/`refresh_index!` as needed so the filesystem mirrors the in-memory state.
- `get_file_path` assembles filenames from the timestamp template, optional suffix, and optional tag; it can optionally ensure the containing directory exists.
- Intermediate folders rely on `_compute_intermediate_metadata`, `_format_intermediate`, and `_scan_highest_index` to parse and maintain zero-padded numeric suffixes inside date folders.

## State Synchronization Helpers
- `refresh_index!` reconciles `IndexState` with the filesystem: it scans the current date folder for the highest numeric intermediate directory, then resets `current`, `highest_seen`, `last_scan_date`, and `active_date`.
- `_align_state_date!` is a light wrapper that forces a refresh when the active date drifts from the requested timestamp, keeping daily boundaries consistent.
- `_promote_to_next_index!` and `increment_index!` advance the index while preserving `highest_seen`.

## Logging & Configuration Mutators
- `set_intermediate_template!`, `set_intermediate_stem!`, and `set_subfolder_template!` (alias `set_date_template!`) update templates and optionally force a full state refresh so future path generation matches the new layout.
- When placeholder ranges are active, these helpers ensure that changes preserve monotonic index allocation by refreshing state and, if necessary, promoting to the next index.

## Role of `last_scan_date`
- `last_scan_date` (held in `IndexState`) records the calendar day when `_scan_highest_index` most recently ran. It prevents redundant filesystem scans when multiple calls occur within the same day and the state remains aligned.
- `refresh_index!` uses `last_scan_date` to decide whether to rescan; if the date has not changed and the state is already aligned, the expensive directory traversal is skipped.
- When `last_scan_date` is `nothing` (initial startup) or differs from the current day, `refresh_index!` performs the scan, then sets both `last_scan_date` and `active_date` to the new date.
- Without `last_scan_date`, the system would need to rescan each request or rely solely on `active_date`, potentially increasing filesystem overhead.

## Role of `active_date`
- `active_date` identifies which day the in-memory index refers to; it is updated whenever `refresh_index!` runs for a new day.
- All path generation functions call `_align_state_date!` (which may refresh) to keep `active_date` equal to the date derived from the provided `now` timestamp. This ensures new files created after midnight automatically switch to the new day's directory.
- `ensure_collection_path!` uses `active_date` to determine the directory to create. It also updates `highest_seen` once a directory is materialized, keeping state consistent.
- For intermediate folders, `active_date` determines which date subdirectory to scan and ensures separate daily index sequences. Removing `active_date` would require deriving the target date from the caller every time or embedding it in each helper call.

## Interaction Between `last_scan_date` and `active_date`
- `refresh_index!` aligns both values together whenever a scan happens: the active date advances, and last scan date records when that alignment occurred.
- `_align_state_date!` uses `active_date` to detect drift; when drift is detected, a forced refresh resets both fields and rescans the filesystem.
- This dual-tracking avoids unnecessary rescans (via `last_scan_date`) while still guaranteeing that daily rollovers are handled (via `active_date`).
- If both were removed, the module would need an alternative strategy to differentiate "already scanned today" from "needs to switch to a new day's directory," possibly increasing contention or requiring every call to supply the intended date explicitly.

