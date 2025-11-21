#!/bin/bash

find /app/priv/static/uploads/images -type f ! -name "*.small.jpg" ! -name "*.webp" \
    -exec bash -c 'convert "$0" -strip -resize 1400x1400 -format webp "${0%.*}.web_lg.webp" && convert "$0" -strip -resize 600x600 -format webp "${0%.*}.web_md.webp" && convert "$0" -strip -thumbnail 300x300^ -gravity center -extent 300x300 -format webp "${0%.*}.thumb.webp"' {} \;

find /app/priv/static/uploads/images -type f -name "*.small.jpg" -exec rm -f {} \;
