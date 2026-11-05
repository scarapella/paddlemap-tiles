#!/bin/bash
set -ex



cd "$(dirname "$0")"
git pull

TILES_OBJECT="${TILES_BUCKET_PATH%/}/$SCHEMA.pmtiles"
if [ "$SKIP_IF_NEWER" = true ]; then
  PBF_UPDATE_TIME=$(gcloud storage objects describe "$PBF_NAME" --format='value(updated)')
  if TILES_UPDATE_TIME=$(gcloud storage objects describe "$TILES_OBJECT" --format='value(updated)' 2>/dev/null); then
    PBF_UPDATE_EPOCH=$(date -d "$PBF_UPDATE_TIME" +%s%N)
    TILES_UPDATE_EPOCH=$(date -d "$TILES_UPDATE_TIME" +%s%N)
    if [[ "$PBF_UPDATE_EPOCH" -le "$TILES_UPDATE_EPOCH" ]]; then
      echo "Skipping generation: $TILES_OBJECT is up to date with $PBF_NAME"
      exit 0
    fi
  fi
fi

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
    
echo "Uploading data/$SCHEMA.pmtiles to $TILES_OBJECT"
gcloud storage cp data/$SCHEMA.pmtiles "$TILES_OBJECT"
