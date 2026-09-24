#!/bin/bash
set -e
set -u

ENTRY_FILE=$1
BASENAME=$(basename "${ENTRY_FILE}")
echo $BASENAME

# Check if file exists first
stat "demos/${ENTRY_FILE}" > /dev/null

rm -r "demos/out/${ENTRY_FILE}"
mkdir -p "demos/out/${ENTRY_FILE}/EFI/BOOT" || true
zig build-exe -O ReleaseFast -target x86_64-uefi-msvc -freference-trace=13 -femit-bin="demos/out/${ENTRY_FILE}/EFI/BOOT/bootx64.efi" demos/$ENTRY_FILE
# Copy any files under demos/<file>/files/ so it may be embedded in the image etc
if [ -d "demos/${ENTRY_FILE}-files/." ] ; then
    cp -R "demos/${ENTRY_FILE}-files/." "demos/out/${ENTRY_FILE}" > /dev/null
fi
# zig build-exe -O ReleaseFast -target aarch64-uefi-msvc -freference-trace=13 -femit-bin="demos/out/${ENTRY_FILE}/EFI/BOOT/bootx64.efi" demos/$ENTRY_FILE