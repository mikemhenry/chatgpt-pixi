# Changelog

## Unreleased

- Initial `Pixi Projects` ChatGPT Skill.
- Bundle official Pixi 0.77.0 for Linux x86-64 as an XZ-compressed verified asset.
- Add upstream GitHub immutable-release attestation and archive checksum verification.
- Fetch and verify Pixi's tar.gz release archive and per-archive checksum sidecar rather than expecting the raw binary in a global `sha256.sum`.
- Add deterministic skill packaging, size enforcement, runtime digest checks, CI, release provenance, and automated Pixi update PRs.
