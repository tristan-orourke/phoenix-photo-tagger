#!/bin/bash

# Smarter conversion: skip if target already exists; show a progress bar.
# Collect relevant files
mapfile -t files < <(find /app/priv/static/uploads/images -type f ! -name "*.small.jpg" ! -name "*.webp")
total=${#files[@]}
count=0

progress_bar() {
  local progress=$1
  local total=$2
  local width=40  # width of the bar
  local percent=$(( progress * 100 / total ))
  local filled=$(( width * progress / total ))
  local empty=$(( width - filled ))
  # Output to stderr which is unbuffered, allowing real-time progress updates
  printf "\r[" >&2
  for ((i=0;i<filled;i++)); do printf "=" >&2; done
  for ((i=0;i<empty;i++)); do printf " " >&2; done
  printf "] %d%% (%d/%d)" "$percent" "$progress" "$total" >&2
}

for src in "${files[@]}"; do
  base="${src%.*}"
  out_lg="${base}.web_lg.webp"
  out_md="${base}.web_md.webp"
  out_thumb="${base}.thumb.webp"

  any_missing=false

  if [ ! -f "$out_lg" ]; then
    convert "$src" -strip -resize 1400x1400 -format webp "$out_lg" || { echo "Error: convert failed for $src (web_lg)" >&2; exit 1; }
    any_missing=true
  fi
  if [ ! -f "$out_md" ]; then
    convert "$src" -strip -resize 600x600 -format webp "$out_md" || { echo "Error: convert failed for $src (web_md)" >&2; exit 1; }
    any_missing=true
  fi
  if [ ! -f "$out_thumb" ]; then
    convert "$src" -strip -thumbnail 300x300^ -gravity center -extent 300x300 -format webp "$out_thumb" || { echo "Error: convert failed for $src (thumb)" >&2; exit 1; }
    any_missing=true
  fi
  ((count++))
  progress_bar $count $total
done

echo >&2

find /app/priv/static/uploads/images -type f -name "*.small.jpg" -exec rm -f {} \;
