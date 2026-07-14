#!/usr/bin/env python3
"""Dead-link checker for data/osint-tools.json.

Checks every tool's URL with a HEAD request (falling back to GET on
HEAD-refusal), concurrently but rate-limited, and writes a report. Never
mutates data/osint-tools.json — reviewing and removing/fixing dead links stays
a manual step for Vincent.

Since the catalog has ~1450 URLs, a single run can be slow and some sites
rate-limit/block bulk checks. Use --limit/--offset/--category to check the
catalog in incremental slices across multiple sessions; progress is saved to
Scripts/.dead-link-state.json (gitignored) so a plain re-run without those
flags resumes from where the last run left off.

Usage:
    python3 Scripts/check_dead_links.py [--limit N] [--offset N] [--category SLUG]
                                        [--workers N] [--timeout SECONDS] [--reset]
"""
import argparse
import concurrent.futures
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

USER_AGENT = "OSINT-index-dead-link-check/1.0"


def load_catalog(path):
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def flatten_tools(catalog, category_slug=None):
    tools = []
    for category in catalog["categories"]:
        if category_slug and category["id"] != category_slug:
            continue
        for tool in category["tools"]:
            tools.append({"id": tool["id"], "name": tool["name"], "url": tool["url"], "category": category["name"]})
    return tools


def check_url(entry, timeout):
    url = entry["url"]
    req = urllib.request.Request(url, method="HEAD", headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return {**entry, "status": resp.status, "ok": resp.status < 400}
    except urllib.error.HTTPError as e:
        if e.code in (405, 501):  # HEAD not allowed — retry with GET
            try:
                req = urllib.request.Request(url, method="GET", headers={"User-Agent": USER_AGENT})
                with urllib.request.urlopen(req, timeout=timeout) as resp:
                    return {**entry, "status": resp.status, "ok": resp.status < 400}
            except Exception as e2:
                return {**entry, "status": None, "ok": False, "error": str(e2)}
        return {**entry, "status": e.code, "ok": e.code < 400}
    except Exception as e:
        return {**entry, "status": None, "ok": False, "error": str(e)}


def load_state(state_path):
    if state_path.exists():
        with state_path.open(encoding="utf-8") as f:
            state = json.load(f)
            state.setdefault("results", [])
            return state
    return {"next_offset": 0, "results": []}


def save_state(state_path, state):
    with state_path.open("w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)


# Status/errors that plausibly mean bot-blocking or transient failure rather than a
# genuinely dead link — never suggest deleting these without a manual look.
UNCERTAIN_STATUSES = {403, 429}


def classify(r):
    if r["ok"]:
        return "ok"
    status = r.get("status")
    if status in UNCERTAIN_STATUSES or (status is not None and status >= 500):
        return "uncertain"
    if status is not None:
        return "likely-dead"  # 404 and other clear 4xx
    error = (r.get("error") or "").lower()
    if "timed out" in error or "timeout" in error:
        return "uncertain"
    return "likely-dead"  # DNS failure, connection refused, etc.


def write_report(report_path, results):
    failing = [r for r in results if not r["ok"]]
    likely_dead = [r for r in failing if classify(r) == "likely-dead"]
    uncertain = [r for r in failing if classify(r) == "uncertain"]

    lines = [
        f"# Dead-link report — {len(failing)} of {len(results)} checked URLs failing",
        "",
        f"- **{len(likely_dead)} likely dead** (404 / DNS failure / clear 4xx) — reasonable cleanup candidates after a manual look.",
        f"- **{len(uncertain)} uncertain** (403 / 429 / 5xx / timeout) — often bot-blocking or transient, do NOT delete without checking by hand.",
        "",
        "## Likely dead",
        "",
        "| Category | Tool | URL | Status |",
        "|---|---|---|---|",
    ]
    for r in likely_dead:
        status = r.get("status") if r.get("status") is not None else r.get("error", "?")
        lines.append(f"| {r['category']} | {r['name']} | {r['url']} | {status} |")
    lines += [
        "",
        "## Uncertain (needs manual check)",
        "",
        "| Category | Tool | URL | Status |",
        "|---|---|---|---|",
    ]
    for r in uncertain:
        status = r.get("status") if r.get("status") is not None else r.get("error", "?")
        lines.append(f"| {r['category']} | {r['name']} | {r['url']} | {status} |")
    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--limit", type=int, default=200, help="max URLs to check this run (default: 200)")
    parser.add_argument("--offset", type=int, default=None, help="start offset (default: resume from saved state)")
    parser.add_argument("--category", default=None, help="only check tools in this category id (slug)")
    parser.add_argument("--workers", type=int, default=20, help="concurrent requests (default: 20)")
    parser.add_argument("--timeout", type=float, default=6.0, help="per-request timeout in seconds (default: 6)")
    parser.add_argument("--reset", action="store_true", help="ignore/reset saved resume state")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    catalog_path = repo_root / "data" / "osint-tools.json"
    state_path = repo_root / "Scripts" / ".dead-link-state.json"
    report_path = repo_root / "Scripts" / "dead-links-report.md"

    catalog = load_catalog(catalog_path)
    tools = flatten_tools(catalog, category_slug=args.category)

    state = {"next_offset": 0, "results": []} if args.reset else load_state(state_path)
    offset = args.offset if args.offset is not None else state["next_offset"]
    batch = tools[offset : offset + args.limit]

    if not batch:
        print(f"✓ Nothing left to check (offset {offset} >= {len(tools)} tools). Pass --reset to start over.")
        write_report(report_path, state["results"])
        return

    print(f"Checking {len(batch)} URLs (offset {offset}/{len(tools)}, {args.workers} workers)...")
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        results = list(pool.map(lambda e: check_url(e, args.timeout), batch))

    dead = [r for r in results if not r["ok"]]

    # Accumulate across runs (keyed by tool id) so the report reflects the whole
    # catalog swept so far, not just this batch — a plain overwrite would lose
    # every earlier incremental slice's findings.
    accumulated = {r["id"]: r for r in state["results"]}
    for r in results:
        accumulated[r["id"]] = r
    all_results = list(accumulated.values())
    write_report(report_path, all_results)

    if not args.category:
        state["next_offset"] = offset + len(batch)
        state["results"] = all_results
        save_state(state_path, state)

    total_dead = sum(1 for r in all_results if not r["ok"])
    print(f"✓ {len(dead)}/{len(results)} URLs failing in this batch. Report: {report_path}")
    print(f"  Cumulative: {total_dead}/{len(all_results)} checked so far failing.")
    if not args.category:
        print(f"  Next run resumes at offset {state['next_offset']}/{len(tools)}.")


if __name__ == "__main__":
    main()
