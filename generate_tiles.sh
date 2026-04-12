#!/bin/sh
set -x
cd "$(dirname "$0")"

# todo: MAKE THIS SUCK LESS
# 1 - bucket + path to find pbf gs://na-ne2-brouter-segments/pbf
# 2 - pbf name
# 3 - schema to generate (without .yml extension)
# 4 - destination bucket for pmtiles gs://na-ne2-openpaddlemap-tiles
# we wrap this script so that it fails immmedatly on error, then we do the cleanup here. 
./generate_tiles_internals.sh $@

#cleanup
gcloud storage cp *.out $4logs/
rm  data/sources/$2
rm  data/$3.pmtiles
rm  -rf data/tmp

