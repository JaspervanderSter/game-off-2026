# Character PNG reference pack

All 24 current Shapeshifters Duel forms, rendered directly from the prototype's
procedural artwork. Each PNG has a transparent background and a centred pivot.
Filenames use the game's form IDs (`guardian`, `rabbit`, `rhino`, etc.).

See [Character Guide](Character%20Guide.md) for a short description of each form,
its current appearance and its distinctive gameplay role. Open `Character Guide.html`
for the illustrated version in a browser.

## Folders

- `64/characters/`: characters alone at the preparation board's resting scale.
- `64/tokens_blue/` and `64/tokens_red/`: the same characters with their team base.
- `512/`: the same three variants rendered at eight times the reference scale,
  directly from the drawing code rather than enlarging a small bitmap.

There are 144 PNGs: 24 forms × 3 variants × 2 sizes.

## Size and placement

The 64 × 64 canvas includes transparent padding. It is an export frame, not the
character's visible width. At the game's reference resolution of 1280 × 720:

- Board cells are 72 × 72 pixels.
- The resting team base radius is 23.04 pixels (46.08-pixel diameter).
- Character drawing scale is 21.1968 pixels (base radius × 0.92); actual silhouettes vary.
- The pivot is at (32, 32) in the 64-pixel files, or (256, 256) in the 512-pixel files.

Keep the same frame and pivot when comparing designs. The 512-pixel files are
enlarged working references, not a required final delivery specification.
Combat can change character scale, position and rotation through animation and
gameplay effects. This pack shows static preparation poses, without effects,
shadows, health bars, stars or hover highlights.

## Regenerate

From the repository root, using Godot 4.7 with a rendering device:

```powershell
& $Godot --path prototypes/prototype_02 --minimized --script res://tools/export_character_pngs.gd
Compress-Archive -Path docs/design/character_pngs/* -DestinationPath docs/design/Character-PNGs.zip -Force
```

Do not pass `--headless`: PNG export reads rendered viewport textures.
The exporter reads `CreatureDB`, `Rules` and `Icons` directly.

The `64/` and `512/` folders and ZIP archives are generated and ignored by Git.
Keep this README, `Character Guide.md`, and the published HTML under version
control. Rebuild the illustrated guide with:

```powershell
python tools/pages/build_character_guide.py
```

See [Pages authoring](../../../tools/pages/README.md) for the source layout and
the artist brief build instructions.
