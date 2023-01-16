#!/usr/bin/env bash

# Fail on error
set -e

rm -rf "output/$2"
mkdir "output/$2"

docker create --name bref-export-zip "$1"

docker cp bref-export-zip:/opt "output/$2"

zip --quiet --recurse-paths "output/$2.zip" "output/$2"

docker rm -f bref-export-zip
