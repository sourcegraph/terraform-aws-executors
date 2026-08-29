#!/usr/bin/env python3
"""Render files containing release-controlled values from checked-in templates."""

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_ROOT = ROOT / "release" / "templates"
VERSION_FILE = ROOT / "release" / "version"
VERSION_RE = re.compile(r"^(?:v)?(\d+)\.(\d+)\.(\d+)$")


def release_values(raw_version: str) -> dict[str, str]:
    match = VERSION_RE.fullmatch(raw_version.strip())
    if not match:
        raise ValueError(f"invalid release version: {raw_version!r}")
    major, minor, patch = match.groups()
    return {
        "release_version": f"{major}.{minor}.{patch}",
        "family_version": f"{major}-{minor}",
    }


def render(template: str, values: dict[str, str]) -> str:
    for name, value in values.items():
        template = template.replace("{{ " + name + " }}", value)
    unresolved = sorted(set(re.findall(r"{{\s*([a-z_]+)\s*}}", template)))
    if unresolved:
        raise ValueError(f"unknown template variables: {', '.join(unresolved)}")
    return template


def rendered_files(values: dict[str, str]):
    for template_path in sorted(TEMPLATE_ROOT.rglob("*.tmpl")):
        relative = template_path.relative_to(TEMPLATE_ROOT)
        output_path = ROOT / relative.with_suffix("")
        yield output_path, render(template_path.read_text(), values)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", help="release version (defaults to release/version)")
    parser.add_argument("--check", action="store_true", help="verify generated files are current")
    args = parser.parse_args()

    raw_version = args.version or VERSION_FILE.read_text().strip()
    try:
        values = release_values(raw_version)
        outputs = list(rendered_files(values))
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1

    stale = []
    for output_path, expected in outputs:
        if args.check:
            if not output_path.exists() or output_path.read_text() != expected:
                stale.append(str(output_path.relative_to(ROOT)))
        else:
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(expected)

    if args.check and stale:
        print("release-generated files are stale:", file=sys.stderr)
        for path in stale:
            print(f"  {path}", file=sys.stderr)
        print("run scripts/render_release.py", file=sys.stderr)
        return 1

    if not args.check:
        VERSION_FILE.write_text(values["release_version"] + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
