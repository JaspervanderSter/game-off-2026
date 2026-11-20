"""Capture current game visuals, encode website clips and rebuild the pages."""
import argparse
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PROJECT = ROOT / "prototypes/prototype_02"
ASSETS = HERE / "assets/artist_brief"
NAMES = ["peasant", "guardian", "berserker", "duelist", "assassin", "spearman",
         "archer", "crossbowman", "pyromancer", "frost_mage", "cleric", "bard",
         "turtle", "rhino", "gorilla", "wolf", "leopard", "rabbit", "snake",
         "skunk", "eagle", "hedgehog", "deer", "peacock"]


def run(*args, env=None):
    subprocess.run([str(arg) for arg in args], cwd=ROOT, env=env, check=True)


def encode(capture):
    shutil.copyfile(capture / "preparation.png", ASSETS / "preparation.png")
    atlas = Image.new("RGBA", (1536, 1024))
    for i, name in enumerate(NAMES):
        source = ROOT / f"docs/design/character_pngs/512/tokens_blue/{name}.png"
        with Image.open(source) as image:
            token = image.convert("RGBA").resize((256, 256), Image.Resampling.NEAREST)
            atlas.paste(token, ((i % 6) * 256, (i // 6) * 256))
    atlas.save(ASSETS / "roster_tokens.png")
    clips = {"gameplay": (0, 17), "motion": (3, 3),
             "shapeshift": (5.9, 3), "exit": (9.85, 3)}
    for name, (start, duration) in clips.items():
        output = ASSETS / f"{name}.mp4"
        filters = "fps=30" if name == "gameplay" else "crop=656:520:312:42,fps=30"
        run("ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", start,
            "-i", capture / "gameplay.avi", "-t", duration, "-vf", filters,
            "-an", "-c:v", "libx264", "-preset", "slow", "-crf", "20",
            "-pix_fmt", "yuv420p", "-movflags", "+faststart", output)
        run("ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", output,
            "-frames:v", "1", ASSETS / f"{name}_poster.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT"))
    parser.add_argument("--from-capture", type=Path,
                        help="Reuse a completed capture and existing character PNG exports")
    args = parser.parse_args()
    if not args.from_capture and not args.godot:
        parser.error("Pass --godot=<Godot 4 executable> or set GODOT")
    with tempfile.TemporaryDirectory(prefix="shapeshifter-site-media-") as work:
        work = Path(work)
        capture = args.from_capture or work
        if not args.from_capture:
            env = dict(os.environ, APPDATA=str(work), LOCALAPPDATA=str(work))
            base = [args.godot, "--path", PROJECT, "--minimized", "--audio-driver", "Dummy"]
            run(*base, "--script", "res://tools/export_character_pngs.gd", env=env)
            run(*base, "--write-movie", work / "gameplay.avi", "--fixed-fps", "60",
                "--script", "res://tools/capture_site_media.gd", "--",
                f"--output-dir={work}", "--no-sound", env=env)
        encode(capture)
        for builder in ["build_artist_brief.py", "build_character_guide.py", "build_resources.py"]:
            run(sys.executable, HERE / builder)
    print("Refreshed website screenshots, portraits, videos and posters")


if __name__ == "__main__":
    main()
