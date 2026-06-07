# Cass Studio Gallery

Small TIC-80 fantasy-console carts, deployed as a static GitHub Pages site.

## What's in here

- `index.html` — the gallery landing page
- `about.html` — about the project
- `carts/<slug>/` — one folder per cart, each with its own `index.html` and assets
- `assets/style.css` — shared synthwave-leaning dark theme

## Adding a new cart

1. Build the cart in `/opt/tic80/` (see the `tic80-headless` skill for the recipe)
2. Capture a preview gif and still into `/opt/tic80/out/`
3. Create `carts/<slug>/` and copy the assets
4. Write `carts/<slug>/index.html` (use the existing one as a template)
5. Add a card to `index.html` at the top of the `.cart-grid`
6. Commit and push. GitHub Pages auto-deploys.

## Local preview

```sh
cd /opt/cass-gallery
python3 -m http.server 8000
# open http://localhost:8000
```

## Deployment

GitHub Pages is configured to serve from the default branch. The site is live at
`https://juang970.github.io/cass-gallery/` (or your custom domain once it's wired up).
