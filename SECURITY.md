# Security and provenance

`chatgpt-pixi` deliberately treats the bundled executable as a supply-chain artifact rather than source-controlled data.

## Upstream verification

Production builds download the raw `pixi-x86_64-unknown-linux-musl` asset directly from the pinned `prefix-dev/pixi` release. `scripts/fetch-pixi.sh` requires the GitHub release and asset attestations, the upstream `sha256.sum`, and the artifact's SLSA attestation to verify successfully. It then requires the resulting digest to match `upstream/pixi.sha256`.

The updater performs those checks before changing the pin and refuses to propose a new version that no longer produces a valid skill under the 25,000,000-byte package limit.

## Downstream verification

Tagged releases generate GitHub build provenance for `skill.zip` with `actions/attest`. Consumers should verify both `skill.zip.sha256` and the GitHub attestation before installing the skill.

## Runtime verification

The skill's `scripts/pixi` launcher verifies the decompressed Pixi SHA-256 before executing it. Cached binaries are rechecked before reuse.

## Reports

Please report suspected supply-chain or integrity problems privately through GitHub's security advisory mechanism when available rather than opening a public issue with exploit details.
