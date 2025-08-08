#!/bin/bash

find /app/priv/static/uploads/images -type f ! -name "*.small.jpg" \
  -exec bash -c 'magic "$0" -strip -resize 1400x1400 -format jpg "${0%.*}.web.jpg"' {} \;
