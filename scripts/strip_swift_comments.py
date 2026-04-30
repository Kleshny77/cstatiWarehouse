#!/usr/bin/env python3
"""Strip Swift comments; keep file header, // MARK:, swiftlint/swift-format directives."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def split_header(lines: list[str]) -> tuple[list[str], list[str]]:
    i = 0
    while i < len(lines):
        st = lines[i].strip()
        if st == "" or st.startswith("//"):
            i += 1
            continue
        break
    return lines[:i], lines[i:]


def keep_full_line_comment(stripped: str) -> bool:
    if not stripped.startswith("//"):
        return False
    if stripped.startswith("///"):
        return False
    if re.match(r"^//\s*MARK:", stripped):
        return True
    if re.match(r"^//\s*swiftlint", stripped):
        return True
    if re.match(r"^//\s*swiftformat", stripped):
        return True
    return False


def strip_body(lines: list[str]) -> list[str]:
    out: list[str] = []
    for line in lines:
        st = line.strip()
        if st.startswith("//"):
            if keep_full_line_comment(st):
                out.append(line.rstrip("\r"))
            continue
        out.append(line.rstrip("\r"))
    return out


def collapse_blank_lines(lines: list[str]) -> list[str]:
    out: list[str] = []
    blank_run = 0
    for line in lines:
        if line.strip() == "":
            blank_run += 1
            if blank_run <= 2:
                out.append(line)
        else:
            blank_run = 0
            out.append(line)
    return out


def process_file(path: Path) -> bool:
    raw = path.read_text(encoding="utf-8")
    lines = raw.splitlines()
    header, body = split_header(lines)
    body = strip_body(body)
    body = collapse_blank_lines(body)

    header_txt = "\n".join(header)
    body_txt = "\n".join(body)

    parts: list[str] = []
    if header_txt:
        parts.append(header_txt)
    if body_txt:
        parts.append(body_txt)
    result = "\n".join(parts)
    if result and not result.endswith("\n"):
        result += "\n"

    if result != raw:
        path.write_text(result, encoding="utf-8")
        return True
    return False


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    changed = 0
    for sub in ("ios/cstatiWarehouse", "ios/cstatiWarehouseTests"):
        d = root / sub
        if not d.is_dir():
            continue
        for path in sorted(d.rglob("*.swift")):
            if process_file(path):
                changed += 1
                print(path.relative_to(root))
    print(f"Done. Modified {changed} files.", file=sys.stderr)


if __name__ == "__main__":
    main()
