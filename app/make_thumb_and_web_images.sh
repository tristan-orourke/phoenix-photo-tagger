#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <docker_container_name>"
  exit 1
fi

CONTAINER_NAME="$1"

docker build -f app/

docker run --rm --volumes-from "$CONTAINER_NAME" \
  imagemagick-processor:latest \
  bash -c "find /app/priv/static/uploads/images -type f ! -name \"*.small.jpg\" \
    -exec bash -c 'magick \"\$0\" -strip -resize 1400x1400 -format webp \"\${0%.*}.web_lg.webp\" && magick \"\$0\" -strip -resize 600x600 -format webp \"\${0%.*}.web_md.webp\" && magick \"\$0\" -strip -thumbnail 300x300^ -gravity center -extent 300x300 -format webp \"\${0%.*}.thumb.webp\"' {} \;"
