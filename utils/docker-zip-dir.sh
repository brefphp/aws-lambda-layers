#!/usr/bin/env bash

# Fail on error
set -e

rm -f "output/$2.zip"
rm -rf "output/$2"
mkdir "output/$2"

# Remove any previously failed container if it exists
docker rm -f bref-export-zip 2>/dev/null || true

docker create --name bref-export-zip "$1"

docker cp bref-export-zip:/opt/. "output/$2"

cd "output/$2"

zip --quiet --recurse-paths "../$2.zip" .

docker rm -f bref-export-zip
