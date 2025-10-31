
#!/usr/bin/env bash
set -euo pipefail

# Switch to project directory
script_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
cd "$script_dir/.."
echo "Project Directory:  $(pwd)"

julia -i --project=. -e 'using Revise, TimestampedPaths;
api_demo()
'

