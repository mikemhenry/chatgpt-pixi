#!/bin/sh
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
version=$(cat "$repo_root/upstream/pixi-version.txt")
zip="$repo_root/dist/skill.zip"
[ -f "$zip" ] || { printf '%s\n' 'error: run scripts/build-skill.sh first' >&2; exit 1; }
command -v unzip >/dev/null 2>&1 || { printf '%s\n' 'error: unzip is required' >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
unzip -q "$zip" -d "$tmp"
[ -x "$tmp/pixi-projects/scripts/pixi" ] || { printf '%s\n' 'error: ZIP did not preserve launcher executable bit' >&2; exit 1; }
actual=$($tmp/pixi-projects/scripts/pixi --version)
[ "$actual" = "pixi $version" ] || { printf '%s\n' "error: expected pixi $version, got $actual" >&2; exit 1; }
printf '%s\n' "round-trip skill test passed: $actual"
