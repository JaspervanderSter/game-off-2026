"""Build a standalone illustrated HTML guide from the character pack's Markdown."""

from pathlib import Path
import base64
import html
import re

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
<title>Shapeshifters Duel — Character Guide</title>
<style>
*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:24px}
body{margin:0;color:#e0dfec;font:16px/1.65 'Segoe UI',Arial,sans-serif;
background:radial-gradient(ellipse at 15% 0%,#46306566,transparent 42%),
radial-gradient(ellipse at 90% 28%,#203c5666,transparent 46%),#11121d}
body:before{content:'';position:fixed;inset:0;z-index:-1;pointer-events:none;
background:repeating-conic-gradient(#ffffff02 0% 25%,transparent 0% 50%) 0 0/120px 120px}
nav{max-width:1180px;margin:auto;padding:24px 32px;display:flex;align-items:center;
gap:24px;border-bottom:1px solid #aa8ad52e;font-size:14px}
nav a{color:#b9b6d0;text-decoration:none}nav a:hover{color:#f3d690}
nav .brand{margin-right:auto;color:#f3d690;font-family:Georgia,serif;font-size:20px}
a:focus-visible{outline:2px solid #e5c783;outline-offset:6px;border-radius:2px}
main{max-width:1180px;margin:auto;padding:48px 32px 80px;display:grid;
grid-template-columns:repeat(2,minmax(0,1fr));gap:22px}
h1,h2,main>p{grid-column:1/-1}h1{margin:8px 0 0;font:normal 58px/1.15 Georgia,serif;
letter-spacing:-1.5px;color:#f8edd3;text-shadow:0 3px 24px #b590e52a}
main>p{max-width:790px;margin:0 0 16px;color:#b9b7ce;font-size:18px}
h2{display:flex;align-items:center;gap:18px;margin:30px 0 2px;font:normal 30px/1.2 Georgia,serif;
color:#e7cd94}h2:after{content:'';height:1px;flex:1;background:linear-gradient(90deg,#b8995f66,transparent)}
article{display:grid;grid-template-columns:110px minmax(0,1fr);column-gap:22px;
align-content:start;position:relative;padding:26px;border:1px solid #77709455;
border-radius:14px;background:linear-gradient(135deg,#292537ed,#1c2030f5);
box-shadow:0 10px 26px #00000029,inset 0 1px #ffffff06;break-inside:avoid;
transition:border-color .2s,box-shadow .2s}
article:hover{border-color:#b59bdb99;box-shadow:0 10px 30px #0000003d,inset 0 1px #ffffff0c}
article img{grid-row:1/span 3;width:110px;height:130px;object-fit:contain;padding:8px;
border-radius:12px;border:1px solid #b99bdd44;
background:radial-gradient(ellipse,#71609840,transparent 72%),#141624;
filter:drop-shadow(0 4px 5px #0006)}
h3{margin:0 0 10px;color:#f5e8c9;font:normal 24px/1.2 Georgia,serif}
p{margin:0 0 12px}article p{font-size:15px;color:#c9c6d8}article p:last-child{margin-bottom:0}
strong{color:#c7afea;font-weight:600}code{font-size:.85em;overflow-wrap:anywhere}
@media(max-width:900px){main{grid-template-columns:1fr;max-width:740px}nav{max-width:740px}
article{grid-template-columns:130px minmax(0,1fr)}article img{width:130px;height:144px}}
@media(max-width:540px){nav{padding:20px;gap:16px;flex-wrap:wrap}nav .brand{width:100%}
main{padding:28px 20px 50px;gap:18px}h1{font-size:43px}main>p{font-size:16px}
h2{font-size:27px;margin-top:24px}article{padding:22px;grid-template-columns:80px minmax(0,1fr);column-gap:18px}
article img{width:80px;height:96px;grid-row:1/span 2}h3{font-size:23px}article p:last-child{grid-column:1/-1}}
@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}article{transition:none}}
@media print{body{background:white;color:#222}body:before,nav{display:none}
main{display:block;padding:0}h1,h2,h3,strong{color:#222}main>p,article p{color:#333}
article{background:white;border:1px solid #ccc;box-shadow:none;margin:16px 0}
article img{filter:none;print-color-adjust:exact}}
</style></head><body><nav aria-label="Guide navigation">
<a class="brand" href="../../index.html">Shapeshifters Duel</a>
<a href="#fantasy-fighters">Fantasy fighters</a><a href="#animal-forms">Animal forms</a>
</nav><main>""" + "\n".join(parts) + "</main></body></html>"
    target = PACK / "Character Guide.html"
    target.write_text(page, encoding="utf-8")
    print(f"Built {target}: {len(ids)} illustrated character descriptions")


if __name__ == "__main__":
    build()
