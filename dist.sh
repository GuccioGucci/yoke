#!/usr/bin/env bash

DIST_DIR="dist"

./bin/install --dist

echo "Preparing $DIST_DIR folder"
rm -rf $DIST_DIR > /dev/null 2>&1 ; mkdir -p $DIST_DIR/yoke
cp -r yoke LICENSE bin $DIST_DIR/yoke

echo "Packaging distribution"
./lib/bin/makeself.sh \
    --nox11 --noprogress --nowait --notemp --current \
    ./dist ./dist/yoke.bin "yoke" ./yoke/yoke --version

echo "Done"