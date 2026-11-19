# GitHub Pages authoring

Published pages live under `docs/`. This directory holds their Python builders
and the source captures used by the artist brief. Commit these sources together
with any regenerated HTML. No hosting or deployment change is needed.

## Shared visual theme

`docs/assets/site.css` defines the colours, typography, panels and responsive
layouts for the homepage, artist brief and character guide. Page-specific layout
rules use the `home-page`, `brief-page` and `guide-page` body classes.

All pages load this stylesheet. The two builders also embed a fallback copy via
`page_theme.py`, preserving standalone sharing of the generated HTML. Rebuild
both documents after editing the shared CSS so their offline copies stay current.

## Build the artist brief

From the repository root, with Python, Pillow and Windows' Segoe UI font:

```powershell
python -m pip install Pillow
python tools/pages/build_artist_brief.py
```

This rebuilds `docs/design/Artist Brief.html` and the labelled `roster.png`.
`assets/artist_brief/` contains the original token atlas, preparation screenshot,
four gameplay recordings and their opening-frame posters. Keep these inputs:
they cannot all be regenerated from the character PNG exporter. The HTML embeds
its media and remains usable offline. `docs/design/Artist Brief.md` is the
companion design note; its text and the HTML template are maintained separately.

## Build the character guide

First regenerate the ignored reference PNGs with Godot and a rendering device:

```powershell
& $Godot --path prototypes/prototype_02 --minimized --script res://tools/export_character_pngs.gd
python tools/pages/build_character_guide.py
```

Set `$Godot` to your Godot executable. Do not use `--headless` for PNG export.
The exporter stays inside the Godot project because it loads the game's drawing
code and data through `res://`. It produces 144 reference PNGs under
`docs/design/character_pngs/64/` and `512/`; these are generated files, not new
artwork to version. The builder reads `Character Guide.md` in that directory and
embeds the 24 large character illustrations in `Character Guide.html`.

See `docs/design/character_pngs/README.md` for reference sizes and ZIP packaging.
The resources homepage, `docs/index.html`, is maintained directly.
