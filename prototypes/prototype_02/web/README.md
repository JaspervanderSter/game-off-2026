# Web loading shell

The **Web** export preset selects `res://web/loading.html` as its custom HTML
shell. `loading.template.html` is the editable source; the committed generated
file embeds every image so a normal Godot export works without a builder or an
asset-copy step. Rebuild after editing the template or its artwork:

```powershell
python tools/build_web_shell.py
```

Run this command from the repository root. Commit both the template and the
rebuilt HTML. The builder uses Python's standard library only. Godot replaces
its own `$GODOT_*` placeholders during export. The Web Benchmark preset retains
Godot's standard shell so its measurements do not include this presentation.

## Artwork and behavior

- `godot-mark.png` is the unchanged Godot face cropped out of the engine's
  default exported splash image, with its transparent background preserved.
- Creature tokens are the existing blue-team PNGs in `sprites/animals/` and
  `sprites/humans/`; the rabbit periodically becomes the turtle.
- Background tiles are the existing school slabs in `tiles/school/`. The
  palette, token halos and transformation puffs reproduce the selected loading
  concept. No AI-generated images or additional libraries are used.

The loader paints before the engine JavaScript is downloaded. `onProgress`
drives the ring with downloaded bytes divided by total bytes. A zero total
means unknown size; completion of the download still leaves engine startup to
finish. Those phases show an orbit rather than a percentage. Only successful
`startGame()` completion dismisses the loader. Browser capability and download
errors remain visible on the loading screen.

The composition fits portrait and landscape windows. Background tiles are
cached at resize, animation is limited to 30 FPS, and device pixel ratio is
capped at two. Hidden tabs skip drawing, reduced-motion users get a still
composition, and the animation is cancelled when the loader leaves. The game
still waits for its own first click before playing the title animation/jingle.
Normal presentation uses icons only; errors and screen-reader descriptions
provide text when needed.

## Browser verification

Export **Web** into a temporary directory outside `export/`, then run from the
game project directory (Node 22+, local Edge or Chrome):

```powershell
node tests/web_loading.mjs --dir=C:/path/to/temporary-web-export
```

Pass `--browser=C:/path/to/chrome.exe` to select another browser. The test uses an
isolated headless browser and local HTTP server, checks real exported HTML with
controlled download/startup/failure cases, takes desktop and phone-size
screenshots, and finally starts the real exported game. Its profile and
screenshots stay beside the temporary export. It does not run the balance suite.
