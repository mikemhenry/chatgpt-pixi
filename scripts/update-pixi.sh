#!/bin/sh
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ "$#" -ne 1 ]; then
    printf '%s\n' "usage: $0 VERSION" >&2
    exit 2
fi
version=${1#v}
target=$(cat "$repo_root/upstream/pixi-target.txt")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
binary="$tmp/pixi-$target"
verification="$tmp/verification"

sha=$($repo_root/scripts/fetch-pixi.sh \
    --version "$version" \
    --target "$target" \
    --output "$binary" \
    --verification-dir "$verification")

printf '%s\n' "$version" > "$repo_root/upstream/pixi-version.txt"
printf '%s\n' "$sha" > "$repo_root/upstream/pixi.sha256"

# Prove the proposed new upstream still produces a valid sub-25 MB skill before
# an automated update PR is opened.
"$repo_root/scripts/build-skill.sh" --local-binary "$binary"
"$repo_root/scripts/test-skill.sh"
printf '%s\n' "Updated Pixi pin to $version ($sha)"
