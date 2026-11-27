#!/bin/bash
# Builds Spike.swift in debug and in -O and writes the results of each to RESULTS.<platform>.<build>.txt.
#
#   Probes/Q5-Spike/run.sh [posts for every variation] [posts for the variations that hold]
set -u
cd "$(dirname "$0")"
all=${1:-4000}
holding=${2:-20000}
platform=$(uname -s | tr 'A-Z' 'a-z')
flags="-swift-version 6 -parse-as-library -enable-upcoming-feature NonisolatedNonsendingByDefault"
mkdir -p .build
swiftc $flags -Onone -D DEBUG Spike.swift -o .build/spike-debug 2>.build/warnings-debug.txt || exit 1
swiftc $flags -O Spike.swift -o .build/spike-O 2>.build/warnings-O.txt || exit 1
for build in debug O; do
    out=RESULTS.$platform.$build.txt
    {
        swiftc --version 2>&1 | head -2
        uname -srm
        echo
        echo "== ./spike log"
        .build/spike-$build log
        echo
        echo "== ./spike regression"
        .build/spike-$build regression
        echo
        echo "== ./spike matrix $all"
        .build/spike-$build matrix "$all"
        echo
        echo "== ./spike matrix $holding 5"
        .build/spike-$build matrix "$holding" 5
        echo
        echo "== ./spike matrix $holding 6"
        .build/spike-$build matrix "$holding" 6
    } > "$out" 2>&1
done
