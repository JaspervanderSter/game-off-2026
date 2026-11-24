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
finish. Those phases show an orbit rather than a percentage. Successful
`startGame()` completion, loaded artwork and registration of the rendered Godot
scene enable a Play medallion below the Godot mark, at the bottom of the completed
ring. The Godot mark keeps exactly the same position and size in every loading
and ready frame; only Play appears, without rearranging the composition. The ring remains until
the player clicks/taps it or presses Enter/Space on the button. Browser capability
and download errors remain visible on the loading screen.

That single trusted input resumes the engine's AudioContexts before any promise
or timer. The shell briefly observes their creation through transparent
constructor proxies, then restores the original constructors after startup.
It fades to white in 400 ms, releases the loading artwork, fades onto the sky in
400 ms, and waits one second before invoking the registered JavaScriptBridge
callback. Godot holds its title at time zero, with no in-game Play prompt or
launch input, until that callback plays the title and its jingle. The white
curtain blocks input until the handoff is complete. Repeated clicks cannot
restart the sequence. The default benchmark shell keeps its original behavior.

The composition fits portrait and landscape windows. Background tiles are
cached at resize, animation is limited to 30 FPS, and device pixel ratio is
capped at two. Hidden tabs skip drawing, reduced-motion users get a still
composition without white fades, and the animation is cancelled when the loader
leaves. Reduced motion retains the one-second pause before the title.
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
controlled download/startup/failure cases, verifies the persistent Play screen,
audio unlocking from one touch/key input and the delayed title callback, takes
desktop and phone-size screenshots, and finally starts the real exported game
with a single click. Its profile and
screenshots stay beside the temporary export. It does not run the balance suite.
