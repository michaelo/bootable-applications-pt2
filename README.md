Bootable applications
===

This repo contains the second installment of the bootable applications project, supporting the talk "Bootable applications - fully interactive applications".

Att! This might be merged with the original bootable applications repository to create a complete set of examples for multiple languages and tool chains. We'll see!

The core goal of this project is to provide a basic playing ground for people interested in exploring what is possible without a proper operating system, mainly through utilization of the UEFI bio

Structure:
---
```
/
    demos/ - single file entry points for specific experiments
        hello.zig - example of such experiment
    resources/
        OVMFx64.fd - bios providing UEFI capabilities for qemu. From the EDK II SDK.
    ---
    build.sh and other convenience scripts
```

The scripts in the root folder supports building, running and flashing the demos. All the scripts takes the name of the entry point file as first argument (e.g. `./build-and-run.sh hello.zig` to build demos/hello.zig and launch qemu upon success).

The flashusb-scripts also takes the device to flash as a second argument (e.g. `./flashusb-macos.sh hello.zig /dev/disk2`)

Recommended reading
---
* ...
