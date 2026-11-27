#!/bin/bash
# Builds Cases.swift in debug and in -O, runs the three run-time cases, and runs the compile-time case of Isolation/.
# Writes CASES.<platform>.<build>.txt and CASES.<platform>.isolation.txt.
#
#   Probes/Q5-Spike/run-cases.sh [posts]
set -u
cd "$(dirname "$0")"
posts=${1:-20000}
platform=$(uname -s | tr 'A-Z' 'a-z')
flags="-swift-version 6 -parse-as-library -enable-upcoming-feature NonisolatedNonsendingByDefault"
mkdir -p .build
swiftc $flags -Onone -D DEBUG Cases.swift -o .build/cases-debug || exit 1
swiftc $flags -O Cases.swift -o .build/cases-O || exit 1
for build in debug O; do
    {
        swiftc --version 2>&1 | head -2
        uname -srm
        for run in 1 2 3; do
            echo
            echo "== ./cases busy $posts (run $run)"
            .build/cases-$build busy "$posts"
        done
        echo
        echo "== ./cases stuck"
        .build/cases-$build stuck
        for run in 1 2 3; do
            echo
            echo "== ./cases many $posts (run $run)"
            .build/cases-$build many "$posts"
        done
    } > "CASES.$platform.$build.txt" 2>&1
done
{
    swiftc --version 2>&1 | head -2
    uname -srm
    echo
    Isolation/check.sh
} > "CASES.$platform.isolation.txt" 2>&1
