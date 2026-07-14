#!/usr/bin/env python3
"""One-shot bootstrap import of data/osint-tools.json from the CC0 osint4all README.

Downloads https://raw.githubusercontent.com/osint4all/osint4all.github.io/main/README.md
(license CC0-1.0) and parses its regular `## CATEGORY` + `[name](url)` structure into the
OSINT-index catalog schema.

This is a ONE-SHOT BOOTSTRAP TOOL, NOT A SYNC TOOL: after the initial import, data/osint-tools.json
is meant to be edited by hand in this repo. Re-running this script would blow away any manual
additions/edits/removals, so it refuses to overwrite an existing output file unless --force is
passed.

Usage:
    python3 Scripts/import_osint4all.py [--force] [--output PATH]
"""
import argparse
import json
import re
import sys
import unicodedata
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

SOURCE_URL = "https://raw.githubusercontent.com/osint4all/osint4all.github.io/main/README.md"
SOURCE_LICENSE = "CC0-1.0"

CATEGORY_RE = re.compile(r"^##\s+(.+?)\s*$")
LINK_RE = re.compile(r"\[([^\]]+)\]\((https?://[^)\s]+)\)")


def slugify(text):
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    text = text.strip("-")
    text = re.sub(r"-{2,}", "-", text)
    return text or "x"


def dedupe(base, seen):
    """Return a unique slug, appending -2, -3, ... on collision within `seen`."""
    if base not in seen:
        seen[base] = 1
        return base
    seen[base] += 1
    return f"{base}-{seen[base]}"


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "OSINT-index-import/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode("utf-8")


def parse(text):
    categories = []
    current = None
    order = 0
    category_slugs_seen = {}
    tool_slugs_seen_by_category = {}

    for line in text.splitlines():
        heading = CATEGORY_RE.match(line)
        if heading:
            name = heading.group(1).strip()
            slug = dedupe(slugify(name), category_slugs_seen)
            current = {"id": slug, "name": name, "order": order, "tools": []}
            order += 1
            categories.append(current)
            tool_slugs_seen_by_category[slug] = {}
            continue

        if current is None:
            continue  # content before the first "## " heading, if any — ignored

        for tool_name, url in LINK_RE.findall(line):
            tool_name = tool_name.strip()
            base_slug = f"{current['id']}-{slugify(tool_name)}"
            slug = dedupe(base_slug, tool_slugs_seen_by_category[current["id"]])
            current["tools"].append(
                {
                    "id": slug,
                    "name": tool_name,
                    "url": url,
                    "notes": None,
                    "addedManually": False,
                }
            )

    return categories


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--force",
        action="store_true",
        help="overwrite data/osint-tools.json if it already exists (destroys manual edits)",
    )
    parser.add_argument(
        "--output",
        default=None,
        help="output path (default: <repo>/data/osint-tools.json)",
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    output_path = Path(args.output) if args.output else repo_root / "data" / "osint-tools.json"

    if output_path.exists() and not args.force:
        print(
            f"✗ {output_path} already exists.\n"
            "  This is a one-shot bootstrap tool, not a sync tool — re-running it would\n"
            "  overwrite any manual edits made since the initial import.\n"
            "  Pass --force to overwrite anyway.",
            file=sys.stderr,
        )
        sys.exit(1)

    print(f"Fetching {SOURCE_URL} ...")
    text = fetch(SOURCE_URL)
    categories = parse(text)
    total_tools = sum(len(c["tools"]) for c in categories)

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    catalog = {
        "version": 1,
        "generatedAt": now,
        "source": {
            "importedFrom": SOURCE_URL,
            "importedAt": now,
            "license": SOURCE_LICENSE,
        },
        "categories": categories,
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"✓ wrote {output_path} — {len(categories)} categories, {total_tools} tools")


if __name__ == "__main__":
    main()
