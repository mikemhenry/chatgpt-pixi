# Security and provenance

`chatgpt-pixi` deliberately treats the bundled executable as a supply-chain artifact rather than source-controlled data.

## Upstream verification

Production builds download the official `pixi-x86_64-unknown-linux-musl.tar.gz` archive and its matching `.tar.gz.sha256` sidecar from the pinned `prefix-dev/pixi` release. `scripts/fetch-pixi.sh` verifies GitHub's immutable-release attestation, verifies that both consumed assets are covered by that release attestation, and verifies the archive against the upstream checksum sidecar. Only then does it extract `pixi`; the extracted binary must match `upstream/pixi.sha256`. GitHub release attestations and SLSA artifact attestations are distinct mechanisms; Pixi v0.77.0 provides the former for its immutable release, not a repository-scoped SLSA attestation for this archive.

The updater performs those checks before changing the pin and refuses to propose a new version that no longer produces a valid skill under the 25,000,000-byte package limit.

## Downstream verification

Tagged releases generate GitHub build provenance for `skill.zip` with `actions/attest`. Consumers should verify both `skill.zip.sha256` and the GitHub attestation before installing the skill.

## Runtime verification

The skill's `scripts/pixi` launcher verifies the decompressed Pixi SHA-256 before executing it. Cached binaries are rechecked before reuse.

## Reports

Please report suspected supply-chain or integrity problems privately through GitHub's security advisory mechanism when available rather than opening a public issue with exploit details.
