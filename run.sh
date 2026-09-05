#!/bin/bash
set -e
set -u

ENTRY_FILE=$1

# Mounts the output-folder directly - can also flash the binary to 
qemu-system-x86_64 -serial stdio -bios ./resources/bios/OVMFx64.fd -drive format=raw,file=fat:rw:demos/out/${ENTRY_FILE}