#!/bin/bash
set -e
set -u

ENTRY_FILE=$1

# Create fresh NVRAM to avoid PlatformConfig override from OVMFx64.fd built-in NVRAM
rm -f "demos/out/${ENTRY_FILE}/Vars.fd" 2>/dev/null || true
mkdir -p "demos/out/${ENTRY_FILE}"
truncate -s 65536 "demos/out/${ENTRY_FILE}/Vars.fd"

qemu-system-x86_64 \
    -machine q35 \
    -display cocoa \
    -device VGA,edid=on,xres=1400,yres=1050 \
    -serial stdio \
    -drive if=pflash,format=raw,readonly=on,file=resources/bios/OVMFx64.fd \
    -drive if=pflash,format=raw,file=demos/out/${ENTRY_FILE}/Vars.fd \
    -drive format=raw,file=fat:rw:demos/out/${ENTRY_FILE}
