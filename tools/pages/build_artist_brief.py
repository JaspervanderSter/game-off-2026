"""Build a lightweight character brief with separately cached prototype media.

Run with Python + Pillow after capturing the media in tools/pages/assets/artist_brief/.
For offline sharing, keep the HTML and docs/assets directories together.
"""
from pathlib import Path
import hashlib
import io
from PIL import Image, ImageDraw, ImageFont
from page_theme import refresh_homepage, stylesheet

ROOT = Path(__file__).resolve().parents[2]
ASSETS = Path(__file__).resolve().parent / "assets/artist_brief"
PUBLISHED = ROOT / "docs/assets/artist-brief"
PUBLISHED.mkdir(parents=True, exist_ok=True)

NAMES = ["Pitchfork Peasant", "Shield Guardian", "Berserker", "Duelist", "Assassin", "Spearman",
         "Archer", "Crossbowman", "Pyromancer", "Frost Mage", "Cleric", "Bard",
         "Turtle", "Rhinoceros", "Gorilla", "Wolf", "Leopard", "Rabbit",
         "Snake", "Skunk", "Eagle", "Porcupine", "Deer", "Peacock"]

def publish(name, data):
    (PUBLISHED / name).write_bytes(data)
    version = hashlib.sha256(data).hexdigest()[:12]
    return f"../assets/artist-brief/{name}?v={version}"

def media_url(name):
    return publish(name, (ASSETS / name).read_bytes())

def token_url(i):
    buf = io.BytesIO()
    tokens[i].save(buf, format="PNG")
    return publish(f"token-{i:02d}.png", buf.getvalue())

def image(url, alt, width, height):
    # No media request until the complete text has been parsed and painted.
    attrs = f'alt="{alt}" width="{width}" height="{height}" decoding="async"'
    return (f'<img data-src="{url}" {attrs}>'
            f'<noscript><img src="{url}" {attrs}></noscript>')

atlas = Image.open(ASSETS / "roster_tokens.png").convert("RGBA")
tokens = [atlas.crop(((i % 6) * 256, (i // 6) * 256, (i % 6 + 1) * 256, (i // 6 + 1) * 256)) for i in range(24)]
font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 24)
sheet = Image.new("RGB", (1536, 1264), "#181c2d")
draw = ImageDraw.Draw(sheet)
for i, (im, name) in enumerate(zip(tokens, NAMES)):
    x, y = (i % 6) * 256, (i // 6) * 316
    sheet.paste(im, (x, y), im)
    draw.text((x + 128, y + 270), name, font=font, fill="#f8f2e7", anchor="mt")
sheet.save(ASSETS / "roster.png")

def cards(start, end):
    return "".join(f'<figure class="token">{image(token_url(i), f"Current {NAMES[i]} token", 256, 256)}<figcaption>{NAMES[i]}</figcaption></figure>' for i in range(start, end))

def video(name, label, poster):
    return f'<video controls muted loop playsinline preload="none" aria-label="{label}" data-poster="{media_url(poster)}"><source src="{media_url(name)}" type="video/mp4">Your browser cannot play this video.</video>'

html = '''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Shapeshifter Duel | Character exploration brief</title>
@@THEME@@</head><body class="brief-page">
<nav class="site-nav" aria-label="Brief sections"><a class="brand" href="../index.html">Shapeshifter Duel / Artist brief</a><a href="#characters">Characters</a><a href="#motion">Motion</a><a href="#request">Your exploration</a></nav><main class="wrap">
<section class="hero" id="game"><p class="eyebrow">01 / The game</p><h1>Character Design for Shapeshifter Duel</h1>
<p class="lead">Current artwork, animation references and a first exploration</p>
<div class="meta"><span class="tag">2D heroic fantasy</span><span class="tag">Character exploration</span><span class="tag">Visuals: 22 November 2026</span></div>
<figure class="hero-shot">@@PREP_IMAGE@@<figcaption>The prototype during preparation. <a href="@@PREP@@" download="Shapeshifters-Duel-board.png">Save the screenshot for your sketches</a>.</figcaption></figure>
<div class="two"><div><h3>You are the wizard.</h3><p>Recruit a small band of fantasy fighters and place them on a board. They fight automatically; you intervene by transforming allies or enemies into a random new form. A shield-bearing guardian can become a rabbit. A new body means a new combat role.</p></div><div><h3>Playful, mischievous, a little absurd.</h3><p>We want expressive characters and surprising magical accidents, with clear tactical action underneath. The current game is a single-player duel against an AI wizard.</p><p class="meta">Super Auto Pets informs the playful atmosphere; Teamfight Tactics informs the board and automatic combat. Neither dictates the character style.</p></div></div>
</section>
<section id="characters"><p class="eyebrow">02 / What exists today</p><div class="section-head"><h2>Two families. One cast apart.</h2><div class="toolbar" role="group" aria-label="Character preview size"><button id="large" aria-pressed="true">Enlarged</button><button id="small" aria-pressed="false">Approx. gameplay size</button></div></div>
<p class="intro">The prototype has 12 fantasy fighters and 12 animal forms. These are the current default visuals: the pixel art sprites of all 24 forms.</p>
<h3>Fantasy fighters</h3><div class="roster">@@FANTASY@@</div>
<h3>Animal forms</h3><div class="roster">@@ANIMALS@@</div>
<p class="meta">Blue and red circles identify the two teams. <a href="@@ROSTER@@" download="Shapeshifters-Duel-current-characters.png">Save the character reference sheet</a>.</p>
<div class="sample"><div class="pair">@@GUARDIAN@@<span class="arrow" aria-label="can transform into">→</span>@@RABBIT@@</div><p><strong>A useful starting pair: Shield Guardian + Rabbit.</strong><br>Armoured strength versus agility: a solid guardian and a quick, unexpectedly fierce rabbit. The rabbit should look less powerful, but still ready to fight. Keep their on-board size comparable so both remain easy to read. This is one possible transformation, not a fixed pair.</p></div>
</section>
<section id="motion"><p class="eyebrow">03 / Animation</p><h2>An approach to explore together.</h2><p class="intro">For the prototype, I move, rotate and scale static drawings to keep the workload small. Dedicated character animations could be interesting too, with a different scope. These clips show the current approach.</p>
<div class="three">
<article class="motion-card">@@MOTION@@<div class="copy"><h3>01. Fight &amp; bounce</h3><p>Short lunges, hit flashes and hops on the bard's beat give combat rhythm and impact.</p></div></article>
<article class="motion-card">@@SHIFT@@<div class="copy"><h3>02. Change bodies</h3><p>Golden light marks a friendly transformation; a purple vortex marks an enemy hex. The new form should read immediately.</p></div></article>
<article class="motion-card">@@EXIT@@<div class="copy"><h3>03. Exit like a rocket</h3><p>Defeated creatures spin off the board trailing smoke: exaggerated, comic defeat.</p></div></article>
</div>
<details style="margin-top:25px"><summary>Watch the full gameplay sequence</summary>@@GAMEPLAY@@<p class="caption">Actual prototype recording, silent.</p></details>
</section>
<section class="request" id="request"><p class="eyebrow">04 / Your first exploration</p><h2>Explore an art direction.</h2><p class="lead">Suggest a visual direction for the game, then try it out through a Shield Guardian and a Rabbit.</p>
<div class="two"><div class="brief-card"><h3>What to share</h3><ol><li><strong>A few words on your art direction and animation.</strong> What would suit the game's mood, stay manageable for a jam, and be fun for you to make? Would you keep the current animation approach or add a few simple character animations? No animation to produce.</li><li><strong>A visual reference.</strong> A game screenshot, a few reference images or a small mock-up to explain your direction. Choose one format.</li><li><strong>A first take on the Guardian and the Rabbit.</strong> One pose each, readable at gameplay size. Rough sketches are welcome.</li></ol></div>
<div><p class="time">Up to 1–2 hours.</p><p>Less is welcome. Keep it light rather than polishing or expanding the scope.</p><p>If another fantasy fighter / animal combination inspires you more, suggest it before starting.</p><p><strong>Open to exploration:</strong> style, palette, proportions and expression, within a 2D heroic fantasy world. Top-down or slight perspective can be explored.</p></div></div>
<div class="terms"><p>This is a small game jam project: a chance to get to know each other and see if we enjoy working together, with no pressure to carry on afterwards.</p><p>If I'd like to use your work in the game, I'll talk it through with you first. And of course, if we decide to work together, you'll be credited on the game's itch.io page, as I've always done for my game jams.</p></div>
</section><footer><span>Shapeshifter Duel / First character exploration</span><span>Working brief · 19 November 2026 · Prototype visuals</span></footer>
</main><script>
const large=document.getElementById('large'),small=document.getElementById('small');
function setSize(compact){document.querySelectorAll('.roster').forEach(r=>r.classList.toggle('small',compact));large.setAttribute('aria-pressed',String(!compact));small.setAttribute('aria-pressed',String(compact));}
large.addEventListener('click',()=>setSize(false));small.addEventListener('click',()=>setSize(true));
// Two frames let the browser paint the complete brief before requesting images.
requestAnimationFrame(()=>requestAnimationFrame(()=>{
  document.querySelectorAll('img[data-src]').forEach(img=>{img.src=img.dataset.src;});
  document.querySelectorAll('video[data-poster]').forEach(video=>{video.poster=video.dataset.poster;});
}));
</script></body></html>'''

# Posters use the exact opening frame of each clip, so playback does not jump.
replacements = {
    "@@THEME@@": stylesheet("../assets/site.css"),
    "@@PREP@@": media_url("preparation.png"),
    "@@PREP_IMAGE@@": image(media_url("preparation.png"), "Current prototype: small creature tokens on a board, with the shop on the right", *Image.open(ASSETS / "preparation.png").size),
    "@@ROSTER@@": media_url("roster.png"),
    "@@FANTASY@@": cards(0, 12), "@@ANIMALS@@": cards(12, 24),
    "@@GUARDIAN@@": image(token_url(1), "Current Shield Guardian", 256, 256),
    "@@RABBIT@@": image(token_url(17), "Current Rabbit", 256, 256),
    "@@MOTION@@": video("motion.mp4", "Current combat movement and bard hops", "motion_poster.png"),
    "@@SHIFT@@": video("shapeshift.mp4", "Current friendly and enemy shapeshift effects", "shapeshift_poster.png"),
    "@@EXIT@@": video("exit.mp4", "Current defeated creature spinning away with smoke", "exit_poster.png"),
    "@@GAMEPLAY@@": video("gameplay.mp4", "Full gameplay context", "gameplay_poster.png").replace('<video ', '<video class="full-video" '),
}
for key, value in replacements.items():
    html = html.replace(key, value)
assert "@@" not in html
out = ROOT / "docs/design/Artist Brief.html"
out.write_text(html, encoding="utf-8")
refresh_homepage()
print(f"Built {out} ({out.stat().st_size:,} bytes)")
