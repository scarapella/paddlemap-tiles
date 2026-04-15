#!/bin/bash
cd "$(dirname "$0")"




usage() {
  echo "Usage: $0" >&2
  echo "  --java-args=JAVA_ARGS" >&2
  echo "  --pbf-bucket-path=PBF_BUCKET_PATH" >&2 
  echo "  --pbf-region=PBF_REGION" >&2
  echo "  --schema=SCHEMA" >&2
  echo "  --tiles-bucket-path=TILES_BUCKET_PATH" >&2
  echo "  --execution-mode=java|docker" >&2
  echo "  --container-engine=podman|docker" >&2
  echo "Example: $0" >&2
  echo "  --java-args='-Dhi=mom -Xmx60g'" >&2
  echo "  --pbf-bucket-path=gs://na-ne2-openpaddlemap-rawdata" >&2
  echo "  --pbf-region=north-america" >&2
  echo "  --schema=waterways" >&2
  echo "  --tiles-bucket-path=gs://na-ne2-openpaddlemap-tiles" >&2
  echo "  --execution-mode=java" >&2
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
      PBF_REGION="${1#*=}"
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
set -x 


export JAVA_ARGS=${JAVA_ARGS:-}

export PBF_BUCKET_PATH=${PBF_BUCKET_PATH:-gs://na-ne2-openpaddlemap-rawdata/pbf}
export SCHEMA=${SCHEMA:-waterways}

export PBF_REGION=${PBF_REGION:-rhode-island}
export TILES_BUCKET_PATH=${TILES_BUCKET_PATH:-gs://na-ne2-openpaddlemap-tiles/tiles-test}

export PBF_FILE=$PBF_REGION-latest.osm.pbf
export PBF_NAME=$PBF_BUCKET_PATH/$PBF_FILE


export CONTAINER_ENGINE=${CONTAINER_ENGINE:-podman}
export EXECUTION_MODE=${EXECUTION_MODE:-java}


./generate_tiles_internals.sh $@
EXIT_STATUS=$?

#cleanup
if [ -f *.out ]
then
  gcloud storage cp *.out $TILES_BUCKET_PATH/logs/
fi
rm  data/sources/$PBF_FILE
rm  data/$SCHEMA.pmtiles
rm  -rf data/tmp

exit $EXIT_STATUS
