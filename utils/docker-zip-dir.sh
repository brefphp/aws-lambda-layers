#!/usr/bin/env bash

# Fail on error
set -e

IMAGE_NAME="$1"
LAYER_NAME="$2"

rm -f "output/$LAYER_NAME.zip"
rm -rf "output/$LAYER_NAME"
mkdir "output/$LAYER_NAME"

# Remove any previously failed container if it exists
docker rm -f bref-export-zip 2>/dev/null || true

docker create --name bref-export-zip "$IMAGE_NAME"

docker cp bref-export-zip:/opt/. "output/$LAYER_NAME"

cd "output/$LAYER_NAME"

zip --quiet --recurse-paths "../$LAYER_NAME.zip" .

docker rm -f bref-export-zip
