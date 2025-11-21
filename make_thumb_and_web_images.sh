#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <docker_container_name>"
  exit 1
fi

CONTAINER_NAME="$1"

if ! docker image inspect imagemagick-processor:latest > /dev/null 2>&1; then
  docker build -f Dockerfile.imagemagick -t imagemagick-processor .
fi

docker run --rm --volumes-from "$CONTAINER_NAME" \
  imagemagick-processor \
  bash -c "find /app/priv/static/uploads/images -type f ! -name \"*.small.jpg\" ! -name \"*.webp\" \
    -exec bash -c 'convert \"\$0\" -strip -resize 1400x1400 -format webp \"\${0%.*}.web_lg.webp\" && convert \"\$0\" -strip -resize 600x600 -format webp \"\${0%.*}.web_md.webp\" && convert \"\$0\" -strip -thumbnail 300x300^ -gravity center -extent 300x300 -format webp \"\${0%.*}.thumb.webp\"' {} \;"
