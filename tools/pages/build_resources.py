"""Build the complete player guide, audio page and adapted Tuning Fork tutorial."""
from pathlib import Path
import base64
import re

from page_theme import refresh_homepage, stylesheet
from itch_card import ITCH, render_itch_card
from player_reference import render_reference

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DOCS = ROOT / "docs"


def write_page(filename, title, body, body_class="document-page"):
    body = body.replace("@@ITCH_CARD@@", render_itch_card())
    page = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Shapeshifter Duel - {title}</title>
{stylesheet("assets/site.css")}
</head><body class="{body_class}">
<nav class="site-nav" aria-label="Site navigation">
<a class="brand" href="index.html">Shapeshifter Duel</a>
<a href="how-to-play.html">Game rules</a><a href="audio.html">Sound &amp; music</a>
<a class="itch-link" href="{ITCH}">Play on itch.io</a>
</nav><main>{body}</main></body></html>'''
    (DOCS / filename).write_text(page, encoding="utf-8")
    print(f"Built {filename}")


def build():
    board = (HERE / "assets/artist_brief/preparation.png").read_bytes()
    board_uri = "data:image/png;base64," + base64.b64encode(board).decode()
    guide = (HERE / "content/how-to-play.html").read_text(encoding="utf-8")
    guide = guide.replace("@@BOARD@@", board_uri)
    for marker, content in render_reference().items():
        guide = guide.replace(marker, content)
    write_page("how-to-play.html", "Game rules", guide, "document-page manual-page")
    audio = (HERE / "content/audio.html").read_text(encoding="utf-8")
    write_page("audio.html", "Sound & music", audio)

    # Reuse the tutorial shipped with Tuning Fork; only adapt its website framing
    # and the event-selection step for contributors replacing existing sounds.
    source = (ROOT / "tools/tuning_fork/guide/Getting started.html").read_text(encoding="utf-8")
    symbols = re.search(r'<svg width="0".*?</svg>', source, re.S).group(0)
    body = re.search(r'<main>(.*?)</main>', source, re.S).group(1)
    body = body.replace('<ol>', '<ol class="tutorial-steps">')
    body = body.replace('<h2>Create an event</h2>', '<h2>Choose a sound</h2>')
    body = body.replace('Click <svg class="icon"><use href="#plus"/></svg> beside the filter, give it a',
                        'Choose an existing event to change a current sound. To add a new one, click <svg class="icon"><use href="#plus"/></svg> beside the filter, give it a')
    body = body.replace('Then tell your programmer its path: the\n\t\t\tgame plays it with <code>Sfx.play("combat/hit")</code>.',
                        'Tell me when a new event should play so I can connect it to the game.')
    body = body.replace('the game picks a different one each time, so a repeated sound never sounds\n\t\t\tthe same.',
                        'the game can vary repeated sounds by picking between the takes.')
    intro = f'<p class="callout">Download the Windows game and Tuning Fork from <a href="{ITCH}#download">itch.io</a>, then extract both archives. This guide also works with the Godot project.</p>'
    body = body.replace('<ol class="tutorial-steps">', intro + '\n<ol class="tutorial-steps">')
    body += '<p class="related-links"><a href="audio.html">Back to sound &amp; music</a></p>'
    write_page("tuning-fork.html", "Tuning Fork getting started", symbols + body, "document-page tuning-guide")
    refresh_homepage()


if __name__ == "__main__":
    build()
