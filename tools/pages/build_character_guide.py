"""Build a standalone illustrated HTML guide from the character pack's Markdown."""

from pathlib import Path
import base64
import html
import re
from page_theme import refresh_homepage, stylesheet

PACK = Path(__file__).resolve().parents[2] / "docs/design/character_pngs"


def inline(text):
    text = html.escape(text)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    return re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)


def build():
    source = (PACK / "Character Guide.md").read_text(encoding="utf-8")
    parts = []
    ids = []
    card_open = False
    for block in re.split(r"\n\s*\n", source.strip()):
        text = " ".join(block.splitlines())
        if text.startswith("### "):
            if card_open:
                parts.append("</article>")
            form_id = re.search(r"`([^`]+)`", text).group(1)
            ids.append(form_id)
            png = (PACK / "512/characters" / f"{form_id}.png").read_bytes()
            uri = "data:image/png;base64," + base64.b64encode(png).decode()
            parts.append(f'<article><img src="{uri}" alt="{html.escape(form_id)}">')
            display_name = re.sub(r"\s*\(`[^`]+`\)", "", text[4:])
            parts.append(f"<h3>{inline(display_name)}</h3>")
            card_open = True
        elif text.startswith("## "):
            if card_open:
                parts.append("</article>")
                card_open = False
            section_id = text[3:].lower().replace(" ", "-")
            parts.append(f'<h2 id="{section_id}">{inline(text[3:])}</h2>')
        elif text.startswith("# "):
            parts.append(f"<h1>{inline(text[2:])}</h1>")
        else:
            parts.append(f"<p>{inline(text)}</p>")
    if card_open:
        parts.append("</article>")
    expected = {p.stem for p in (PACK / "512/characters").glob("*.png")}
    assert len(ids) == 24 and set(ids) == expected, "Guide must cover all 24 PNGs exactly once"
    page = """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Shapeshifter Duel — Character Guide</title>
@@THEME@@</head><body class="guide-page"><nav class="site-nav" aria-label="Guide navigation">
<a class="brand" href="../../index.html">Shapeshifter Duel</a>
<a href="#fantasy-fighters">Fantasy fighters</a><a href="#animal-forms">Animal forms</a>
</nav><main>""" + "\n".join(parts) + "</main></body></html>"
    page = page.replace("@@THEME@@", stylesheet("../../assets/site.css"))
    target = PACK / "Character Guide.html"
    target.write_text(page, encoding="utf-8")
    refresh_homepage()
    print(f"Built {target}: {len(ids)} illustrated character descriptions")


if __name__ == "__main__":
    build()
