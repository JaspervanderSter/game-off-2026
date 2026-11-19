"""Shared stylesheet with an embedded fallback for standalone HTML documents."""
from pathlib import Path
import hashlib
import re
from urllib.parse import unquote

STYLESHEET = Path(__file__).resolve().parents[2] / "docs/assets/site.css"


def stylesheet(relative_url):
    css = STYLESHEET.read_text(encoding="utf-8")
    version = hashlib.sha256(STYLESHEET.read_bytes()).hexdigest()[:12]
    return f'<style data-shared-theme="fallback">\n{css}\n</style>\n<link rel="stylesheet" href="{relative_url}?v={version}">'


def refresh_homepage():
    """Invalidate cached CSS and documents when opening them from the homepage."""
    docs = STYLESHEET.parent.parent
    homepage = docs / "index.html"
    page = homepage.read_text(encoding="utf-8")
    for url in ("assets/site.css", "design/Artist%20Brief.html",
                "design/character_pngs/Character%20Guide.html"):
        target = docs / unquote(url)
        version = hashlib.sha256(target.read_bytes()).hexdigest()[:12]
        page = re.sub(r'href="' + re.escape(url) + r'(?:\?v=[a-f0-9]+)?"',
                      f'href="{url}?v={version}"', page)
    homepage.write_text(page, encoding="utf-8")


if __name__ == "__main__":
    refresh_homepage()
