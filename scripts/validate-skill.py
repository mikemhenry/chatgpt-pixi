#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import re
import sys


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("skill_dir", type=pathlib.Path)
    args = parser.parse_args()
    root = args.skill_dir

    skill_md = root / "SKILL.md"
    openai_yaml = root / "agents" / "openai.yaml"
    launcher = root / "scripts" / "pixi"
    archive = root / "assets" / "pixi-x86_64-unknown-linux-musl.xz"
    version = root / "assets" / "pixi.version"
    digest = root / "assets" / "pixi.sha256"
    license_file = root / "LICENSES" / "pixi-BSD-3-Clause.txt"
    for path in (skill_md, openai_yaml, launcher, archive, version, digest, license_file):
        if not path.is_file():
            fail(f"missing required skill file: {path}")

    text = skill_md.read_text()
    if not text.startswith("---\n"):
        fail("SKILL.md lacks YAML frontmatter")
    if not re.search(r"(?m)^name:\s+pixi-projects\s*$", text):
        fail("SKILL.md name must be pixi-projects")
    if not re.search(r"(?m)^description:\s+\S", text):
        fail("SKILL.md needs a description")

    sha = digest.read_text().strip()
    if not re.fullmatch(r"[0-9a-f]{64}", sha):
        fail("assets/pixi.sha256 is not a lowercase SHA-256 digest")
    if not version.read_text().strip():
        fail("assets/pixi.version is empty")
    if not (launcher.stat().st_mode & 0o111):
        fail("scripts/pixi is not executable")

    print("skill structure validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
