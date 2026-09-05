#!/bin/bash
set -e
set -u

function log() {
    echo "BUILD: $*"
}

IMGPATH="demos/out/$1.img"
DEVICE=$2

if [ ! -f "$IMGPATH" ]; then
    log File \"$IMGPATH\" not found
    exit 1
fi

diskutil unmountDisk $DEVICE || true
sudo dd if=$IMGPATH of=$DEVICE bs=1m 
diskutil eject $DEVICE

log Finished.