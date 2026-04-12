#!/bin/bash
set -x
cd "$(dirname "$0")"

# todo: MAKE THIS SUCK LESS
# 1 - bucket + path to find pbf gs://na-ne2-brouter-segments/pbf
# 2 - pbf name
# 3 - schema to generate (without .yml extension)
# 4 - destination bucket for pmtiles gs://na-ne2-openpaddlemap-tiles
# we wrap this script so that it fails immmedatly on error, then we do the cleanup here. 
./generate_tiles.sh $@

#cleanup
gcloud compute instances stop $HOSTNAME --zone=northamerica-northeast2-b 
