#!/bin/bash
set -e
set -u

. build.sh $*
. make-img.sh $*
. flashusb-macos.sh $*