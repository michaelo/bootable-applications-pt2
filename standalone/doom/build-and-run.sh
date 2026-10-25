#!/bin/bash
set -ue
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-uefi-msvc
mkdir -p zig-out/bin/mount/EFI/BOOT
cp zig-out/bin/puredoom_zig.efi zig-out/bin/mount/EFI/BOOT/bootx64.efi

if [[ "$OSTYPE" == "darwin"* ]]; then
    platform_args="-accel hvf -cpu host"
else
    # TODO: add acceleration-options for other OSes/targets as well
    platform_args=""
fi

qemu-system-x86_64 \
    -m 4G \
    $platform_args \
    -smp 1 \
    -machine q35 \
    -display cocoa \
    -device VGA,edid=on,xres=640,yres=480 \
    -serial stdio \
    -drive if=pflash,format=raw,readonly=on,file=../../resources/bios/OVMFx64.fd \
    -drive format=raw,file=fat:rw:zig-out/bin/mount
