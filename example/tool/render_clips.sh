#!/usr/bin/env bash
# Renders clips/ into the repo's doc/screenshots/ and doc/clips/, Material and Cupertino side by side.
# macOS only, since the Cupertino look needs the system's SF Pro. Needs ffmpeg and img2webp.
set -euo pipefail

example="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
docs="$(dirname "$example")/doc"
frame_millis=33
frames="$(mktemp -d)"
trap 'rm -rf "$frames"' EXIT

(cd "$example" && CLIP_FRAMES="$frames" CLIP_FRAME_MILLIS="$frame_millis" flutter test tool/clips)

for clip in "$frames"/*/*/; do
  folder="$(basename "$(dirname "$clip")")"
  name="$(basename "$clip")"
  mkdir -p "$clip/pair" "$docs/$folder"
  # A white gap between the 2 looks.
  ffmpeg -loglevel error -i "$clip/material/%04d.png" -i "$clip/cupertino/%04d.png" \
    -filter_complex '[0]pad=iw+24:ih:0:0:white[material];[material][1]hstack' "$clip/pair/%04d.png"
  img2webp -loop 0 -lossy -q 75 -d "$frame_millis" "$clip"/pair/*.png -o "$docs/$folder/$name.webp"
done
