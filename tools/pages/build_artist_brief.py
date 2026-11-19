"""Build a standalone character brief with embedded prototype art and videos.

Run with Python + Pillow after capturing the media in tools/pages/assets/artist_brief/.
The HTML works offline and can be shared as a single file.
"""
from pathlib import Path
import base64
import io
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
ASSETS = Path(__file__).resolve().parent / "assets/artist_brief"

NAMES = ["Pitchfork Peasant", "Shield Guardian", "Berserker", "Duelist", "Assassin", "Spearman",
         "Archer", "Crossbowman", "Pyromancer", "Frost Mage", "Cleric", "Bard",
         "Turtle", "Rhinoceros", "Gorilla", "Wolf", "Leopard", "Rabbit",
         "Snake", "Skunk", "Eagle", "Hedgehog", "Deer", "Peacock"]

def uri(path):
    path = Path(path)
    mime = "video/mp4" if path.suffix == ".mp4" else "image/png"
    return f"data:{mime};base64," + base64.b64encode(path.read_bytes()).decode()

def image_uri(im):
    buf = io.BytesIO()
    im.save(buf, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()

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
    return "".join(f'<figure class="token"><img src="{image_uri(tokens[i])}" alt="Current {NAMES[i]} token"><figcaption>{NAMES[i]}</figcaption></figure>' for i in range(start, end))

def video(name, label, poster):
    return f'<video controls muted loop playsinline preload="metadata" aria-label="{label}" poster="{uri(ASSETS / poster)}"><source src="{uri(ASSETS / name)}" type="video/mp4">Your browser cannot play this video.</video>'

html = '''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Shapeshifters Duel | Character exploration brief</title>
<style>
:root{--paper:#f6f2e9;--ink:#242538;--muted:#656575;--purple:#6650a4;--line:#ded8ce;--night:#181c2d;--gold:#f0cd76}
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:#e8e3da;color:var(--ink);font:17px/1.6 'Segoe UI',Arial,sans-serif}a{color:var(--purple)}
.wrap{max-width:1120px;margin:auto;background:var(--paper);box-shadow:0 0 75px #24253812}nav{display:flex;gap:25px;align-items:center;padding:18px 48px;border-bottom:1px solid var(--line);font-size:13px}nav strong{margin-right:auto}nav a{text-decoration:none}
section{padding:52px 64px;border-top:1px solid var(--line)}.hero{border:0;padding-top:48px}.eyebrow{color:var(--purple);font-size:12px;font-weight:700;letter-spacing:2px;text-transform:uppercase;margin:0 0 12px}h1{font-size:60px;line-height:1.03;letter-spacing:-2.3px;margin:0 0 24px;max-width:720px}h2{font-size:34px;line-height:1.16;letter-spacing:-.8px;margin:0 0 18px}h3{font-size:20px;line-height:1.3;margin:0 0 12px}p{margin:0 0 17px}.lead{font-size:22px;line-height:1.5;max-width:800px}.intro{max-width:780px}.meta{font-size:13px;color:var(--muted)}.tag{display:inline-block;border:1px solid #c4b7d9;border-radius:20px;padding:4px 12px;font-size:12px;margin-right:6px}
figure{margin:0}img{max-width:100%;height:auto;display:block}figcaption,.caption{font-size:13px;color:var(--muted);line-height:1.5;margin-top:10px}.hero-shot{margin:30px -20px 16px}.hero-shot img{border-radius:10px;border:1px solid #cbc2b5}.two{display:grid;grid-template-columns:1fr 1fr;gap:32px}.three{display:grid;grid-template-columns:repeat(3,1fr);gap:20px}.note{padding:17px 20px;border-left:3px solid var(--purple);background:#ece6f3;font-size:15px;margin-top:24px}.section-head{display:flex;justify-content:space-between;align-items:center;gap:18px}.roster{display:grid;grid-template-columns:repeat(6,1fr);gap:22px 10px;padding:26px 20px;border-radius:12px;background:var(--night);margin:18px 0 28px}.token{text-align:center}.token img{width:112px;height:112px;object-fit:contain;margin:auto;transition:width .18s,height .18s}.token figcaption{color:#e5e2ec;font-size:12px;min-height:36px;padding:0 3px}.roster.small .token img{width:52px;height:52px}.toolbar{display:flex;gap:7px}button{font:600 12px 'Segoe UI',sans-serif;background:transparent;color:var(--purple);border:1px solid #c2b7d4;border-radius:20px;padding:7px 13px;cursor:pointer}button[aria-pressed=true]{background:var(--purple);color:white;border-color:var(--purple)}button:focus-visible,a:focus-visible{outline:3px solid #e0ac39;outline-offset:4px}
.sample{background:#eae4f2;border-radius:12px;padding:25px;display:flex;align-items:center;gap:24px;margin:25px 0}.pair{display:flex;align-items:center;gap:16px;flex-shrink:0}.pair img{width:100px}.arrow{color:var(--purple);font-size:30px}.sample p{margin:0;font-size:15px}.motion-card{background:white;border:1px solid var(--line);border-radius:12px;overflow:hidden}.motion-card video{display:block;width:100%;aspect-ratio:592/448;object-fit:contain;background:var(--night)}.motion-card .copy{padding:20px}.motion-card p{font-size:15px}.motion-card h3{font-size:18px}.motion-card .caption{font-size:12px}.full-video{width:100%;display:block;border-radius:10px;background:var(--night);margin-top:18px;aspect-ratio:16/9}
.request{background:#fffdf8}.request .eyebrow{color:#8a6523}.brief-card{padding:26px;border:1px solid var(--line);border-radius:12px;background:#f6f2e9}.brief-card ol{padding-left:20px;margin:0}.brief-card li{margin:0 0 15px}.brief-card li:last-child{margin:0}.checks{padding-left:20px;font-size:16px}.checks li{margin-bottom:10px}.time{font-size:26px;color:var(--purple);font-weight:700;margin:0 0 12px}.terms{font-size:14px;color:var(--muted);padding-top:25px;border-top:1px solid var(--line);margin-top:30px}footer{font-size:12px;color:var(--muted);padding:20px 64px;border-top:1px solid var(--line);display:flex;justify-content:space-between}
@media(max-width:760px){nav{padding:15px 22px;gap:12px;flex-wrap:wrap}nav strong{width:100%}section{padding:34px 24px}h1{font-size:44px}h2{font-size:28px}.lead{font-size:19px}.hero-shot{margin:22px 0}.two,.three{grid-template-columns:1fr}.roster{grid-template-columns:repeat(3,1fr);padding:20px 10px}.token img{width:90px;height:90px}.section-head{display:block}.toolbar{margin-bottom:18px}.sample{display:block}.pair{justify-content:center;margin-bottom:18px}footer{padding:20px 24px;display:flex;flex-direction:column;gap:6px}}
@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}.token img{transition:none}}
@media print{body{background:white;font-size:11pt}.wrap{max-width:none;box-shadow:none}nav,.toolbar{display:none}section{padding:24px 0;break-inside:avoid}.roster{print-color-adjust:exact}.three{grid-template-columns:repeat(3,1fr)}video{display:none}.motion-card:before{content:'Animation available in the HTML brief';display:block;padding:15px;font-size:10pt}.hero-shot{margin:20px 0}h1{font-size:36pt}}
</style></head><body><main class="wrap">
<nav aria-label="Brief sections"><strong>SHAPESHIFTERS DUEL / ARTIST BRIEF</strong><a href="#characters">Characters</a><a href="#motion">Motion</a><a href="#request">Your exploration</a></nav>
<section class="hero" id="game"><p class="eyebrow">01 / The game</p><h1>Character Design for Shapeshifters Duel</h1>
<p class="lead">Current artwork, animation references and a first exploration</p>
<div class="meta"><span class="tag">2D heroic fantasy</span><span class="tag">Character exploration</span><span class="tag">19 November 2026</span></div>
<figure class="hero-shot"><img src="@@PREP@@" alt="Current prototype: small creature tokens on a board, with the shop on the right"><figcaption>The prototype during preparation. <a href="@@PREP@@" download="Shapeshifters-Duel-board.png">Save the screenshot for your sketches</a>.</figcaption></figure>
<div class="two"><div><h3>You are the wizard.</h3><p>Recruit a small band of fantasy fighters and place them on a board. They fight automatically; you intervene by transforming allies or enemies into a random new form. A shield-bearing guardian can become a rabbit. A new body means a new combat role.</p></div><div><h3>Playful, mischievous, a little absurd.</h3><p>We want expressive characters and surprising magical accidents, with clear tactical action underneath. The current game is a single-player duel against an AI wizard.</p><p class="meta">Super Auto Pets informs the playful atmosphere; Teamfight Tactics informs the board and automatic combat. Neither dictates the character style.</p></div></div>
</section>
<section id="characters"><p class="eyebrow">02 / What exists today</p><div class="section-head"><h2>Two families. One cast apart.</h2><div class="toolbar" role="group" aria-label="Character preview size"><button id="large" aria-pressed="true">Enlarged</button><button id="small" aria-pressed="false">Approx. gameplay size</button></div></div>
<p class="intro">The prototype has 12 fantasy fighters and 12 animal forms. These drawings establish identities and roles; the visual style is open to exploration.</p>
<h3>Fantasy fighters</h3><div class="roster">@@FANTASY@@</div>
<h3>Animal forms</h3><div class="roster">@@ANIMALS@@</div>
<p class="meta">Blue and red circles identify the two teams. <a href="@@ROSTER@@" download="Shapeshifters-Duel-current-characters.png">Save the character reference sheet</a>.</p>
<div class="sample"><div class="pair"><img src="@@GUARDIAN@@" alt="Current Shield Guardian"><span class="arrow" aria-label="can transform into">→</span><img src="@@RABBIT@@" alt="Current Rabbit"></div><p><strong>A useful starting pair: Shield Guardian + Rabbit.</strong><br>Armoured strength versus agility: a solid guardian and a quick, unexpectedly fierce rabbit. The rabbit should look less powerful, but still ready to fight. Keep their on-board size comparable so both remain easy to read. This is one possible transformation, not a fixed pair.</p></div>
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
</section><footer><span>Shapeshifters Duel / First character exploration</span><span>Working brief · 19 November 2026 · Prototype visuals</span></footer>
</main><script>
const large=document.getElementById('large'),small=document.getElementById('small');
function setSize(compact){document.querySelectorAll('.roster').forEach(r=>r.classList.toggle('small',compact));large.setAttribute('aria-pressed',String(!compact));small.setAttribute('aria-pressed',String(compact));}
large.addEventListener('click',()=>setSize(false));small.addEventListener('click',()=>setSize(true));
</script></body></html>'''

# Posters use the exact opening frame of each clip, so playback does not jump.
replacements = {
    "@@PREP@@": uri(ASSETS / "preparation.png"),
    "@@ROSTER@@": uri(ASSETS / "roster.png"),
    "@@FANTASY@@": cards(0, 12), "@@ANIMALS@@": cards(12, 24),
    "@@GUARDIAN@@": image_uri(tokens[1]), "@@RABBIT@@": image_uri(tokens[17]),
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
print(f"Built {out} ({out.stat().st_size:,} bytes)")
