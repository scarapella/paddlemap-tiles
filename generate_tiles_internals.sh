#!/bin/sh
set -ex



cd "$(dirname "$0")"
git pull

gcloud storage cp $PBF_NAME data/sources

CONTAINER_ENGINE=${CONTAINER_ENGINE:-"podman"}

JAVA_CONTAINER_OPTS=

PLANETILER_ARGS= generate-custom \
--osm-path=data/sources/$(basename $PBF_NAME) \
--schema=/data/layers/$SCHEMA.yml \
--output=/data/$SCHEMA.pmtiles \
--storage=RAM --force 


if [ "$EXECUTION_MODE" == "docker" ]; then
  if [ -n "$JAVA_ARGS" ]; then
    JAVA_CONTAINER_OPTS="-e JAVA_TOOL_OPTIONS='$JAVA_ARGS'"
  fi
  $CONTAINER_ENGINE run $JAVA_CONTAINER_OPTS \
  -v "$(pwd)/data":/data \
  ghcr.io/onthegomap/planetiler generate-custom $PLANETILER_ARGS 
elif [ "$EXECUTION_MODE" == "java" ]; then
  java planentiler.jar $JAVA_ARGS $PLANETILER_ARGS
else
  echo "Unknown execution mode: EXECUTION_MODE=$EXECUTION_MODE" >&2
  exit 1
fi
    
gcloud storage cp data/$SCHEMA.pmtiles $TILES_BUCKET_PATH/
