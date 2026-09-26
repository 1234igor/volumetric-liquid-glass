#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
VALIDATION="$ROOT/validation"
RAW="$VALIDATION/captures/raw/volume"
FRAMES=${VOLUME_FRAMES:-6}
VARIANTS=${VOLUME_VARIANTS:-"regular clear regular-tinted clear-tinted identity"}

capture_materials() {
	object=$1
	view=$2
	background=$3
	for variant in $VARIANTS; do
		output="$RAW/materials/$object/$variant.png"
		mkdir -p "$(dirname "$output")"
		"$VALIDATION/tools/gd.sh" \
			"--object=$object" \
			"--view=$view" \
			"--variant=$variant" \
			"--background=$background" \
			--state=rest \
			"--frames=$FRAMES" \
			"--shot=$output"
	done
}

capture_view() {
	view=$1
	output="$RAW/views/panel/$view.png"
	mkdir -p "$(dirname "$output")"
	"$VALIDATION/tools/gd.sh" \
		--object=panel \
		"--view=$view" \
		--variant=regular \
		--background=harbour \
		--state=rest \
		"--frames=$FRAMES" \
		"--shot=$output"
}

capture_materials panel three-quarter facade
capture_materials orb three-quarter city-night
capture_materials torus top prism
capture_materials cluster three-quarter harbour

for view in side three-quarter grazing top; do
	capture_view "$view"
done
