#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
VALIDATION="$ROOT/validation"

"$VALIDATION/tools/capture-side-matrix.sh"
"$VALIDATION/tools/compose-side-evidence.py"
"$VALIDATION/tools/capture-volume-matrix.sh"
"$VALIDATION/tools/compose-volume-evidence.py"

echo "FULL VISUAL OK - native side parity, material volumes, and view projections"
