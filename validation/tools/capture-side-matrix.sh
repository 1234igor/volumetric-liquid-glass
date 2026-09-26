#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
VALIDATION="$ROOT/validation"
RAW="$VALIDATION/captures/raw/side"
SWIFT_PROCESS=LiquidGlassReference
SWIFT_OWNER="Liquid Glass Reference"
VARIANTS=${MATRIX_VARIANTS:-"regular clear regular-tinted clear-tinted identity"}
BACKGROUNDS=${MATRIX_BACKGROUNDS:-"harbour city-night prism facade"}
reference_pid=
reference_log=$(mktemp -t volumetric-liquid-glass-reference)

stop_reference() {
	[ -n "$reference_pid" ] || return 0
	if kill -0 "$reference_pid" 2>/dev/null; then
		kill -TERM "$reference_pid" 2>/dev/null || true
	fi
	for _attempt in $(seq 1 50); do
		kill -0 "$reference_pid" 2>/dev/null || {
			wait "$reference_pid" 2>/dev/null || true
			reference_pid=
			return 0
		}
		sleep 0.1
	done
	echo "forcing owned $SWIFT_PROCESS process $reference_pid to stop" >&2
	kill -KILL "$reference_pid" 2>/dev/null || true
	wait "$reference_pid" 2>/dev/null || true
	reference_pid=
}

title_case() {
	printf '%s' "$1" | awk -F- '{ for (i = 1; i <= NF; i++) { $i = toupper(substr($i, 1, 1)) substr($i, 2) } } 1' OFS=' '
}

cleanup() {
	set +e
	stop_reference
	rm -f "$reference_log"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

for background in harbour city-night prism facade; do
	cmp -s \
		"$ROOT/assets/backgrounds/$background.png" \
		"$VALIDATION/reference-swiftui/Sources/LiquidGlassReference/Resources/$background.png" || {
		echo "reference asset mismatch: $background.png" >&2
		exit 1
	}
done

if [ "${SKIP_NATIVE_BUILD:-0}" != "1" ]; then
	developer_dir=${DEVELOPER_DIR:-$(xcode-select -p)}
	module_cache=${TMPDIR:-/private/tmp}/volumetric-liquid-glass-swift-modules
	(
		cd "$VALIDATION/reference-swiftui"
		CLANG_MODULE_CACHE_PATH="$module_cache" \
		SWIFTPM_MODULECACHE_OVERRIDE="$module_cache" \
		DEVELOPER_DIR="$developer_dir" \
		swift build -c debug
	)
fi

for background in $BACKGROUNDS; do
	for variant in $VARIANTS; do
		output="$RAW/$background/$variant"
		mkdir -p "$output"

		if [ "${REUSE_NATIVE:-0}" != "1" ] || [ ! -s "$output/swiftui.png" ]; then
			stop_reference
			"$VALIDATION/reference-swiftui/run.sh" "$variant" debug "$background" >"$reference_log" 2>&1 &
			reference_pid=$!
			sleep 2
			xcrun swift "$VALIDATION/tools/move-pointer.swift"
			osascript -e 'tell application "System Events" to set frontmost of first application process whose name is "LiquidGlassReference" to true'
			sleep 3
			variant_title=$(title_case "$variant")
			background_title=$(title_case "$background")
			"$VALIDATION/tools/capture-window.sh" "$SWIFT_OWNER - $variant_title - $background_title" "$output/swiftui.png"
			stop_reference
		fi

		"$VALIDATION/tools/gd.sh" \
			--object=panel \
			--view=side \
			"--variant=$variant" \
			"--background=$background" \
			--state=rest \
			"--shot=$output/godot.png"
		"$VALIDATION/tools/compare.py" "$output/swiftui.png" "$output/godot.png" "$output"
	done
done
