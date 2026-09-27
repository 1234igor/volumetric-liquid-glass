# Validation

The volume shapes and the flat panel have separate checks. Only the flat panel has a native SwiftUI reference.

## Volume shapes

The matrix covers four objects and five materials. Active materials must change at least 5% of the frame's pixels. Identity may change at most 1%; the stored run changes none. A separate check confirms that the four camera presets produce different images.

See [materials](captures/volume-material-matrix.png), [views](captures/view-projections.png), and [metrics](captures/volume-metrics.json). The metrics record the changed-pixel fraction for each shape and material.

## Flat panel

Panel with the Side camera is compared with SwiftUI on four backgrounds at 2400 × 1600. In the stored macOS 27 run, Regular fails the 95-point glass-crop threshold on three backgrounds:

| Background | Score |
| --- | ---: |
| Harbour | 94.93 |
| Dark city | 93.80 |
| Prism | 94.81 |

The score is `100 × (1 − mean absolute RGB error / 255)`. It measures mean channel error on a 0–100 scale.

See the [side comparison](captures/side-projection-matrix.png) and [metrics](captures/side-projection-metrics.json).

## Run checks

Requires Godot 4.7, Python 3, and Pillow 10.1 or later. Run from the repository root:

```sh
validation/tools/check.sh
validation/tools/full-visual.sh
```

The first checks scripts, shaders, assets, and addon behavior without a window. The second builds SwiftUI and captures the full comparison. Native captures require macOS 26 or later, a matching Xcode, and Screen Recording permission. Set `DEVELOPER_DIR` to choose Xcode.

The full run stops at the known flat-panel failure. To capture the volumes separately:

```sh
validation/tools/capture-volume-matrix.sh
python3 validation/tools/compose-volume-evidence.py
```

## README image

With Pillow 10.1 or later installed:

```sh
python3 validation/tools/compose-showcase.py
```

Run `capture-volume-matrix.sh` first if `captures/raw/volume/` is missing. The showcase uses Clear Panel, Clear Orb, Regular Tinted Torus, and Regular Cluster. It resizes each complete frame and adds labels; it does not alter the glass. Raw captures are generated files and are not checked in.
