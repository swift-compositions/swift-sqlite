#!/bin/bash
# Compiles (to SIL, so that ownership, lifetime and region diagnostics run) every file of <package>/Rejected against the package's built modules. Each must be rejected; the
# compiler's diagnostic is written beside it as <name>.diagnostic.txt. Fails when one of them compiles.
#
#   Probes/rejected.sh Probes/Q1-Protocol
set -u
cd "$1" || exit 2
swift build >/dev/null 2>&1 || { echo "the package itself does not build"; exit 2; }
modules=".build/out/Products/Debug-linux-x86_64"
[ -d "$modules" ] || modules="$(swift build --show-bin-path)"
status=0
for file in Rejected/*.swift; do
    out="${file%.swift}.diagnostic.txt"
    if swiftc -emit-sil -o /dev/null -parse-as-library -swift-version 6 -I "$modules" \
        -enable-upcoming-feature NonisolatedNonsendingByDefault \
        -enable-upcoming-feature ExistentialAny \
        -enable-upcoming-feature InferIsolatedConformances \
        -enable-experimental-feature Lifetimes \
        -strict-memory-safety ${EXTRA_FLAGS:-} \
        "$file" >"$out" 2>&1
    then
        echo "ACCEPTED (expected a rejection): $file"; status=1
    else
        echo "rejected: $file"; grep -E "error:" "$out" | sed 's/^/    /'
    fi
done
exit $status
