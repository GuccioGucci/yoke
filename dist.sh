#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

DIST_DIR="${DIST_DIR:-$CURRENT_DIR/dist}"
LIB_DIR="${LIB_DIR:-$CURRENT_DIR/lib}"

BIN_DIR="$CURRENT_DIR/bin"

$BIN_DIR/install --dist

echo "Preparing $DIST_DIR folder"
rm -rf $DIST_DIR > /dev/null 2>&1 ; mkdir -p $DIST_DIR/yoke
cp -r yoke LICENSE bin $DIST_DIR/yoke

echo "Packaging distribution archive"
( cd $DIST_DIR ; tar -czf yoke.tar.gz yoke )

echo "Packaging distribution binary"
$LIB_DIR/bin/makeself.sh \
    --quiet --nox11 --noprogress --nowait --notemp --current \
    $DIST_DIR $DIST_DIR/yoke.bin "yoke" ./yoke/yoke

echo "Done"