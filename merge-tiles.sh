#!/bin/bash
cd "$(dirname "$0")"

set -e


usage() {
  echo "Usage: $0" >&2
  echo "  --tiles-source-bucket-path=TILES_SOURCE_BUCKET_PATH" >&2 
  echo "  --pmtiles-file=PMTILES_FILE" >&2
  echo "  --tiles-bucket-path=TILES_BUCKET_PATH" >&2
  echo "  [--pbf-region=PBF_REGION,PBF_REGION...] #if empty will default to all findable regions" >&2
  echo "  [--working-dir=WORKING_DIR]" >&2
  echo "Example: $0" >&2
  echo "  --tiles-source-bucket-path=gs://na-ne2-paddlemap-rawdata" >&2
  echo "  --pmtiles-file=waterways.pmtiles" >&2
  echo "  --tiles-bucket-path=gs://na-ne2-paddlemap-tiles" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pmtiles-file=*)
      PMTILES_FILE="${1#*=}"
      shift
      ;;
    --tiles-source-bucket-path=*)
      TILES_SOURCE_BUCKET_PATH="${1#*=}"
      shift
      ;;
    --tiles-bucket-path=*)
      TILES_BUCKET_PATH="${1#*=}"
      shift
      ;;
    --pbf-region=*)
      PBF_REGIONS="${1#*=}"
      shift
      ;;
    --working-dir=*)
      WORKING_DIR="${1#*=}"
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
WORKING_DIR=${WORKING_DIR:-tmp-tiles}
TILES_BUCKET_PATH=${TILES_BUCKET_PATH:-}
PMTILES_FILE=${PMTILES_FILE:-waterways.pmtiles}
TILES_SOURCE_BUCKET_PATH=${TILES_SOURCE_BUCKET_PATH:-}

if [ -z "$TILES_SOURCE_BUCKET_PATH" ] || [ -z "$PMTILES_FILE" ] || [ -z "$TILES_BUCKET_PATH" ]; then
  echo "Error: --tiles-source-bucket-path, --pmtiles-file, and --tiles-bucket-path are required" >&2
  usage
fi

rm -rf $WORKING_DIR
mkdir -p $WORKING_DIR

IFS=',' read -ra PBF_REGION_LIST <<< "$PBF_REGIONS"

if [ ${#PBF_REGION_LIST[@]} -gt 0 ]; then
  for PBF_REGION in "${PBF_REGION_LIST[@]}"; do
    echo "retrieving $TILES_SOURCE_BUCKET_PATH/$PBF_REGION/$PMTILES_FILE"
    mkdir -p $WORKING_DIR/$PBF_REGION
    gcloud storage cp $TILES_SOURCE_BUCKET_PATH/$PBF_REGION/$PMTILES_FILE $WORKING_DIR/$PBF_REGION/
  done
else
    echo "retrieving all instances of $PMTILES_FILE from sub-directories of $TILES_SOURCE_BUCKET_PATH/"
    gcloud storage ls -r  $TILES_SOURCE_BUCKET_PATH/** 
    #TODO: filter on filename.  unfortunatle if you just do -r blah/**/file.txt tmp-dir  it will try to write all the file.txt to the same file (will not copy structure)
    gcloud storage cp -r $TILES_SOURCE_BUCKET_PATH/ $WORKING_DIR/
fi


echo generating merged pmtiles file with tile-join
find $WORKING_DIR -type f -name "$PMTILES_FILE" -exec tile-join -o $WORKING_DIR/$PMTILES_FILE {} +

echo uploading merged pmtiles file to $TILES_BUCKET_PATH/$PMTILES_FILE
gcloud storage cp $WORKING_DIR/$PMTILES_FILE $TILES_BUCKET_PATH/$PMTILES_FILE

rm -rf $WORKING_DIR

