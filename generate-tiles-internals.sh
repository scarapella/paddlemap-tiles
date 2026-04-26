#!/bin/bash
set -ex



cd "$(dirname "$0")"
git pull

gcloud storage cp $PBF_NAME data/sources

CONTAINER_ENGINE=${CONTAINER_ENGINE:-"podman"}

PLANETILER_ARGS="generate-custom \
--osm-path=data/sources/$PBF_FILE \
--schema=data/layers/$SCHEMA.yml \
--output=data/$SCHEMA.pmtiles \
--storage=RAM --force" 


JAVA_CONTAINER_OPTS=

if [ "$EXECUTION_MODE" == "docker" ]; then
  if [ -n "$JAVA_ARGS" ]; then
    JAVA_CONTAINER_OPTS="-e JAVA_TOOL_OPTIONS='$JAVA_ARGS'"
  fi
  $CONTAINER_ENGINE run $JAVA_CONTAINER_OPTS \
  -v "$(pwd)/data":/data \
  ghcr.io/onthegomap/planetiler generate-custom $PLANETILER_ARGS 
elif [ "$EXECUTION_MODE" == "java" ]; then
   java $JAVA_ARGS -jar planetiler.jar $PLANETILER_ARGS
else
  "Unknown execution mode: EXECUTION_MODE=$EXECUTION_MODE" >&2
  exit 1
fi
    
echo "Uploading data/$SCHEMA.pmtiles  to $TILES_BUCKET_PATH"
gcloud storage cp data/$SCHEMA.pmtiles $TILES_BUCKET_PATH/
