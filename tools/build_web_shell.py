"""Bake the game's existing artwork into its self-contained Web loading shell.

Run from any directory: python tools/build_web_shell.py
No generated artwork, network resources, or separate asset-copy step is needed.
"""
import base64
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / 'prototypes/prototype_02'
WEB = GAME / 'web'
ASSETS = {
    'godot': WEB / 'godot-mark.png',
    'Rabbit': GAME / 'sprites/animals/Rabbit-B.png',
    'Turtle': GAME / 'sprites/animals/Turtle-B.png',
    'Deer': GAME / 'sprites/animals/Deer-B.png',
    'Wolf': GAME / 'sprites/animals/Wolf-B.png',
    'Guardian': GAME / 'sprites/humans/Guardian-B.png',
    'Pyromancer': GAME / 'sprites/humans/Pyromancer-B.png',
    'Eagle': GAME / 'sprites/animals/Eagle-B.png',
    **{name: GAME / f'tiles/school/{name}.png' for name in (
        'light-slab-1', 'dark-slab-1', 'light-slab-2', 'dark-slab-2')},
}


def build():
    assets = {name: 'data:image/png;base64,' + base64.b64encode(path.read_bytes()).decode('ascii')
              for name, path in ASSETS.items()}
    template = (WEB / 'loading.template.html').read_text(encoding='utf-8')
    assert template.count('__LOADING_ASSETS__') == 1
    result = template.replace('__LOADING_ASSETS__', json.dumps(assets, separators=(',', ':')))
    (WEB / 'loading.html').write_text(result, encoding='utf-8', newline='\n')
    print(f'Built {WEB / "loading.html"} ({len(result.encode("utf-8")):,} bytes)')


if __name__ == '__main__':
    build()
