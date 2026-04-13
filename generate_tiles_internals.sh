#!/bin/sh
set -ex
cd "$(dirname "$0")"
git pull
# todo: MAKE THIS SUCK LESS
# todo: MAKE THIS SUCK LESS
# 1 - bucket + path to find pbf gs://na-ne2-brouter-segments/pbf
# 2 - pbf name
# 3 - schema to generate (without .yml extension)
# 4 - destination bucket for pmtiles gs://na-ne2-openpaddlemap-tiles
gcloud storage cp $1/$2 data/sources

CONTAINER_ENGINE=${CONTAINER_ENGINE:-"podman"}

$CONTAINER_ENGINE run -e JAVA_TOOL_OPTIONS='-Xmx60g' \
-v "$(pwd)/data":/data \
ghcr.io/onthegomap/planetiler generate-custom \
--osm-path=data/sources/$2 \
--schema=/data/layers/$3.yml \
--output=/data/$3.pmtiles \
--storage=RAM --force 
    
gcloud storage cp data/$3.pmtiles $4/
