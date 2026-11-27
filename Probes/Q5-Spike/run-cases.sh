#!/bin/bash
# Builds Cases.swift in debug and in -O, runs the three run-time cases, and runs the compile-time case of Isolation/.
# Writes CASES.<platform>.<build>.txt and CASES.<platform>.isolation.txt.
#
#   Probes/Q5-Spike/run-cases.sh [rule] [posts]
set -u
cd "$(dirname "$0")"
only=""
if [ "${1:-}" = rule ]; then only=rule; shift; fi
posts=${1:-20000}
platform=$(uname -s | tr 'A-Z' 'a-z')
flags="-swift-version 6 -parse-as-library -enable-upcoming-feature NonisolatedNonsendingByDefault"
mkdir -p .build
swiftc $flags -Onone -D DEBUG Cases.swift -o .build/cases-debug || exit 1
swiftc $flags -O Cases.swift -o .build/cases-O || exit 1
for build in debug O; do
    [ -z "$only" ] && {
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
        for run in 1 2 3; do
            echo
            echo "== ./cases own $posts (run $run)"
            .build/cases-$build own "$posts"
        done
        echo
        echo "== ./cases cross"
        .build/cases-$build cross 2000
        for run in 1 2 3; do
            echo
            echo "== ./cases cancel 2000 (run $run)"
            .build/cases-$build cancel 2000
        done
    } > "CASES.$platform.$build.txt" 2>&1
    # The decided rule, added last. `run-cases.sh rule` runs only this part.
    {
        swiftc --version 2>&1 | head -2
        uname -srm
        for run in 1 2 3; do
            echo
            echo "== ./cases body $posts (run $run)"
            .build/cases-$build body "$posts"
            echo
            echo "== ./cases child (run $run)"
            .build/cases-$build child
        done
    } > "CASES.$platform.$build.rule.txt" 2>&1
done
[ -z "$only" ] && {
    swiftc --version 2>&1 | head -2
    uname -srm
    echo
    Isolation/check.sh
} > "CASES.$platform.isolation.txt" 2>&1
exit 0
