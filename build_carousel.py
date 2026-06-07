#!/usr/bin/env python3
"""
audiovisual-carousel: theme + song + images -> a static HTML carousel.

Output layout (relative to a base directory, e.g. /opt/cass-gallery):

  <theme-slug>/
    index.html
    images/
      01.jpg
      02.jpg
      ...
    README.md         (theme notes, image sources, song pick + rationale)

The index.html is a self-contained carousel: prev/next buttons, autoplay on
the song, image fade transitions. Works offline if Spotify isn't reachable.

Usage:
    build_carousel.py --theme "80s sunset chill" \\
        --images "url1,url2,url3,..." \\
        --song "Whitesnake" "Is This Love" \\
        --out /opt/cass-gallery/80s-sunset-chill
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from textwrap import dedent

UA = "cass-carousel-builder/1.0 (juan-gonzalez; github.com/JuanG970/cass-gallery)"
HEAD_JSON = {"User-Agent": UA, "Accept": "application/json"}


# ---------------------------------------------------------------------------
# Audio lookup
# ---------------------------------------------------------------------------

def lookup_song(artist: str, track: str) -> dict:
    """Resolve a song to an embeddable player.

    Returns a dict with keys: source, embed_url, audio_url (optional direct),
    title, artist. Sources tried in order:
      1. Spotify (via public search; we do not have a Spotify Web API key)
         - actually: we rely on a known ID OR fail through
      2. iTunes Search API (always works) — gives a 30s AAC preview URL
      3. YouTube embed (always works) — but we don't resolve YT IDs cheaply
    """
    # iTunes Search (always available, no key, returns 30s AAC preview)
    q = f"{artist} {track}".strip()
    url = "https://itunes.apple.com/search?" + urllib.parse.urlencode({
        "term": q, "media": "music", "limit": "1"
    })
    req = urllib.request.Request(url, headers=HEAD_JSON)
    with urllib.request.urlopen(req, timeout=15) as r:
        data = json.load(r)
    results = data.get("results") or []
    if not results:
        return {
            "source": "none",
            "title": track,
            "artist": artist,
            "embed_url": None,
            "audio_url": None,
            "note": "iTunes Search returned no results",
        }
    hit = results[0]
    return {
        "source": "itunes",
        "title": hit.get("trackName", track),
        "artist": hit.get("artistName", artist),
        "embed_url": None,
        "audio_url": hit.get("previewUrl"),  # 30s AAC preview
        "artwork": (hit.get("artworkUrl100") or "").replace("100x100", "600x600"),
        "track_view_url": hit.get("trackViewUrl"),
        "note": "30s preview — full track not embeddable without API key",
    }


# ---------------------------------------------------------------------------
# Image lookup
# ---------------------------------------------------------------------------

def _wiki_thumb_url(title: str, width: int = 800) -> str | None:
    """Resolve a Wikimedia Commons file title to a thumbnail URL."""
    api = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode({
        "action": "query", "format": "json", "titles": title,
        "prop": "imageinfo", "iiprop": "url", "iiurlwidth": str(width),
    })
    req = urllib.request.Request(api, headers={"User-Agent": UA, "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            data = json.load(r)
    except Exception as e:
        return None
    pages = data.get("query", {}).get("pages", {})
    for page in pages.values():
        info = (page.get("imageinfo") or [{}])[0]
        return info.get("thumburl") or info.get("url")
    return None


def _wiki_search_files(query: str, n: int = 5) -> list[str]:
    """Return up to n Commons file titles matching the query."""
    api = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode({
        "action": "query", "format": "json", "list": "search",
        "srsearch": query, "srnamespace": "6", "srlimit": str(n),
    })
    req = urllib.request.Request(api, headers={"User-Agent": UA, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=15) as r:
        data = json.load(r)
    return [h["title"] for h in data.get("query", {}).get("search", [])]


def grab_images(queries: list[str], n_target: int = 6) -> list[dict]:
    """For each query, resolve Wikimedia file titles to thumbnail URLs.

    Returns a list of {query, title, url, source} dicts.
    """
    out = []
    seen_titles = set()
    for q in queries:
        if len(out) >= n_target:
            break
        titles = _wiki_search_files(q, n=5)
        for t in titles:
            if t in seen_titles:
                continue
            seen_titles.add(t)
            url = _wiki_thumb_url(t, width=800)
            if not url:
                continue
            out.append({"query": q, "title": t, "url": url, "source": "wikimedia"})
            if len(out) >= n_target:
                break
        time.sleep(1.5)  # be polite to Wikimedia; their 429 threshold is strict
    return out


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

HTML_TEMPLATE = dedent("""\
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>{title} — Cass // Studio</title>
<meta name="description" content="{description}" />
<link rel="stylesheet" href="../assets/style.css" />
<style>
  .carousel-wrap {{
    max-width: 720px; margin: 0 auto; padding: 20px;
  }}
  .stage {{
    position: relative; aspect-ratio: 4 / 3;
    background: #000; border-radius: 8px; overflow: hidden;
    box-shadow: 0 4px 24px rgba(0,0,0,0.5);
  }}
  .stage img {{
    position: absolute; inset: 0; width: 100%; height: 100%;
    object-fit: cover; opacity: 0; transition: opacity 0.7s ease;
  }}
  .stage img.active {{ opacity: 1; }}
  .controls {{
    display: flex; justify-content: space-between; align-items: center;
    margin-top: 16px; gap: 12px;
  }}
  .controls button {{
    background: var(--bg-elevated); color: var(--fg);
    border: 1px solid var(--accent-cyan); border-radius: 4px;
    padding: 8px 16px; font-family: var(--font-mono); font-size: 0.9rem;
    cursor: pointer;
  }}
  .controls button:hover {{ background: var(--accent-cyan); color: var(--bg); }}
  .counter {{
    font-family: var(--font-mono); color: var(--fg-dim);
    font-size: 0.85rem;
  }}
  .player {{
    margin-top: 24px; padding: 16px; background: var(--bg-elevated);
    border-radius: 8px; border: 1px solid var(--accent-magenta);
  }}
  .player audio {{ width: 100%; margin-top: 8px; }}
  .player .meta {{
    font-family: var(--font-mono); font-size: 0.85rem; color: var(--fg-dim);
  }}
  .player .meta strong {{ color: var(--accent-yellow); }}
  .caption {{
    margin-top: 24px; padding: 16px; background: var(--bg-elevated);
    border-radius: 8px; font-size: 0.95rem; line-height: 1.5;
  }}
  .caption h3 {{ margin-top: 0; }}
  .caption .sources {{
    font-size: 0.8rem; color: var(--fg-dim); margin-top: 12px;
  }}
  .caption .sources li {{ font-family: var(--font-mono); }}
</style>
</head>
<body>
<main>
  <header class="site">
    <h1>Cass <span class="cyan">//</span> Studio</h1>
    <nav>
      <a href="../">Gallery</a>
      <a href="../about.html">About</a>
    </nav>
  </header>

  <div class="carousel-wrap">
    <h2 style="margin-bottom:8px;">{title}</h2>
    <p style="color:var(--fg-dim);margin-top:0;font-family:var(--font-mono);">
      {tagline}
    </p>

    <div class="stage" id="stage">
      {img_tags}
    </div>

    <div class="controls">
      <button id="prev">&larr; Prev</button>
      <span class="counter"><span id="cur">1</span> / {n}</span>
      <button id="next">Next &rarr;</button>
    </div>

    <div class="player">
      <div class="meta">
        <strong>Now playing:</strong> {song_artist} &mdash; {song_title}
        <span style="color:var(--fg-dim);"> &middot; {song_note}</span>
      </div>
      {audio_tag}
    </div>

    <div class="caption">
      <h3>About this piece</h3>
      <p>{description}</p>
      <ul class="sources">
        {source_list}
      </ul>
    </div>
  </div>

  <footer class="site">
    <span><a href="../">&larr; Back to gallery</a></span>
    <span>Built by <a href="https://github.com/JuanG970/cass-gallery">Cass</a></span>
  </footer>
</main>

<script>
  const imgs = document.querySelectorAll('#stage img');
  let i = 0;
  const cur = document.getElementById('cur');
  function show(n) {{
    imgs.forEach((im, k) => im.classList.toggle('active', k === n));
    cur.textContent = (n + 1);
    i = n;
  }}
  document.getElementById('prev').onclick = () => show((i - 1 + imgs.length) % imgs.length);
  document.getElementById('next').onclick = () => show((i + 1) % imgs.length);
  document.addEventListener('keydown', (e) => {{
    if (e.key === 'ArrowLeft') show((i - 1 + imgs.length) % imgs.length);
    if (e.key === 'ArrowRight') show((i + 1) % imgs.length);
  }});
  show(0);
</script>
</body>
</html>
""")


def build(theme: str, queries: list[str], song: dict, out_dir: Path,
          n_images: int = 6, description: str = "",
          tagline: str = "", image_urls: list[str] | None = None) -> None:
    out_dir = Path(out_dir)
    img_dir = out_dir / "images"
    img_dir.mkdir(parents=True, exist_ok=True)

    # Download images
    items = []
    if image_urls:
        for u in image_urls:
            items.append({"query": "(direct url)", "title": Path(u).name, "url": u, "source": "direct"})
    else:
        items = grab_images(queries, n_target=n_images)

    if not items:
        print(f"  WARNING: no images found for theme {theme!r}", file=sys.stderr)

    for k, item in enumerate(items, 1):
        ext = ".jpg"
        # determine extension from URL
        m = re.search(r"\.(jpg|jpeg|png|webp|gif)(\?|$)", item["url"], re.I)
        if m:
            ext = "." + m.group(1).lower()
        dest = img_dir / f"{k:02d}{ext}"
        # retry-with-backoff for 429s
        last_err = None
        for attempt in range(3):
            try:
                req = urllib.request.Request(item["url"], headers={"User-Agent": UA})
                with urllib.request.urlopen(req, timeout=20) as r:
                    with open(dest, "wb") as f:
                        shutil.copyfileobj(r, f)
                print(f"  saved {dest.relative_to(out_dir)}  ({dest.stat().st_size} bytes)")
                last_err = None
                break
            except urllib.error.HTTPError as e:
                last_err = e
                if e.code == 429:
                    wait = 5 * (attempt + 1)
                    print(f"    429, sleeping {wait}s ...", file=sys.stderr)
                    time.sleep(wait)
                else:
                    break
            except Exception as e:
                last_err = e
                break
        if last_err is not None:
            print(f"  FAILED to download {item['url']}: {last_err}", file=sys.stderr)

    # Render index.html
    img_tags_lines = []
    for k, item in enumerate(items, 1):
        suffix = Path(item["url"]).suffix or ".jpg"
        active = ' class="active"' if k == 1 else ""
        img_tags_lines.append(
            f'<img src="images/{k:02d}{suffix}" alt="{item["title"]}"{active} />'
        )
    img_tags = "\n      ".join(img_tags_lines)
    source_list = "\n        ".join(
        f'<li>image {k}: {item["title"]} (via {item["source"]})</li>'
        for k, item in enumerate(items, 1)
    )

    if song["source"] == "itunes" and song["audio_url"]:
        audio_tag = f'<audio controls preload="none" src="{song["audio_url"]}"></audio>'
    else:
        audio_tag = (
            f'<p style="color:var(--fg-dim);font-style:italic;">'
            f'No playable preview. Search on your favorite platform: '
            f'<a href="{song.get("track_view_url", "#")}">{song["artist"]} — {song["title"]}</a></p>'
        )

    html = HTML_TEMPLATE.format(
        title=theme,
        tagline=tagline or f"a {len(items)}-image carousel",
        description=description or f"An audiovisual experiment: images of '{theme}' paired with a song that fits the mood.",
        img_tags=img_tags,
        n=len(items),
        song_artist=song["artist"],
        song_title=song["title"],
        song_note=song.get("note", ""),
        audio_tag=audio_tag,
        source_list=source_list,
    )
    (out_dir / "index.html").write_text(html)
    print(f"  wrote {out_dir / 'index.html'}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--theme", required=True, help="Theme name (used as title)")
    ap.add_argument("--queries", nargs="+",
                    help="Wikimedia search queries to grab images")
    ap.add_argument("--image-urls", nargs="+", default=None,
                    help="Direct image URLs (overrides --queries)")
    ap.add_argument("--artist", required=True, help="Song artist")
    ap.add_argument("--track", required=True, help="Song track")
    ap.add_argument("--out", required=True, help="Output directory")
    ap.add_argument("--n", type=int, default=6, help="Target image count")
    ap.add_argument("--description", default="")
    ap.add_argument("--tagline", default="")
    args = ap.parse_args()

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"Resolving song: {args.artist} — {args.track}")
    song = lookup_song(args.artist, args.track)
    print(f"  source: {song['source']}, has audio: {bool(song.get('audio_url'))}")

    print(f"Building carousel at {out_dir}")
    build(
        theme=args.theme,
        queries=args.queries or [],
        song=song,
        out_dir=out_dir,
        n_images=args.n,
        description=args.description,
        tagline=args.tagline,
        image_urls=args.image_urls,
    )
    print("done.")


if __name__ == "__main__":
    main()
