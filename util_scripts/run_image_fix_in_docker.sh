#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <docker_container_name>"
  exit 1
fi

CONTAINER_NAME="$1"

docker build -f Dockerfile.imagemagick -t imagemagick-processor .

docker run --rm --volumes-from "$CONTAINER_NAME" \
  imagemagick-processor \
  bash -c "/bin/make_thumb_and_web_images.sh"