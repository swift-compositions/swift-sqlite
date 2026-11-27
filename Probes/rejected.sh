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
maps=()
while IFS= read -r map; do maps+=(-Xcc "-fmodule-map-file=$map"); done < <(
    find Sources ../Q*/Sources .build/checkouts -name module.modulemap -not -path "*/.build/*/.build/*" 2>/dev/null
    find .build/out/Intermediates.noindex -path "*GeneratedModuleMaps*" -name "*.modulemap" 2>/dev/null
)
for file in Rejected/*.swift; do
    out="${file%.swift}.diagnostic.txt"
    if swiftc -emit-sil -o /dev/null -parse-as-library -swift-version 6 -I "$modules" \
        -enable-upcoming-feature NonisolatedNonsendingByDefault \
        -enable-upcoming-feature ExistentialAny \
        -enable-upcoming-feature InferIsolatedConformances \
        -enable-experimental-feature Lifetimes \
        -strict-memory-safety "${maps[@]}" ${EXTRA_FLAGS:-} \
        "$file" >"$out" 2>&1
    then
        echo "ACCEPTED (expected a rejection): $file"; status=1
    elif grep -q "fatal error encountered during compilation" "$out"; then
        # Keep the compiler's own words; drop the stack dump and the register dump.
        sed -i -E '/^ *#[0-9]+ 0x|^\*\*\* Signal/,$d' "$out"
        echo "COMPILER CRASH (not accepted, but no diagnostic): $file"; grep -E "Found ownership error|Have operand" "$out" | sed 's/^/    /'
    elif grep -qE "missing required module|no such module" "$out"; then
        echo "NOT COMPILED (a module was not found): $file"; status=2
    else
        echo "rejected: $file"; grep -E "error:" "$out" | sed 's/^/    /'
    fi
done
exit $status
