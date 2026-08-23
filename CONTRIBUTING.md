# Contributing

Keep the repository source-only: do not commit the generated Pixi binary, compressed asset, `dist/`, or `skill.zip`.

Before opening a pull request, from fish run:

```fish
./scripts/build-skill.sh
./scripts/test-skill.sh
```

Changes to `upstream/pixi-version.txt` and `upstream/pixi.sha256` should normally be produced by:

```fish
./scripts/update-pixi.sh <version>
```

Do not weaken upstream attestation, checksum, size, or runtime hash verification merely to make a build pass.
