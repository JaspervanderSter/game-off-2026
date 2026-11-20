# GitHub Pages authoring

Published pages live under `docs/`. This directory holds their Python builders
and the source captures used by the artist brief. Commit these sources together
with any regenerated HTML. No hosting or deployment change is needed.

Use **Shapeshifter Duel** (singular) as the displayed game title, matching the
itch.io listing and cover. Existing executable and archive filenames retain
their canonical names.

## Shared visual theme

`docs/assets/site.css` defines the colours, typography, panels and responsive
layouts for the homepage, artist brief and character guide. Page-specific layout
rules use the `home-page`, `brief-page` and `guide-page` body classes.
Player and audio pages use `document-page`, with `tuning-guide` for the tutorial.

All pages load this stylesheet. The two builders also embed a fallback copy via
`page_theme.py`, preserving standalone sharing of the generated HTML. Rebuild
both documents after editing the shared CSS so their offline copies stay current.
Also run the resource builder below when the theme changes.
Stylesheet URLs and homepage links include a content-based version to avoid
reusing stale cached pages. Both builders refresh these links automatically.
After a manual homepage edit, run `python tools/pages/page_theme.py` to refresh
them without rebuilding the documents.

## Build the artist brief

From the repository root, with Python, Pillow and Windows' Segoe UI font:

```powershell
python -m pip install Pillow
python tools/pages/build_artist_brief.py
```

This rebuilds `docs/design/Artist Brief.html` and the labelled `roster.png`.
`assets/artist_brief/` contains the original token atlas, preparation screenshot,
four gameplay recordings and their opening-frame posters. Keep these inputs:
they cannot all be regenerated from the character PNG exporter. The HTML links to
separate, versioned media under `docs/assets/artist-brief/`. The complete text
loads first; images and video posters are requested after its first paint, and
videos use `preload="none"` so they download only when played. Keep the HTML and
the `docs/assets/` directory together for offline sharing; the HTML alone no
longer contains its media. `docs/design/Artist Brief.md` is the
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

## Build the player and audio pages

The complete guide is the single rules document, with section shortcuts. Its
teaching order remains under exploration; progression hypotheses stay in
`docs/reflections/`. `player_reference.py` reads live creature data and character
names to embed packs, compact base statistics and transformation outcomes, with
short role summaries maintained in that builder.
The guide's screenshot and 24 small creature illustrations are embedded for
standalone reading. There is no duplicate game card in its body.

```powershell
python tools/pages/build_resources.py
```

This generates `docs/how-to-play.html`, `docs/audio.html` and
`docs/tuning-fork.html`. The first two read the English HTML fragments under
`content/`; the complete guide embeds the preparation screenshot. The tutorial
reuses `tools/tuning_fork/guide/Getting started.html`, adapting the website framing
and the event-selection step for collaborators working on existing sounds.
Keep the original tutorial as the source for the five-step workflow.

All three pages use `page_theme.py`, embed the shared theme for standalone use,
and refresh the homepage's versioned local links. The game's itch.io page is the
public entry point for both Windows downloads; do not hardcode temporary CDN
download URLs. Verify all six website pages and the local cross-links after changes.

The homepage and audio page use `itch_card.py` for their itch game
card. The official cover is saved as `assets/itch-cover.jpg` from the game's
itch.io page and embedded in the HTML. The homepage's marked card block is
refreshed automatically. The card links directly to itch.io and stays readable
without a third-party iframe, which was rate-limited during verification.
Update the source cover if the itch listing changes. Card and button styles
belong in the shared CSS.
