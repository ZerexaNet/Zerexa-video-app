#!/usr/bin/env python3
"""
Render release notes by substituting placeholders in a template file
with values read from external files. This avoids all bash / YAML
quoting pitfalls — values are passed via plain files, not env vars or
shell arguments.

Usage:
    render-release-notes.py \
        <template_path> <output_path> \
        <version_file> \
        <header_line_file> \
        <pre_note_file> \
        <commit_list_title_file> \
        <commit_list_file> \
        <run_number_file> \
        <run_url_file>

Template placeholders (case-sensitive, exact match):
    __VERSION__
    __HEADER_LINE__
    __PRE_NOTE__
    __COMMIT_LIST_TITLE__
    __COMMIT_LIST__
    __RUN_NUMBER__
    __RUN_URL__
"""

import sys
from pathlib import Path


def read_file(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 10:
        print(__doc__, file=sys.stderr)
        return 2

    template_path = sys.argv[1]
    output_path = sys.argv[2]
    version = read_file(sys.argv[3])
    header_line = read_file(sys.argv[4])
    pre_note = read_file(sys.argv[5])
    commit_list_title = read_file(sys.argv[6])
    commit_list = read_file(sys.argv[7])
    run_number = read_file(sys.argv[8])
    run_url = read_file(sys.argv[9])

    template = Path(template_path).read_text(encoding="utf-8")

    # Order matters: substitute longer placeholders first so shorter
    # ones don't accidentally match a substring of a longer one.
    # All our placeholders are unique strings, so order doesn't matter
    # in practice, but we sort by length descending for safety.
    substitutions = [
        ("__COMMIT_LIST_TITLE__", commit_list_title),
        ("__COMMIT_LIST__", commit_list),
        ("__HEADER_LINE__", header_line),
        ("__PRE_NOTE__", pre_note),
        ("__VERSION__", version),
        ("__RUN_NUMBER__", run_number),
        ("__RUN_URL__", run_url),
    ]
    substitutions.sort(key=lambda kv: len(kv[0]), reverse=True)

    out = template
    for placeholder, value in substitutions:
        out = out.replace(placeholder, value)

    Path(output_path).write_text(out, encoding="utf-8")
    print(f"Wrote {len(out)} bytes to {output_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
