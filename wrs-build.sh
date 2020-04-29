#!/bin/bash
#
# wrs-build.sh - Used by TeamCity to execute package build
#
# This uses the PKGDIST variable from the .customerinfo file to determine which build
# scripts to use and where to copy artifacts to.
# It also expects BUILD_NUMBER to be set by TeamCity.

# Default to el7
PKGDIST=el7

if [ -z "$BUILD_NUMBER" ]; then
    echo "ERROR: BUILD_NUMBER env var not set" 1>&2
    exit 1
fi

local_conf_file=".customerinfo"

if [ -f "$local_conf_file" ]; then
    source "$local_conf_file"
fi

case "$PKGDIST" in
    ubu-lts)
        /usr/local/bin/tc-build-ubu-oxi.sh -s auto -b $BUILD_NUMBER
        find . -name \*.deb
        ;;
    el7|sles12sp4)
        /usr/local/bin/tc-build-rpm.sh -n $PKGDIST -b $BUILD_NUMBER
        ;;
    *)
        echo "ERROR: unsupported distribution '$PKGDIST'" 1>&2
        exit 1
esac

