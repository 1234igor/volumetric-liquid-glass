# Validation

This directory keeps the pixel-matching work separate from normal addon use. It
holds a small SwiftUI application that calls Apple's public `.glassEffect`, the
canonical Godot side scene, the capture tooling, and the checked-in evidence.

Two different things are gated here, because only one of them has something to
be compared against.

## 1. The flat projection, against SwiftUI

Panel + Side is the projection with a native counterpart, so it is measured the
same way as the flat addon: five materials × four backgrounds = 20 pairs at
2400 × 1600, compared in sRGB over the whole window, the glass crop and the
control bounds. Measured on macOS 27 with Godot 4.7.1:

| Metric | Range |
|--------|-------|
| Glass crop — Regular, Clear, both tinted | 93.80 – 97.73 % |
| Glass crop — Identity | 98.81 – 99.52 % |
| Whole window | 99.42 – 99.94 % |

Evidence: [`captures/side-projection-matrix.png`](captures/side-projection-matrix.png),
`captures/side-projection-metrics.json`.

### Known failure

`tools/full-visual.sh` **reports a failure on Regular out of the box**:

```
harbour/regular     glass 94.93% < 95.00%
city-night/regular  glass 93.80% < 95.00%
prism/regular       glass 94.81% < 95.00%
```

The optics were calibrated against macOS 26. macOS 27 moved the Regular
material slightly; the other four are unaffected and still clear the gate. The
gate has deliberately **not** been lowered to make the run green — a gate that
moves whenever it fails measures nothing. Re-tuning Regular against the current
system is the open work.

Because the run stops there, regenerating the volumetric evidence below needs
its two steps invoked directly:

```sh
validation/tools/capture-volume-matrix.sh
validation/tools/compose-volume-evidence.py
```

## 2. The volumes, against themselves

A ray-marched orb has no native counterpart, so it is gated on **coverage**
instead of similarity: each material must change a measurable share of the
pixels inside the object, and Identity must change none at all.

| Metric | Measured | Gate |
|--------|----------|------|
| Active materials, changed pixels | 8.29 – 22.43 % | ≥ 5 % |
| Identity, changed pixels | 0.00 % | ≤ 1 % |

Four objects — panel, orb, torus, cluster — × five materials, plus the four
camera presets as a separate pair-wise check that each view actually differs.

Evidence: [`captures/volume-material-matrix.png`](captures/volume-material-matrix.png),
[`captures/view-projections.png`](captures/view-projections.png),
`captures/volume-metrics.json`.

## Running it

Fast — instantiates the production `VolumetricGlassLayer` and checks the
canonical panel-side dispatch, configurable content bounds, Identity capture and
input shutdown, and the active/idle processing lifecycle. No GUI:

```sh
validation/tools/check.sh
```

This deliberately exercises the same addon path the integration docs describe,
so the two cannot drift.

Full — builds the SwiftUI reference, then captures and compares everything:

```sh
validation/tools/full-visual.sh
```

That needs macOS 26 or newer and a matching Xcode, plus permission for
`screencapture` to record the screen. `tools/gd.sh` launches the dedicated
reference scene explicitly, so the root project keeps opening the spatial
gallery. Every capture is serialized and self-closing.

The reference build uses whatever `xcode-select -p` points at; override it with
`DEVELOPER_DIR=...` if you keep several Xcodes.

## Layout

| Path | What it is |
|------|-----------|
| `reference-swiftui/` | The SwiftUI application the side projection is compared against |
| `godot/` | The canonical Godot reference scene |
| `tools/` | Capture, comparison and evidence-composition scripts |
| `captures/` | Checked-in evidence; `captures/raw/` is generated and ignored |
