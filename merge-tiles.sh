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
  echo "  [--skip-if-newer]" >&2
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
    --skip-if-newer)
      SKIP_IF_NEWER=true
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

IFS=',' read -ra PBF_REGION_LIST <<< "$PBF_REGIONS"

if [ "$SKIP_IF_NEWER" = true ]; then
  TILES_OBJECT="${TILES_BUCKET_PATH%/}/$PMTILES_FILE"
  SOURCE_ROOT="${TILES_SOURCE_BUCKET_PATH%/}"
  SOURCE_OBJECTS=()

  if [ ${#PBF_REGION_LIST[@]} -gt 0 ]; then
    for PBF_REGION in "${PBF_REGION_LIST[@]}"; do
      SOURCE_OBJECTS+=("$SOURCE_ROOT/$PBF_REGION/$PMTILES_FILE")
    done
  else
    SOURCE_LIST=$(gcloud storage ls -r "$SOURCE_ROOT/**")
    while IFS= read -r SOURCE_OBJECT; do
      if [[ "${SOURCE_OBJECT##*/}" == "$PMTILES_FILE" ]]; then
        SOURCE_OBJECTS+=("$SOURCE_OBJECT")
      fi
    done <<< "$SOURCE_LIST"
  fi

  if [ ${#SOURCE_OBJECTS[@]} -eq 0 ]; then
    echo "Error: No source objects found for $PMTILES_FILE under $SOURCE_ROOT" >&2
    exit 1
  fi

  TILES_UPDATE_TIME=$(gcloud storage objects describe "$TILES_OBJECT" --format='value(update_time)' 2>/dev/null || true)
  if [ -n "$TILES_UPDATE_TIME" ]; then
    TILES_UPDATE_EPOCH=$(date -d "$TILES_UPDATE_TIME" +%s%N)
    ALL_SOURCES_CURRENT=true
    for SOURCE_OBJECT in "${SOURCE_OBJECTS[@]}"; do
      SOURCE_UPDATE_TIME=$(gcloud storage objects describe "$SOURCE_OBJECT" --format='value(update_time)')
      SOURCE_UPDATE_EPOCH=$(date -d "$SOURCE_UPDATE_TIME" +%s%N)
      if [[ "$SOURCE_UPDATE_EPOCH" -gt "$TILES_UPDATE_EPOCH" ]]; then
        ALL_SOURCES_CURRENT=false
        break
      fi
    done

    if [ "$ALL_SOURCES_CURRENT" = true ]; then
      echo "Skipping merge: $TILES_OBJECT is up to date with all source objects"
      exit 0
    fi
  fi
fi

rm -rf "$WORKING_DIR"
mkdir -p "$WORKING_DIR"

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

