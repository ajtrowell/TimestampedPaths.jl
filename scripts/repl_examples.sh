#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEPOT_PATH="${JULIA_DEPOT_PATH:-${PROJECT_ROOT}/.julia}"

export JULIA_DEPOT_PATH="${DEPOT_PATH}"

exec julia \
    --project="${PROJECT_ROOT}" \
    --startup-file=no \
    -i \
    "${PROJECT_ROOT}/scripts/repl_examples.jl"
