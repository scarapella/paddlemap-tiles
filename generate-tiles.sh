#!/bin/bash
cd "$(dirname "$0")"




usage() {
  echo "Usage: $0" >&2
  echo "  --pbf-bucket-path=PBF_BUCKET_PATH" >&2 
  echo "  --pbf-region=PBF_REGIONS[,PBF_REGIONS2...]" >&2
  echo "  --schema=SCHEMA" >&2
  echo "  --tiles-bucket-path=TILES_BUCKET_PATH" >&2
  echo "  [--execution-mode=java|docker]" >&2
  echo "  [--container-engine=podman|docker]" >&2
  echo "  [--java-args=JAVA_ARGS]" >&2
  echo "Example: $0" >&2
  echo "  --pbf-bucket-path=gs://na-ne2-openpaddlemap-rawdata" >&2
  echo "  --pbf-region=north-america" >&2
  echo "  --schema=waterways" >&2
  echo "  --tiles-bucket-path=gs://na-ne2-paddlemap-tiles" >&2
  echo "  --execution-mode=java" >&2
  echo "  --java-args='-Dhi=mom -Xmx60g'" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --java-args=*)
      JAVA_ARGS="${1#*=}"
      shift
      ;;
    --pbf-bucket-path=*)
      PBF_BUCKET_PATH="${1#*=}"
      shift
      ;;
    --pbf-region=*)
      PBF_REGIONS="${1#*=}"
      shift
      ;;
    --schema=*)
      SCHEMA="${1#*=}"
      shift
      ;;
    --tiles-bucket-path=*)
      TILES_BUCKET_PATH="${1#*=}"
      shift
      ;;
    --execution-mode=*)
      EXECUTION_MODE="${1#*=}"
      shift
      ;;
    --container-engine=*)
      CONTAINER_ENGINE="${1#*=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      echo "Invalid argument: $1" >&2
      usage
      exit 1
      ;;
    *)
      echo "Invalid argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

#setup common exports for generate_tiles_internals
BASE_TILES_BUCKET_PATH=${TILES_BUCKET_PATH:-gs://na-ne2-paddlemap-tiles/tiles-test}
export JAVA_ARGS=${JAVA_ARGS:-}

export PBF_BUCKET_PATH=${PBF_BUCKET_PATH:-gs://na-ne2-openpaddlemap-rawdata/pbf}
export SCHEMA=${SCHEMA:-waterways}

export CONTAINER_ENGINE=${CONTAINER_ENGINE:-podman}
export EXECUTION_MODE=${EXECUTION_MODE:-java}

if [ -z "$PBF_REGIONS" ] || [ -z "$SCHEMA" ] || [ -z "$BASE_TILES_BUCKET_PATH" ] || [ -z "$PBF_BUCKET_PATH" ]; then
  echo "Error: --pbf-region, --schema, --tiles-bucket-path, and --pbf-bucket-path are required" >&2
  usage
fi
set -x 

IFS=',' read -ra PBF_REGION_LIST <<< "$PBF_REGIONS"

for PBF_REGION in "${PBF_REGION_LIST[@]}"; do

  # If there are multiple regions, we will create a subdirectory for each region in the tiles bucket path
  if [ ${#PBF_REGION_LIST[@]} -gt 1 ]; then
    export TILES_BUCKET_PATH=${BASE_TILES_BUCKET_PATH}/${PBF_REGION}
  else
    export TILES_BUCKET_PATH=${BASE_TILES_BUCKET_PATH}
  fi

  export PBF_FILE=$PBF_REGION-latest.osm.pbf
  export PBF_NAME=$PBF_BUCKET_PATH/$PBF_FILE

  echo "Processing region: $PBF_REGION with schema: $SCHEMA"
  ./generate-tiles-internals.sh $@
  EXIT_STATUS=$?

  #cleanup
  if [ -f *.out ]
  then
    gcloud storage cp *.out $TILES_BUCKET_PATH/logs/
  fi
  if [ $EXIT_STATUS -ne 0 ]
  then
    echo "Error: generate_tiles_internals.sh failed for region $PBF_REGION with schema $SCHEMA" >&2
    exit $EXIT_STATUS
  fi
  rm  data/sources/$PBF_FILE
  rm  data/$SCHEMA.pmtiles
  rm  -rf data/tmp
done

