#!/bin/bash
# Compiles Follow.swift with each Accepted.* file (must compile) and each Rejected.* file (must not), and writes the
# diagnostics of the rejected ones to <name>.diagnostic.txt.
cd "$(dirname "$0")"
flags="-swift-version 6 -parse-as-library -enable-upcoming-feature NonisolatedNonsendingByDefault -emit-sil -wmo -o /dev/null"
status=0
for file in Accepted.*.swift; do
    if swiftc $flags Follow.swift "$file" >/dev/null 2>&1; then echo "accepted: $file"; else echo "REJECTED (expected accepted): $file"; status=1; fi
done
for file in Rejected.*.swift; do
    out="${file%.swift}.diagnostic.txt"
    if swiftc $flags Follow.swift "$file" >"$out" 2>&1; then echo "ACCEPTED (expected rejected): $file"; status=1
    else echo "rejected: $file"; grep "error:" "$out" | grep -v "^ " | sed 's/^[^:]*:[0-9]*:[0-9]*: /    /' | sort -u; fi
done
exit $status
