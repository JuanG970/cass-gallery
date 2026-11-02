#!/usr/bin/env python3
"""Link and asset integrity check for the Cass Gallery static site.

Standard library only; run from anywhere as `python3 scripts/check_site.py`.
Over every tracked .html file it checks that each local href/src resolves on
disk, each pieces/*.html is linked from index.html, each carousel folder (any
top-level directory that is not assets/, media/, pieces/ or scripts/) has an
index.html, and each file under media/ is referenced by some page.
Exits 0 when the site is clean, 1 when anything fails.
"""

import os
import re
import subprocess
import sys
from urllib.parse import unquote

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Top-level directories that are containers or tooling, not carousel pieces.
NOT_CAROUSELS = {"assets", "media", "pieces", "scripts"}

# Files under media/ that are deliberately referenced by nothing. This is the
# only place a stray asset may sit without a consumer; each entry carries the
# reason it is still worth keeping.
ALLOW_UNREFERENCED_MEDIA = {
    "media/horizon-svg-preview.png": "alternate preview for an earlier SVG piece",
    "media/lighthouse-animated.svg": "animated variant kept as a source sketch",
    "media/preview-carousel-80s.png": "older carousel card preview",
    "media/preview-gallery-v2.png": "earlier landing-page mockup",
    "media/preview-gallery-with-carousels.png": "earlier landing-page mockup",
    "media/synthwave-horizon/index.html": "retired carousel experiment, kept for reference",
}

ATTR_RE = re.compile(r"""(?:href|src)\s*=\s*["']([^"']*)["']""", re.IGNORECASE)
SKIP_SCHEMES = ("http://", "https://", "mailto:", "tel:", "data:", "javascript:")


def tracked_files(suffix=None):
    """Tracked paths relative to ROOT, sorted. Falls back to a walk."""
    try:
        out = subprocess.run(
            ["git", "-C", ROOT, "ls-files", "-z"],
            capture_output=True, check=True,
        ).stdout.decode("utf-8", "replace")
        names = [n for n in out.split("\0") if n]
    except (OSError, subprocess.CalledProcessError):
        names = []
        for base, dirs, files in os.walk(ROOT):
            dirs[:] = [d for d in dirs if d not in {".git", "__pycache__", "node_modules"}]
            for f in files:
                names.append(os.path.relpath(os.path.join(base, f), ROOT))
    names = sorted(n.replace(os.sep, "/") for n in names)
    if suffix:
        names = [n for n in names if n.endswith(suffix)]
    return names


def local_refs(page):
    """Yield the raw local URLs referenced by one page."""
    with open(os.path.join(ROOT, page), encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    for match in ATTR_RE.finditer(text):
        url = match.group(1).strip()
        if not url or url.startswith("#") or url.startswith("//"):
            continue
        if url.lower().startswith(SKIP_SCHEMES):
            continue
        # Drop query/fragment: neither changes which file is fetched.
        url = unquote(url.split("#", 1)[0].split("?", 1)[0])
        if url:
            yield url


def resolve(page, url):
    """Map a page-relative or root-relative URL to a repo-relative path."""
    if url.startswith("/"):
        joined = os.path.normpath(url.lstrip("/")) if url.strip("/") else "."
    else:
        joined = os.path.normpath(os.path.join(os.path.dirname(page), url))
    return str(joined).replace(os.sep, "/")


def main():
    pages = tracked_files(".html")
    media = [p for p in tracked_files() if p.startswith("media/")]
    problems = []

    # 1. Every local reference must land on a file or directory.
    referenced = set()
    basenames = set()
    ref_count = 0
    broken = {}  # (target, page) -> None, so each pair is reported once
    for page in pages:
        for url in local_refs(page):
            ref_count += 1
            target = resolve(page, url)
            if os.path.exists(os.path.join(ROOT, target)):
                referenced.add(target)
                basenames.add(os.path.basename(target))
                continue
            broken[(target if target != "." else url, page)] = None
    for (target, page) in broken:
        problems.append(f"broken reference: {target} — referenced by {page} — missing on disk")

    # 2. Every piece detail page must be reachable from the landing page.
    linked_from_index = set()
    for url in local_refs("index.html"):
        target = resolve("index.html", url)
        if target.startswith("pieces/"):
            linked_from_index.add(target)
    for piece in (p for p in pages if p.startswith("pieces/")):
        if piece not in linked_from_index:
            problems.append(f"unlinked piece: {piece} — not linked from index.html")

    # 3. Every carousel folder carries its own landing page.
    for entry in sorted(os.listdir(ROOT)):
        path = os.path.join(ROOT, entry)
        if not os.path.isdir(path) or entry.startswith(".") or entry in NOT_CAROUSELS:
            continue
        if not os.path.isfile(os.path.join(path, "index.html")):
            problems.append(f"carousel missing index.html: {entry}/ — folder has no index.html")

    # 4. Every media asset must be referenced by some page.
    #    Page names are all index.html, so an HTML file is matched by path only;
    #    everything else is matched by path or basename.
    for asset in media:
        by_path = asset in referenced
        by_name = not asset.endswith(".html") and os.path.basename(asset) in basenames
        if by_path or by_name:
            if asset in ALLOW_UNREFERENCED_MEDIA:
                print(f"note: allowlisted {asset} is now referenced; drop it from the allowlist")
            continue
        if asset in ALLOW_UNREFERENCED_MEDIA:
            continue
        problems.append(f"unreferenced asset: {asset} — no page links to it")

    for asset in ALLOW_UNREFERENCED_MEDIA:
        if not os.path.exists(os.path.join(ROOT, asset)):
            print(f"note: allowlisted {asset} no longer exists; drop it from the allowlist")

    print(f"check_site: {len(pages)} pages, {len(media)} media files, {ref_count} local references")
    for problem in problems:
        print(f"FAIL {problem}")
    if problems:
        print(f"{len(problems)} problem(s) found")
        return 1
    print("all checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
