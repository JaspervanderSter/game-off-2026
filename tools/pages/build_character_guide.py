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
            parts.append(f"<h2>{inline(text[3:])}</h2>")
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
*{box-sizing:border-box}body{margin:0;background:#e8e3da;color:#242538;
font:17px/1.6 'Segoe UI',Arial,sans-serif}main{max-width:960px;margin:auto;
padding:40px;background:#f6f2e9}h1{font-size:36px;line-height:1.2}h2{clear:both;
margin-top:40px;border-bottom:2px solid #d6cbdc;padding-bottom:8px}h3{margin:0 0 12px;
font-size:21px}article{display:flow-root;margin:20px 0;padding:22px;background:white;
border:1px solid #ded8ce;border-radius:12px;break-inside:avoid}article img{float:left;
width:144px;height:144px;object-fit:contain;background:#252638;border-radius:8px;
margin:0 24px 12px 0}p{margin:0 0 14px}article p:last-child{margin-bottom:0}
code{font-size:.85em;overflow-wrap:anywhere;color:#6650a4}
@media(max-width:600px){main{padding:22px}article img{float:none;display:block;
margin:0 0 16px}h1{font-size:29px}}@media print{body,main{background:white}
main{padding:0}article{border-color:#ccc}article img{print-color-adjust:exact}}
</style></head><body><main>""" + "\n".join(parts) + "</main></body></html>"
    target = PACK / "Character Guide.html"
    target.write_text(page, encoding="utf-8")
    print(f"Built {target}: {len(ids)} illustrated character descriptions")


if __name__ == "__main__":
    build()
