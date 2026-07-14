#!/usr/bin/env python3
"""Merge a supplementary source of tools/links into data/osint-tools.json.

Unlike import_osint4all.py (a one-shot bootstrap with an overwrite guard), this
script is meant to be run repeatedly as new complementary sources are found —
it merges INTO the existing catalog rather than replacing it, and never
overwrites an existing entry.

Input is a small JSON file you prepare from the source (start.me pages can't be
scraped by script — read them in a real browser and transcribe), shaped like:

    {
      "importedFrom": "https://start.me/p/0Pqbdg/osint-500-tools",
      "entries": [
        {"category": "Cryptocurrency", "name": "Blockchain Explorer", "url": "https://www.blockchain.com/explorer"},
        {"category": "Cryptocurrency", "name": "Blockchair", "url": "https://blockchair.com", "notes": "multi-chain"}
      ]
    }

Deduplication is by NORMALIZED URL, not by the composite category+name id: the
same tool re-listed under a different source often lands in a differently
named category or with a slightly different label, so an id-based collision
check would miss it and silently import a duplicate. The URL is the only
identity signal shared across sources — normalized (lowercase host, strip
"www.", strip scheme, strip trailing slash, strip fragment) so
"https://Example.com/" and "http://example.com" compare equal.

Category reconciliation: an incoming entry's category is matched against
existing categories by slug; if none matches, a new category is created
(appended at the end, after the highest existing `order`).

Before writing, each new entry's URL is checked for liveness (reusing
check_dead_links.check_url) so we don't import a link that's already dead in
the new source — clear 404/DNS-failure entries are dropped, but 403/429/5xx/
timeout ("uncertain" — often bot-blocking) are kept with a warning rather than
silently dropped, since those are not reliably "dead". Pass
--skip-link-check to disable this (e.g. offline dry runs).

Never mutates or removes any existing entry — on a URL collision the existing
entry always wins, so this is always safe to run against manual edits.

Usage:
    python3 Scripts/merge_source.py <input.json> [--catalog PATH] [--skip-link-check] [--dry-run]
"""
import argparse
import json
import sys
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from import_osint4all import slugify, dedupe  # noqa: E402
from check_dead_links import check_url  # noqa: E402


def normalize_url(url):
    parsed = urllib.parse.urlsplit(url.strip())
    host = parsed.netloc.lower()
    if host.startswith("www."):
        host = host[4:]
    path = parsed.path.rstrip("/")
    return f"{host}{path}{('?' + parsed.query) if parsed.query else ''}".lower()


def load_json(path):
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def build_existing_index(catalog):
    """Existing normalized URLs, category slug -> category dict, and per-category
    tool-slug-seen counters seeded from what's already there (so new ids never
    collide with existing ones)."""
    existing_urls = set()
    categories_by_id = {}
    tool_slugs_seen_by_category = {}
    category_slugs_seen = {}

    for category in catalog["categories"]:
        categories_by_id[category["id"]] = category
        category_slugs_seen[category["id"]] = 1
        tool_slugs_seen_by_category[category["id"]] = {}
        for tool in category["tools"]:
            existing_urls.add(normalize_url(tool["url"]))
            # Seed the dedupe counter for this category's tool slugs so a new
            # entry can't mint an id that already exists.
            tool_slugs_seen_by_category[category["id"]][tool["id"]] = 1

    return existing_urls, categories_by_id, tool_slugs_seen_by_category, category_slugs_seen


def reconcile_category(category_name, categories_by_id, category_slugs_seen, catalog):
    slug = slugify(category_name)
    if slug in categories_by_id:
        return categories_by_id[slug]

    next_order = max((c["order"] for c in catalog["categories"]), default=-1) + 1
    new_category = {"id": slug, "name": category_name, "order": next_order, "tools": []}
    catalog["categories"].append(new_category)
    categories_by_id[slug] = new_category
    category_slugs_seen[slug] = 1
    return new_category


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("input", help="path to the JSON file describing entries to merge (see module docstring)")
    parser.add_argument("--catalog", default=None, help="path to data/osint-tools.json (default: repo's)")
    parser.add_argument("--skip-link-check", action="store_true", help="don't check new entries' URLs before writing")
    parser.add_argument("--timeout", type=float, default=6.0, help="per-request timeout for the link check (default: 6)")
    parser.add_argument("--dry-run", action="store_true", help="print what would happen, don't write the catalog")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    catalog_path = Path(args.catalog) if args.catalog else repo_root / "data" / "osint-tools.json"
    input_path = Path(args.input)

    source = load_json(input_path)
    catalog = load_json(catalog_path)

    existing_urls, categories_by_id, tool_slugs_seen_by_category, category_slugs_seen = build_existing_index(catalog)

    added, skipped_duplicate, skipped_dead, uncertain_kept, new_categories = 0, 0, 0, 0, 0

    for entry in source["entries"]:
        url = entry["url"].strip()
        normalized = normalize_url(url)
        if normalized in existing_urls:
            skipped_duplicate += 1
            continue

        if not args.skip_link_check:
            result = check_url({"id": "", "name": entry["name"], "url": url, "category": entry["category"]}, args.timeout)
            if not result["ok"]:
                status = result.get("status")
                is_uncertain = status in (403, 429) or (status is not None and status >= 500) or (
                    status is None and "timeout" in str(result.get("error", "")).lower()
                )
                if is_uncertain:
                    uncertain_kept += 1
                    print(f"  ! kept despite uncertain check ({status or result.get('error')}): {entry['name']} — {url}")
                else:
                    skipped_dead += 1
                    print(f"  x dropped, looks dead ({status or result.get('error')}): {entry['name']} — {url}")
                    continue

        was_new_category = slugify(entry["category"]) not in categories_by_id
        category = reconcile_category(entry["category"], categories_by_id, category_slugs_seen, catalog)
        if was_new_category:
            new_categories += 1

        base_slug = f"{category['id']}-{slugify(entry['name'])}"
        tool_id = dedupe(base_slug, tool_slugs_seen_by_category.setdefault(category["id"], {}))
        category["tools"].append({
            "id": tool_id,
            "name": entry["name"],
            "url": url,
            "notes": entry.get("notes"),
            "addedManually": False,
        })
        existing_urls.add(normalized)
        added += 1

    print(
        f"\n{added} added, {skipped_duplicate} skipped (duplicate URL), "
        f"{skipped_dead} skipped (looks dead), {uncertain_kept} kept despite uncertain check, "
        f"{new_categories} new categories."
    )

    if args.dry_run:
        print("(dry run — not writing catalog)")
        return

    if added == 0:
        print("Nothing to write.")
        return

    catalog["generatedAt"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with catalog_path.open("w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"✓ wrote {catalog_path}")


if __name__ == "__main__":
    main()
