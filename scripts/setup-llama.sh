#!/usr/bin/env bash
# Builds Vendor/llama.xcframework, which the app links.
#
# llama.cpp publishes iOS device and macOS builds but no iOS Simulator build. This script
# takes the official device and macOS slices (checked against a pinned SHA-256), builds a
# simulator slice from the same release tag, and combines them. Needs Xcode and CMake
# (brew install cmake). Takes several minutes.
set -euo pipefail

TAG=b11988
ZIP_SHA256=733ae95d8fe9fe45eecdf335a8a634424e280c36aa626c0c2fda7488f049c845

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Vendor/llama.xcframework"

if [[ -d "$OUT" ]]; then
  echo "Vendor/llama.xcframework already exists. Delete it to rebuild."
  exit 0
fi
command -v cmake >/dev/null || { echo "CMake is required: brew install cmake" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Fetching the official llama.cpp $TAG build..."
curl -fL --progress-bar -o "$WORK/official.zip" \
  "https://github.com/ggml-org/llama.cpp/releases/download/$TAG/llama-$TAG-xcframework.zip"
echo "$ZIP_SHA256  $WORK/official.zip" | shasum -a 256 -c -
mkdir "$WORK/official"
unzip -q "$WORK/official.zip" -d "$WORK/official"
OFFICIAL="$(find "$WORK/official" -name llama.xcframework -maxdepth 3 | head -1)"

echo "Building the simulator slice from source..."
git clone --quiet --depth 1 --branch "$TAG" https://github.com/ggml-org/llama.cpp "$WORK/src"
(cd "$WORK/src" && ./build-xcframework.sh ios-sim)
SIM="$(find "$WORK/src/build-apple" -name llama.xcframework -maxdepth 2 | head -1)"

echo "Combining..."
mkdir -p "$ROOT/Vendor"
xcodebuild -create-xcframework \
  -framework "$OFFICIAL/ios-arm64/llama.framework" \
  -framework "$OFFICIAL/macos-arm64_x86_64/llama.framework" \
  -framework "$SIM/ios-arm64_x86_64-simulator/llama.framework" \
  -output "$OUT"
echo "Done: $OUT"
