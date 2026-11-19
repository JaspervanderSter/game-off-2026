"""Reusable itch game card with its cover embedded for offline sharing."""
from pathlib import Path
import base64

ITCH = "https://spacemonkeyc.itch.io/shapeshifter-duel"
COVER = Path(__file__).resolve().parent / "assets/itch-cover.jpg"


def render_itch_card():
    image = "data:image/jpeg;base64," + base64.b64encode(COVER.read_bytes()).decode()
    return f'''<a class="itch-card" href="{ITCH}" aria-label="Play Shapeshifter Duel on itch.io">
<img src="{image}" alt="Shapeshifter Duel cover" width="630" height="500">
<span class="itch-card-copy">
<span class="itch-card-name">Shapeshifter Duel</span>
<span class="itch-card-author">by Space Monkey</span>
<span class="itch-card-description">A shapeshifting auto-battler prototype</span>
<span class="itch-card-button">Play on itch.io</span>
<span class="itch-card-brand">itch.io</span>
</span></a>'''
