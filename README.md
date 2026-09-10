Bootable applications
===

TL;DR:
--
`./build-and-run hello.zig`

About
--

**Design goals of project: To be a playing- and learning ground for UEFI based development. Simplicity and readability over cleverness.**

This repo contains the second installment of the bootable applications project, supporting the talk "Bootable applications - fully interactive applications".

Att! This might be merged with the original bootable applications repository to create a complete set of examples for multiple languages and tool chains. We'll see!

The core goal of this project is to provide a basic playing ground for people interested in exploring what is possible without a proper operating system, mainly through utilization of the UEFI firmware.

Structure:
---
```
/
    demos/ - single file entry points for specific experiments
        hello.zig - example of such experiment
    resources/ - vendored files from external sources
        OVMFx64.fd - firmware providing UEFI capabilities for qemu. From the EDK II SDK.
        font8x8/ - minimal 8x8 font glyphs from https://github.com/dhepper/font8x8
    ---
    build.sh and other convenience scripts
```

The scripts in the root folder supports building, running and flashing the demos. All the scripts takes the name of the entry point file as first argument (e.g. `./build-and-run.sh hello.zig` to build demos/hello.zig and launch qemu upon success).

The flashusb-scripts also takes the device to flash as a second argument (e.g. `./flashusb-macos.sh hello.zig /dev/disk2`)

Recommended reading
---
* ...


Thanks / credits
---

* [TerjeW](https://github.com/terjew) - For discussions and contributions to all aspects of this project. For always being up to geek out on anything.


TODO
---
* Simply integer type handling - currently lots of brute force casting in the utility functions
* Simplify builds for ARM
* Investigate possibilities for embedding GPU-drivers
* Create demo which showcases the proper OS handover from UEFI?
