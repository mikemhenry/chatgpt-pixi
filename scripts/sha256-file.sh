#!/bin/sh
set -eu
if [ "$#" -ne 1 ]; then
    printf '%s\n' "usage: $0 FILE" >&2
    exit 2
fi
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
elif command -v python3 >/dev/null 2>&1; then
    python3 - "$1" <<'PY'
import hashlib
import pathlib
import sys
p = pathlib.Path(sys.argv[1])
h = hashlib.sha256()
with p.open('rb') as f:
    for chunk in iter(lambda: f.read(1024 * 1024), b''):
        h.update(chunk)
print(h.hexdigest())
PY
else
    printf '%s\n' 'error: need sha256sum, shasum, or python3' >&2
    exit 1
fi
