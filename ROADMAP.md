# Cass Gallery — roadmap and backlog

Planning document for `JuanG970/cass-gallery`. The gallery ships one piece per
night: author the asset, write `pieces/<slug>.html`, add a card to `index.html`,
push to `main`, GitHub Pages deploys. Everything below is proposed work, not
approved work; each candidate needs its own issue, branch, and review before
implementation.

Measurements in this document were taken against `main` at `a54cba6`
(Piece #088, 2026-10-25) with the commands quoted in each section.

## Current shape

- `index.html` — 1,946 lines, 96 anchors, 103 `<img>` tags, hand-edited on every
  night's commit (it changed in 30 of the last 30 commits).
- `pieces/` — 67 detail pages, 612 KB total; all 67 are linked from the landing
  page today (no orphans).
- 20 carousel folders (the folder *is* the piece) plus 20 TIC-80 carts,
  23 SVG, 21 ASCII, 1 canvas, 2 triptychs — matching the counts spelled out in
  the section headings.
- `media/` — 131 files, 5.5 MB; carousel `images/` — 125 files, 36.7 MB.
- No `.github/`, no tests, no check scripts. `build_carousel.py` (623 lines) is
  the only tooling in the repo.
- Deployment is static: relative links only, because the site is served from a
  subpath (`juan-gonzalez.org/cass-gallery/`).

## 1. Add a link and asset integrity check before new pieces land

**Why it matters.** A broken preview or a wrong `href` is invisible until
someone opens the page; there is nothing in the repo that checks links, assets,
or page-to-index coverage.

**Evidence.**
- No `.github/` directory exists, so no check runs on push.
- `git log --oneline -30 -- index.html | wc -l` → `30` of 30: the landing page is
  edited every night, by hand, in a 1,946-line file.
- Six unreferenced media files exist right now (`media/horizon-svg-preview.png`,
  `media/lighthouse-animated.svg`, `media/preview-carousel-80s.png`,
  `media/preview-gallery-v2.png`, `media/preview-gallery-with-carousels.png`,
  `media/synthwave-horizon/index.html`), i.e. leftovers already accumulate.
- The deploy workflow stages assets from another machine into `media/<slug>/`
  before writing the page (README "Adding a new piece"), so a missing or
  misnamed file is a normal failure mode, not a hypothetical one.

**Proposed scope.** One dependency-free Python script (`scripts/check_site.py`)
that walks every tracked `.html` file and verifies: each local `href`/`src`
resolves on disk; each `pieces/*.html` is reachable from `index.html`; each
carousel folder contains `index.html`; each file under `media/` is referenced
somewhere, with an explicit allowlist for intentional extras. Plus a workflow
that runs it on pull requests and pushes to `main`.

**Acceptance criteria.**
- Running the script on current `main` exits 0, or fails only on entries added
  to a small, commented allowlist for the six files above.
- Renaming one preview image in a scratch branch makes the script exit non-zero
  and name the file and the page that references it.
- The workflow has read-only permissions, no secrets, and no Wolfram or other
  paid runtime.
- README documents the command so a piece can be checked locally before push.

## 2. Make the landing page generated from a piece manifest

**Why it matters.** `index.html` is the single most-edited file in the repo and
the only place that knows the full catalogue. Counts, ordering, "latest" badge,
and card markup are all maintained by hand, so the landing page can drift from
the tree without any signal.

**Evidence.**
- 1,946 lines, 96 anchors, 103 images, 30/30 recent commits.
- Section headings hard-code totals that a human must keep correct:
  `Audiovisual // 20 carousels`, `Fantasy Consoles // 20 TIC-80 carts`,
  `Browser Canvas // 1 canvas`, `Vector &amp; Text // 23 SVG, 21 ASCII`,
  `Triptychs // 2 triptychs`. Link counts per section currently match
  (20 / 20 / 1 / 44 / 4), which is exactly the invariant that has no check.
- One duplicate anchor pair exists already (`pieces/free-running.html` appears
  twice in the markup), the kind of slip a generator cannot make.
- ASCII cards duplicate a `<pre>` preview that also lives in `media/*.txt`, and
  the README warns that this copy "can't drift from the source" only by
  convention.

**Proposed scope.** A `pieces.json` (or `pieces.yaml`) manifest with one entry
per piece — slug, title, medium, section, path, preview, optional song/coda
metadata — plus `scripts/generate_index.py` that renders the card sections and
heading counts from it. Keep the existing HTML/CSS unchanged in the first pass
and prove parity before switching the workflow over.

**Acceptance criteria.**
- Generated output matches the current `index.html` structure and ordering for
  all 87 cards (67 piece pages + 20 carousel folders), or every difference is
  listed and explicitly accepted.
- `python3 scripts/generate_index.py --check` exits non-zero when a piece is
  added to the manifest but not regenerated (and vice versa).
- New-piece workflow in README becomes: add entry, run generator, run check —
  no hand editing of card markup or section counts.
- `index.html` gains a "generated — do not edit" header comment.
- No change to published URLs, so existing links and the Pages path keep working.

## 3. Stop the landing page from loading 18 MB of previews eagerly

**Why it matters.** The landing page requests every preview at once. On a phone
that is a slow first paint for a page whose job is to be looked at for ten
seconds.

**Evidence.**
- 100 unique images are referenced from `index.html`, totalling **18.4 MB**
  (summed with `os.path.getsize` over every local `src`).
- Largest single preview: `lakes-at-first-light/images/01.jpg` at 1.54 MB,
  followed by `cherry-blossom-spring/images/04.jpg` at 0.71 MB and
  `vaporwave-mac-plus/images/03.jpg` at 0.61 MB.
- 21 of those images are animated GIFs (0.1–0.3 MB each).
- `grep -c 'loading="lazy"' index.html` → `0`, and no `<img>` carries
  `width`/`height`, so every card also reflows as it loads.

**Proposed scope.** Add `loading="lazy"` and `decoding="async"` to below-the-fold
cards, add intrinsic `width`/`height` (or `aspect-ratio` in CSS) to reserve
layout, and consider a smaller preview variant for carousel cards while the
detail page keeps the full-resolution image.

**Acceptance criteria.**
- Local measurement recorded before/after (`python3 -m http.server`, browser
  network panel or `curl`-based byte count): initial viewport transfer drops
  materially, with the exact numbers written into the PR.
- No card jumps on load; layout shift for the grid is zero in a scroll-through.
- Every preview still renders when JavaScript is disabled.
- Detail pages keep their current full-size images.

## 4. Set and enforce an image weight budget for carousel folders

**Why it matters.** Carousels are 36.7 MB of the repo's 38 MB and the budget is
implicit. One unshrunk image set silently makes the site heavier for everyone
and the repo slower to clone every night.

**Evidence.**
- 125 images under `*/images/`, 36.7 MB total, average 301 KB.
- The distribution is long-tailed: the top eight files are 0.55–1.54 MB, all
  full-resolution photographs.
- `build_carousel.py` fetches and stages images; nothing in it reports or caps
  output size.

**Proposed scope.** A documented budget (for example: ≤250 KB and ≤1600 px on the
long edge per carousel image, with a per-carousel total cap), a report mode in
`build_carousel.py` that prints offenders, and a check that reads the budget.
Resizing must be a deliberate, reviewed step, not a silent rewrite of the
existing 125 files.

**Acceptance criteria.**
- Budget numbers and rationale are written down in README or a `MEDIA.md`.
- `python3 build_carousel.py --audit <slug>/` (or equivalent) lists every file
  over budget with its size and dimensions.
- The integrity check from candidate 1 fails when a new carousel ships an image
  over budget, unless the allowlist records an explicit exception.
- Existing oversized images are either re-encoded in a reviewed commit or listed
  as accepted debt; no bulk unreviewed rewrite.

## 5. Give the carousel wish list a structured home in `TASTE.md`

**Why it matters.** The nightly carousel depends on a wish list that currently
exists only as prose. Picking tonight's song means re-reading 542 lines to find
what is still open and what has already been used.

**Evidence.**
- `TASTE.md` is 542 lines of dated "Vibe / Why" entries, plus a
  `## Song picks so far` list at the top.
- The wish list is quoted inside the prose ("The wish list said …") rather than
  kept as a section with status.
- Commit `a68323e` ("Notes: log the obsolescence run in TASTE.md and reopen the
  wish list") shows the list is actively reopened and closed by hand.

**Proposed scope.** Add one `## Wish list` section with dated, one-line entries
and an explicit status (`open`, `picked <carousel>`, `dropped <why>`). Leave the
existing prose and history untouched; link each pick back to its wish entry
where one exists.

**Acceptance criteria.**
- Every song pick references either a wish entry or states that it is
  off-list, and no open entry is duplicated.
- A reader can list open wishes with a single `grep`/`rg` command documented at
  the top of the section.
- No historical entry is deleted or rewritten.

## Order and guardrails

Suggested order: 1, 3, 4, 2, 5 — the check and the perf work are small and
user-visible; the generator is the largest structural change and benefits from
having the check in place first; the taste-file edit is independent and can
happen any night.

Guardrails for every candidate:

- Stay static. No build server, no framework, no client-side dependency unless a
  concrete piece needs one.
- Keep relative paths. The site is served from a subpath; a leading `/` breaks it.
- Do not change published URLs; `media/<slug>` and the carousel-folder-as-piece
  convention are stable.
- Do not touch `main` directly with bulk rewrites; each candidate lands as its
  own reviewed change with measured evidence.
- Nothing here authorizes deleting or re-encoding existing art. Weight work is
  additive unless a change is reviewed file by file.
