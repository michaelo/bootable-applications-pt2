#!/bin/bash
set -e
set -u

ENTRY_FILE=$1

# rm -f "demos/out/${ENTRY_FILE}/Vars.fd" 2>/dev/null || true
# mkdir -p "demos/out/${ENTRY_FILE}"
# truncate -s 65536 "demos/out/${ENTRY_FILE}/Vars.fd"

if [[ "$OSTYPE" == "darwin"* ]]; then
    platform_args="-accel hvf -cpu host"
    echo "Detected macOS"
else
    # TODO: add acceleration-options for other OSes/targets as well
    platform_args=""
fi

qemu-system-x86_64 \
    -m 4G \
    $platform_args \
    -smp 1 \
    -machine q35 \
    -display cocoa,zoom-to-fit=on \
    -device VGA,edid=on,xres=640,yres=480 \
    -serial stdio \
    -drive if=pflash,format=raw,readonly=on,file=resources/bios/OVMFx64.fd \
    -drive format=raw,file=fat:rw:demos/out/${ENTRY_FILE}
    # -drive if=pflash,format=raw,file=demos/out/${ENTRY_FILE}/Vars.fd \
