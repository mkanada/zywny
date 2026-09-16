#!/usr/bin/env bash
# Copies the Verovio music-font resources (Bravura etc.) from the
# third_party/verovio_lottie submodule into assets/verovio_data/, where
# Flutter picks them up as bundled assets.
#
# The copy is gitignored and regenerable — re-run after updating the submodule.
set -euo pipefail

proj_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="$proj_dir/third_party/verovio_lottie/verovio/data"
dst="$proj_dir/assets/verovio_data"

[[ -d "$src" ]] || { echo "ERROR: submodule data dir missing: $src" >&2; exit 1; }

rm -rf "$dst"
mkdir -p "$dst"
cp -r "$src"/. "$dst"/
echo "Copied $src -> $dst ($(du -sh "$dst" | cut -f1))"
