#!/bin/bash
set -e
set -u

function log() { 
    echo "BUILD: $*"
}

FOLDER="demos/out/${1}"

FLASHFILE=demos/out/${1}.img
log Checking for mformat and mmd, if found: create $FLASHFILE

if mformat --version > /dev/null && mmd --version > /dev/null ; then
    log mformat and mmd found, creating $FLASHFILE
    # Currently creating a 64MB image. Usually way overkill for most examples, but goes for "one size fits all" right now
    dd if=/dev/zero of=$FLASHFILE bs=1k count=65536
    mformat -i $FLASHFILE -h 64 -t 64 -n 32  ::
    mmd -i $FLASHFILE ::/EFI
    mmd -i $FLASHFILE ::/EFI/BOOT
    mcopy -i $FLASHFILE -s "$FOLDER/"* ::/
else
    log mformat and/or mmd not found
fi;