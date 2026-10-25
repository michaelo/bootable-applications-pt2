#!/bin/bash
set -e
set -u

function log() { 
    echo "BUILD: $*"
}

FLASHFILE=puredoom_zig.img
log Checking for mformat and mmd, if found: create $FLASHFILE

if mformat --version > /dev/null && mmd --version > /dev/null ; then
    log mformat and mmd found, creating $FLASHFILE
    dd if=/dev/zero of=$FLASHFILE bs=1k count=16384
    mformat -i $FLASHFILE -h 64 -t 16 -n 32  ::
    mmd -i $FLASHFILE ::/EFI
    mmd -i $FLASHFILE ::/EFI/BOOT
    mcopy -i $FLASHFILE zig-out/bin/puredoom_zig.efi ::/EFI/BOOT/BOOTX64.EFI
else
    log mformat and/or mmd not found
fi;