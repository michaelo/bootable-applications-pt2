#!/bin/bash
set -e
set -u

ENTRY_FILE=$1

mkdir -p "demos/out/${ENTRY_FILE}/EFI/BOOT" || true
zig build-exe -O ReleaseFast -target x86_64-uefi-msvc -femit-bin="demos/out/${ENTRY_FILE}/EFI/BOOT/bootx64.efi" demos/$ENTRY_FILE