#!/bin/bash
# Builds probe.c against the system SQLite and against the amalgamation of the same version, three times, and runs
# each. The amalgamation is downloaded from sqlite.org and not committed.
#
# The checksum below is that of the archive as this probe first downloaded it. It was not compared with a checksum
# published by sqlite.org; it only makes later runs use the same bytes.
#
#   Probes/Q6-Locking/run.sh
set -eu
cd "$(dirname "$0")"
version=3450100
sha=5592243caf28b2cdef41e6ab58d25d653dfc53deded8450eb66072c929f030c4
mkdir -p .build
vendored=.build/sqlite-amalgamation-$version
if [ ! -f "$vendored/sqlite3.c" ]; then
    curl -sS -o .build/sqlite.zip "https://www.sqlite.org/2024/sqlite-amalgamation-$version.zip"
    echo "$sha  .build/sqlite.zip" | sha256sum -c - >/dev/null
    (cd .build && unzip -qo sqlite.zip)
fi

echo "== system library"
cc -O2 -o .build/system probe.c -lsqlite3 -lpthread
.build/system /tmp/q6-system.sqlite

for threadsafe in 1 2 0; do
    echo
    echo "== vendored amalgamation, -DSQLITE_THREADSAFE=$threadsafe"
    cc -O2 -DSQLITE_THREADSAFE=$threadsafe -I"$vendored" -o ".build/vendored-$threadsafe" probe.c "$vendored/sqlite3.c" -lpthread -ldl -lm
    ".build/vendored-$threadsafe" "/tmp/q6-vendored-$threadsafe.sqlite"
done
