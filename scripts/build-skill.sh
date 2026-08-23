#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
version=$(cat "$repo_root/upstream/pixi-version.txt")
target=$(cat "$repo_root/upstream/pixi-target.txt")
expected_sha=$(cat "$repo_root/upstream/pixi.sha256")
local_binary=''

usage() {
    cat <<USAGE
usage: $0 [--local-binary PATH]

Without --local-binary, fetch and cryptographically verify the pinned official
Pixi release from GitHub. --local-binary is intended for development/testing;
the supplied binary must still match the pinned SHA-256 exactly.
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --local-binary) local_binary=$2; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) printf '%s\n' "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

command -v xz >/dev/null 2>&1 || { printf '%s\n' 'error: xz is required to build the skill' >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { printf '%s\n' 'error: python3 is required to build the skill' >&2; exit 1; }

rm -rf "$repo_root/dist"
mkdir -p "$repo_root/dist/staging"
stage="$repo_root/dist/staging/pixi-projects"
cp -a "$repo_root/skill/pixi-projects" "$stage"
mkdir -p "$stage/assets" "$repo_root/dist/upstream"

raw="$repo_root/dist/pixi-$target"
if [ -n "$local_binary" ]; then
    cp "$local_binary" "$raw"
    actual_sha=$($repo_root/scripts/sha256-file.sh "$raw")
    [ "$actual_sha" = "$expected_sha" ] || {
        printf '%s\n' "error: local Pixi SHA-256 mismatch: expected=$expected_sha actual=$actual_sha" >&2
        exit 1
    }
else
    actual_sha=$($repo_root/scripts/fetch-pixi.sh \
        --version "$version" \
        --target "$target" \
        --expected-sha "$expected_sha" \
        --output "$raw" \
        --verification-dir "$repo_root/dist/upstream")
fi

printf '%s\n' "$version" > "$stage/assets/pixi.version"
printf '%s\n' "$expected_sha" > "$stage/assets/pixi.sha256"

# Extended level 4 is a practical balance: Pixi 0.77.0 compresses to about
# 23.5 MB while avoiding the very long run time of -9e. CI enforces the final
# 25,000,000-byte skill ZIP limit so future Pixi growth fails closed.
xz -4e -T1 -c "$raw" > "$stage/assets/pixi-$target.xz"

cat > "$stage/UPSTREAM.md" <<EOF2
# Bundled Pixi

- Upstream project: https://github.com/prefix-dev/pixi
- Version: $version
- Release tag: v$version
- Asset: pixi-$target
- SHA-256: $expected_sha
- License: BSD-3-Clause; see LICENSES/pixi-BSD-3-Clause.txt

The release build fetches this asset directly from the official prefix-dev/pixi
GitHub release. CI verifies Pixi's sha256.sum, GitHub's release and release-asset
attestations, and the SLSA artifact attestation for the raw binary before the
binary is compressed into this skill.
EOF2

"$repo_root/scripts/validate-skill.py" "$stage"
"$stage/scripts/pixi" --version | grep -Fx "pixi $version"
"$repo_root/scripts/package-skill.py" "$stage" "$repo_root/dist/skill.zip"

size=$(wc -c < "$repo_root/dist/skill.zip" | tr -d ' ')
limit=25000000
if [ "$size" -gt "$limit" ]; then
    printf '%s\n' "error: dist/skill.zip is $size bytes, exceeding the $limit-byte ChatGPT skill limit" >&2
    exit 1
fi

skill_sha=$($repo_root/scripts/sha256-file.sh "$repo_root/dist/skill.zip")
printf '%s  %s\n' "$skill_sha" 'skill.zip' > "$repo_root/dist/skill.zip.sha256"

cat > "$repo_root/dist/BUILD-INFO.txt" <<EOF2
skill_zip_bytes=$size
skill_zip_sha256=$skill_sha
pixi_version=$version
pixi_target=$target
pixi_sha256=$expected_sha
xz_version=$(xz --version | head -n 1)
EOF2

printf '%s\n' "Built dist/skill.zip ($size bytes)"
