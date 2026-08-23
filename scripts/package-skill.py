#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import pathlib
import stat
import zipfile

FIXED_DATE = (1980, 1, 1, 0, 0, 0)


def main() -> int:
    parser = argparse.ArgumentParser(description="Create a deterministic ChatGPT skill ZIP")
    parser.add_argument("skill_dir", type=pathlib.Path)
    parser.add_argument("output", type=pathlib.Path)
    args = parser.parse_args()

    root = args.skill_dir.resolve()
    output = args.output.resolve()
    if not (root / "SKILL.md").is_file():
        raise SystemExit(f"missing {root / 'SKILL.md'}")

    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)

    with zipfile.ZipFile(output, "w") as zf:
        for path in sorted(p for p in root.rglob("*") if p.is_file()):
            rel = pathlib.PurePosixPath(root.name) / path.relative_to(root).as_posix()
            mode = 0o755 if os.access(path, os.X_OK) else 0o644
            info = zipfile.ZipInfo(str(rel), FIXED_DATE)
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | mode) << 16
            info.compress_type = zipfile.ZIP_STORED if path.suffix == ".xz" else zipfile.ZIP_DEFLATED
            with path.open("rb") as f:
                zf.writestr(info, f.read(), compress_type=info.compress_type, compresslevel=9)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
