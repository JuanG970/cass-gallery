# Cass Studio Gallery

A gallery of small low-resolution pieces across five mediums — TIC-80 fantasy-console carts, SVG illustrations (some animated with SMIL), ASCII textures, audiovisual image+song carousels, and multi-medium triptychs. Deployed as a static GitHub Pages site.

## What's in here

- `index.html` — the gallery landing page (five sections: Audiovisual / Fantasy Consoles / Vector & Text / Triptychs)
- `about.html` — about the project
- `pieces/<slug>.html` — one page per piece (cart / svg / ascii), with assets and notes
- `<carousel-slug>/index.html` — one folder per carousel (the folder *is* the piece)
- `media/<slug>/` — assets for multi-file pieces (TIC-80 carts: .tic, preview.gif, preview.png, source .lua; some ASCII: .txt in a subdir)
- `media/<slug>.<ext>` — single-file media (svg or txt) for a piece
- `assets/style.css` — shared synthwave-leaning dark theme
- `TASTE.md` — running log of carousel song picks and the reasoning behind each
- `build_carousel.py` — builds a new carousel folder from a theme + song + image set

## Adding a new piece

The actual workflow lives in the `cass-gallery-deploy` skill. Quick orientation:

### TIC-80 cart
1. Author Lua in `/opt/tic80/code.lua`; capture preview.gif + preview.png into `/opt/tic80/out/`
2. Stage assets to `/root/Projects/cass-gallery/media/<slug>/`
3. Write `pieces/<slug>.html` (model on `pieces/rowboat-at-night.html` or `pieces/still-lake-at-night.html`)
4. Add a card to `index.html`'s `.cart-grid` under "Fantasy Consoles"
5. Commit and push to main → GitHub Pages auto-deploys

### SVG
1. Hand-author at `/tmp/<slug>.svg`, render with cairosvg and vision-check before staging
2. Stage to `/root/Projects/cass-gallery/media/<slug>.svg` (top level, NOT in a subdir — it's a single file)
3. Write `pieces/<slug>.html`
4. Add a card under "Vector & Text"

### ASCII
1. Author the .txt at `/root/Projects/cass-gallery/media/<slug>/<slug>.txt` (single file in subdir OR at top level as `media/<slug>.txt`)
2. Write `pieces/<slug>.html`
3. Generate the card-preview `<pre>` block with `scripts/make_ascii_card_preview.py` so the index.html copy can't drift from the source
4. Add a card under "Vector & Text"

### Audiovisual carousel
1. Read `TASTE.md` for the wish list + patterns
2. Pick a theme + song; resolve via `python3 build_carousel.py --theme ... --queries ... --artist ... --track ... --out <slug>/`
3. Vision-check all candidates before committing; curate to one light, one tempo
4. Add a card under "Audiovisual" (the carousel folder IS the piece, href is `<slug>/index.html`)

## Local preview

```sh
cd /root/Projects/cass-gallery
python3 -m http.server 8000
# open http://localhost:8000
```

## Deployment

GitHub Pages serves from the default branch at `/`. The custom domain
is `juan-gonzalez.org/cass-gallery/`, so every internal link is
**relative** (no leading `/`) — `media/<slug>/preview.gif` from a
top-level page, `../media/foo.svg` from a `pieces/` page.

## Skills referenced

- `cass-gallery-deploy` — the full deploy workflow, pre-flight checks, sharp edges
- `tic80-headless` (now archived; see `headless-game-runtime`) — TIC-80 byte-patch recipe, x11grab capture, gif re-encoding
- `audiovisual-carousel` — image curation, song-pick patterns, TASTE.md accumulation
- `ascii-art` — Tool 9 (LLM-authored composition) + Tool 10 (PIL render-to-PNG for vision verification)
