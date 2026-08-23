# chatgpt-pixi

A self-contained ChatGPT Skill for working with [Pixi](https://github.com/prefix-dev/pixi) projects.

The skill embeds the official static Linux x86-64 Pixi release binary as an XZ-compressed asset. At runtime, a small launcher decompresses Pixi into a writable cache, verifies the pinned SHA-256, and executes it. This lets ChatGPT use the repository's real Pixi environments and tasks even when Pixi is not preinstalled in the execution sandbox.

## Trust model

The Pixi binary is **not committed to this repository**. Release automation reconstructs `skill.zip` from the official `prefix-dev/pixi` GitHub release and requires all of the following before packaging:

1. `gh release verify` validates GitHub's immutable-release attestation for the pinned Pixi release.
2. `gh release verify-asset` verifies that the downloaded tar.gz archive and its `.sha256` sidecar are covered by that release attestation.
3. The archive digest matches Pixi's official per-archive `.tar.gz.sha256` sidecar.
4. The archive is extracted and the resulting raw Pixi binary must match the digest committed in `upstream/pixi.sha256`.
5. The generated `skill.zip` must be at most 25,000,000 bytes and must pass a round-trip execution test.
6. Release automation creates a separate GitHub artifact attestation for the generated `skill.zip`.

Pixi's BSD-3-Clause license is included in the built skill.

## Current embedded tool

- Pixi: `0.77.0`
- Target: `x86_64-unknown-linux-musl`
- SHA-256: `6e2183fafd5f1750675c0adf4d6b3d6a1d997346043f90c0cb41bc7eb5c34078`

The skill is therefore Linux x86-64 only. The bundled Pixi executable is statically linked.

## Build locally

Requirements: `gh` 2.96 or newer, `xz`, `python3`, `unzip`, and either `sha256sum` or `shasum`. Authenticate GitHub CLI first so it can retrieve the release assets and verify GitHub's immutable-release attestation.

From fish:

```fish
./scripts/build-skill.sh
./scripts/test-skill.sh
```

The distributable file is `dist/skill.zip`.

For development with a binary you already downloaded, the build can skip the network fetch while still requiring the pinned SHA-256:

```fish
./scripts/build-skill.sh --local-binary ~/Downloads/pixi-x86_64-unknown-linux-musl
./scripts/test-skill.sh
```

## Install in ChatGPT

Upload `dist/skill.zip` as a custom Skill. The installed skill appears as **Pixi Projects** and can be invoked explicitly, for example:

```text
@Pixi Projects run the repository's Pixi check task.
```

It is also designed to trigger automatically when a repository contains `pixi.toml`, `pixi.lock`, or Pixi workspace configuration.

## Verify a published release

After downloading `skill.zip` and `skill.zip.sha256` from this repository's GitHub Release, first verify the checksum:

```fish
sha256sum -c skill.zip.sha256
```

Then verify GitHub build provenance.

```fish
set repo mikemhenry/chatgpt-pixi
gh attestation verify skill.zip --repo $repo
```

If immutable GitHub Releases are enabled for the repository, you can additionally verify that the downloaded file belongs to that release:

```fish
set repo mikemhenry/chatgpt-pixi
gh release verify-asset v0.1.0 skill.zip --repo $repo
```

For example
```bash
$ gh release verify-asset v0.1.0 ~/Downloads/skill.zip --repo mikemhenry/chatgpt-pixi
Calculated digest for skill.zip: sha256:f42d9bc58273c4675b802f7e92d61d0d0cd25d4898b3a038e3e12dbdb8a5c905
Resolved tag v0.1.0 to sha1:7fac1c66f97451e1b20e9ed988773f0a66b09c69
Loaded attestation from GitHub API

✓ Verification succeeded! skill.zip is present in release v0.1.0
```

## Updating Pixi

The repository has a scheduled workflow that checks the official Pixi latest release. When a new release appears, it verifies GitHub's immutable-release attestation, the upstream release archive and checksum sidecar, extracts the binary, confirms that it still fits in a valid skill, then opens an update PR changing only the pinned version and extracted-binary SHA-256.

You can perform the same update manually from fish:

```fish
./scripts/update-pixi.sh 0.78.0
```

The update workflow requires the repository setting that allows GitHub Actions to create pull requests. If that setting is disabled, run the update script locally and open the PR normally.

## Release process

1. Merge any desired Pixi update.
2. Tag the repository, for example `v0.1.0`.
3. Push the tag.
4. `.github/workflows/release.yml` rebuilds and verifies the skill from upstream, attests `skill.zip`, and creates a GitHub Release with the skill, checksum, build metadata, and upstream verification records.

Consider enabling GitHub's immutable releases setting as an additional protection for published releases.

## Repository layout

```text
skill/pixi-projects/       source for the Skill, excluding generated binary assets
upstream/                  pinned Pixi version, target, and SHA-256
scripts/fetch-pixi.sh      official download + upstream verification
scripts/build-skill.sh     build and size enforcement
scripts/package-skill.py   deterministic ZIP creation
scripts/test-skill.sh      unpack + execute round-trip test
scripts/update-pixi.sh     verified version bump helper
.github/workflows/         CI, release, and automatic Pixi update workflows
```

## Licensing

The integration code in this repository is MIT licensed. Pixi is redistributed in release-built skill archives under its BSD-3-Clause license; the Pixi license text is included in `skill/pixi-projects/LICENSES/` and in every generated skill.
