#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
version=$(cat "$repo_root/upstream/pixi-version.txt")
target=$(cat "$repo_root/upstream/pixi-target.txt")
expected_sha=''
output=''
verification_dir=''

usage() {
    cat <<USAGE
usage: $0 [--version VERSION] [--target TARGET] --output PATH [--expected-sha SHA256] [--verification-dir DIR]

Downloads the official Pixi release binary from prefix-dev/pixi and verifies:
  1. the release-level GitHub attestation,
  2. the release asset's GitHub attestation,
  3. Pixi's sha256.sum manifest,
  4. the SLSA artifact attestation for the raw binary.
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --version) version=$2; shift 2 ;;
        --target) target=$2; shift 2 ;;
        --output) output=$2; shift 2 ;;
        --expected-sha) expected_sha=$2; shift 2 ;;
        --verification-dir) verification_dir=$2; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) printf '%s\n' "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

[ -n "$output" ] || { printf '%s\n' 'error: --output is required' >&2; exit 2; }
command -v gh >/dev/null 2>&1 || { printf '%s\n' 'error: GitHub CLI (gh) is required' >&2; exit 1; }
command -v awk >/dev/null 2>&1 || { printf '%s\n' 'error: awk is required' >&2; exit 1; }

tag="v$version"
asset="pixi-$target"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

printf '%s\n' "Fetching $asset from prefix-dev/pixi $tag" >&2
gh release download "$tag" -R prefix-dev/pixi -p "$asset" -p 'sha256.sum' -D "$tmp"

# Verify GitHub's release-level attestation and the association of this exact
# byte sequence with the immutable upstream release.
gh release verify "$tag" -R prefix-dev/pixi >/dev/null
gh release verify-asset "$tag" "$tmp/$asset" -R prefix-dev/pixi >/dev/null

manifest_sha=$(awk -v wanted="$asset" '
{
    name=$2
    sub(/^\*/, "", name)
    if (name == wanted) { print $1; exit }
}
' "$tmp/sha256.sum")
[ -n "$manifest_sha" ] || { printf '%s\n' "error: $asset not found in upstream sha256.sum" >&2; exit 1; }

actual_sha=$($repo_root/scripts/sha256-file.sh "$tmp/$asset")
[ "$actual_sha" = "$manifest_sha" ] || {
    printf '%s\n' "error: upstream manifest mismatch: manifest=$manifest_sha actual=$actual_sha" >&2
    exit 1
}
if [ -n "$expected_sha" ] && [ "$actual_sha" != "$expected_sha" ]; then
    printf '%s\n' "error: pinned SHA-256 mismatch: expected=$expected_sha actual=$actual_sha" >&2
    exit 1
fi

if [ -n "$verification_dir" ]; then
    mkdir -p "$verification_dir"
    gh release verify "$tag" -R prefix-dev/pixi --format json > "$verification_dir/upstream-release-verification.json"
    gh release verify-asset "$tag" "$tmp/$asset" -R prefix-dev/pixi --format json > "$verification_dir/upstream-release-asset-verification.json"
    gh attestation verify "$tmp/$asset" -R prefix-dev/pixi --source-ref "refs/tags/$tag" --format json > "$verification_dir/upstream-slsa-verification.json"
    cp "$tmp/sha256.sum" "$verification_dir/upstream-sha256.sum"
else
    gh attestation verify "$tmp/$asset" -R prefix-dev/pixi --source-ref "refs/tags/$tag" >/dev/null
fi

mkdir -p "$(dirname -- "$output")"
cp "$tmp/$asset" "$output"
printf '%s\n' "$actual_sha"
