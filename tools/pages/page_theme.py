"""Shared stylesheet with an embedded fallback for standalone HTML documents."""
from pathlib import Path

STYLESHEET = Path(__file__).resolve().parents[2] / "docs/assets/site.css"


def stylesheet(relative_url):
    css = STYLESHEET.read_text(encoding="utf-8")
    return f'<style data-shared-theme="fallback">\n{css}\n</style>\n<link rel="stylesheet" href="{relative_url}">'
