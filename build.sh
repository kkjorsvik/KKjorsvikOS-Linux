#!/usr/bin/env bash
# Build the KKjorsvik OS ISO. Requires sudo (mkarchiso sets up loop devices).
set -euo pipefail
cd "$(dirname "$0")"
echo ">> Building KKjorsvik OS ISO with mkarchiso (you will be prompted for sudo)..."
sudo mkarchiso -v -w work -o out profile
echo ">> Done. ISO(s) in ./out:"
ls -lh out/*.iso
