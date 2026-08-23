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

Downloads the official Pixi release archive from prefix-dev/pixi and verifies:
  1. GitHub's immutable-release attestation for the pinned release,
  2. the archive and checksum sidecar against that release attestation,
  3. the archive digest against Pixi's per-archive .sha256 sidecar,
  4. the extracted Pixi binary against the optional pinned raw-binary SHA-256.
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
command -v tar >/dev/null 2>&1 || { printf '%s\n' 'error: tar is required' >&2; exit 1; }

tag="v$version"
asset="pixi-$target"
archive="$asset.tar.gz"
checksum_asset="$archive.sha256"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

printf '%s\n' "Fetching $archive from prefix-dev/pixi $tag" >&2
gh release download "$tag" -R prefix-dev/pixi -p "$archive" -p "$checksum_asset" -D "$tmp"

# Verify GitHub's immutable-release attestation for the release and for both
# upstream artifacts that we consume.
gh release verify "$tag" -R prefix-dev/pixi >/dev/null
gh release verify-asset "$tag" "$tmp/$archive" -R prefix-dev/pixi >/dev/null
gh release verify-asset "$tag" "$tmp/$checksum_asset" -R prefix-dev/pixi >/dev/null

sidecar_sha=$(awk 'NR == 1 { print $1 }' "$tmp/$checksum_asset")
sidecar_name=$(awk 'NR == 1 { name=$2; sub(/^\*/, "", name); print name }' "$tmp/$checksum_asset")
[ -n "$sidecar_sha" ] || { printf '%s\n' "error: $checksum_asset does not contain a SHA-256" >&2; exit 1; }
[ "$sidecar_name" = "$archive" ] || {
    printf '%s\n' "error: $checksum_asset names '$sidecar_name', expected '$archive'" >&2
    exit 1
}

actual_archive_sha=$($repo_root/scripts/sha256-file.sh "$tmp/$archive")
[ "$actual_archive_sha" = "$sidecar_sha" ] || {
    printf '%s\n' "error: upstream archive checksum mismatch: sidecar=$sidecar_sha actual=$actual_archive_sha" >&2
    exit 1
}

# Immutable GitHub releases carry a release attestation covering the tag,
# commit, and release assets. This is distinct from a SLSA artifact attestation:
# `gh release verify[-asset]` is the correct verifier for this upstream release.
if [ -n "$verification_dir" ]; then
    mkdir -p "$verification_dir"
    gh release verify "$tag" -R prefix-dev/pixi --format json > "$verification_dir/upstream-release-verification.json"
    gh release verify-asset "$tag" "$tmp/$archive" -R prefix-dev/pixi --format json > "$verification_dir/upstream-release-archive-verification.json"
    gh release verify-asset "$tag" "$tmp/$checksum_asset" -R prefix-dev/pixi --format json > "$verification_dir/upstream-release-checksum-verification.json"
    cp "$tmp/$checksum_asset" "$verification_dir/upstream-archive.sha256"
fi

mkdir -p "$tmp/extracted"
tar -xzf "$tmp/$archive" -C "$tmp/extracted"
extracted="$tmp/extracted/pixi"
[ -f "$extracted" ] && [ ! -L "$extracted" ] || {
    printf '%s\n' "error: $archive did not contain the expected top-level pixi binary" >&2
    exit 1
}

actual_sha=$($repo_root/scripts/sha256-file.sh "$extracted")
if [ -n "$expected_sha" ] && [ "$actual_sha" != "$expected_sha" ]; then
    printf '%s\n' "error: pinned Pixi SHA-256 mismatch: expected=$expected_sha actual=$actual_sha" >&2
    exit 1
fi

mkdir -p "$(dirname -- "$output")"
cp "$extracted" "$output"
chmod +x "$output"
printf '%s\n' "$actual_sha"
