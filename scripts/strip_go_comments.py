#!/usr/bin/env python3
"""Strip Go comments; keep file header, //go: directives, // +build, // MARK:."""

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


def full_line_comment_kept(stripped: str) -> bool:
    if not stripped.startswith("//"):
        return False
    if stripped.startswith("//go:"):
        return True
    if re.match(r"^//\s*\+build\b", stripped):
        return True
    if re.match(r"^//\s*MARK:", stripped):
        return True
    if re.match(r"^//\s*nolint\b", stripped):
        return True
    return False


def strip_trailing_comment(line: str) -> str:
    """Remove ` // ...` from a code line; respects double-quoted, raw, and rune strings."""
    i = 0
    n = len(line)
    in_double = False
    in_raw = False
    in_rune = False
    escape = False

    while i < n:
        c = line[i]

        if in_raw:
            if c == "`":
                in_raw = False
            i += 1
            continue

        if in_double:
            if escape:
                escape = False
                i += 1
                continue
            if c == "\\":
                escape = True
                i += 1
                continue
            if c == '"':
                in_double = False
            i += 1
            continue

        if in_rune:
            if escape:
                escape = False
                i += 1
                continue
            if c == "\\":
                escape = True
                i += 1
                continue
            if c == "'":
                in_rune = False
            i += 1
            continue

        if c == "`":
            in_raw = True
            i += 1
            continue
        if c == '"':
            in_double = True
            i += 1
            continue
        if c == "'":
            in_rune = True
            i += 1
            continue

        if c == "/" and i + 1 < n and line[i + 1] == "/":
            return line[:i].rstrip()
        i += 1

    return line


def strip_body_line(line: str) -> str | None:
    """Return processed line, or None if the entire line should be dropped."""
    raw = line.rstrip("\r")
    leading_ws_len = len(raw) - len(raw.lstrip())
    content = raw[leading_ws_len:]
    stripped = content.strip()

    if stripped == "":
        return raw

    if stripped.startswith("//"):
        if full_line_comment_kept(stripped):
            return raw
        return None

    without_trailing = strip_trailing_comment(raw)
    return without_trailing.rstrip()


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

    new_body: list[str] = []
    for line in body:
        processed = strip_body_line(line)
        if processed is not None:
            new_body.append(processed)

    new_body = collapse_blank_lines(new_body)

    header_txt = "\n".join(header)
    body_txt = "\n".join(new_body)

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
    backend = root / "backend"
    if not backend.is_dir():
        print("backend/ not found", file=sys.stderr)
        sys.exit(1)

    changed = 0
    for path in sorted(backend.rglob("*.go")):
        if process_file(path):
            changed += 1
            print(path.relative_to(root))
    print(f"Done. Modified {changed} files.", file=sys.stderr)


if __name__ == "__main__":
    main()
