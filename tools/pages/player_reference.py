"""Render compact pack, creature and transformation references from live data."""
import ast
import base64
import html
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]


def constant(source, name):
    match = re.search(r"const " + name + r" := ([\[{].*?^[\]}])", source, re.M | re.S)
    return ast.literal_eval(match.group(1))


def render_reference():
    source = (ROOT / "prototypes/prototype_02/scripts/data/creature_db.gd").read_text(encoding="utf-8")
    forms, packs, stages, outcomes = [constant(source, n) for n in ("FORMS", "PACKS", "STAGES", "OUTCOME_ORDER")]
    notes = (ROOT / "docs/design/character_pngs/Character Guide.md").read_text(encoding="utf-8")
    names = {re.search(r"`([^`]+)`", heading).group(1): heading.split(" (`")[0]
             for heading in re.findall(r"^### (.+)$", notes, re.M)}
    roles = {
        "peasant": "Economy: generates gold at combat start when fielded.",
        "guardian": "Front line: high health and armour; low damage.",
        "berserker": "Melee: attacks faster as health falls.",
        "duelist": "Melee: parries one basic attack, then recharges for 4 seconds.",
        "assassin": "Melee: initially pursues a distant enemy; no teleport or stealth.",
        "spearman": "Reach: attacks from behind the front line.",
        "archer": "Ranged: retreats from nearby melee enemies while reloading.",
        "crossbowman": "Ranged: armour-piercing bolts; chains to more targets with stars.",
        "pyromancer": "Ranged: splash shots and burns; channels a heavy fireball.",
        "frost_mage": "Ranged: chills targets; channels a 3 × 3-cell blizzard.",
        "cleric": "Healing: restores 22 health to the most wounded nearby ally every 3.5 seconds.",
        "bard": "Support: beats grant all allies +35% attack speed for 3 seconds.",
        "turtle": "Defence: +50 armour for 2 seconds; stops moving and attacking during shell.",
        "rhino": "Front line: charges for double basic damage and knocks its target back.",
        "gorilla": "Area damage: melee attacks hit enemies around the target.",
        "wolf": "Melee: +40% attack speed while another ally is within 2 cells.",
        "leopard": "Melee: hunts nearby enemies with the lowest health percentage.",
        "rabbit": "Melee: leaps behind the enemy back line; allied entry readies the leap.",
        "snake": "Poison: bites apply 7 damage/second for 4 seconds; repeated bites refresh it.",
        "skunk": "Support: spray removes 30 armour for 4 seconds; allied entry fears nearby enemies.",
        "eagle": "Melee: dives onto a distant enemy for 30 damage.",
        "porcupine": "Retaliation: deals 5 damage back after a melee hit lands.",
        "deer": "Healing: nearby allies, including itself, regenerate 5 health/second.",
        "peacock": "Support: multiplies nearby enemies’ attack interval by 1.8 for 4 seconds.",
    }
    assert set(names) == set(forms) == set(outcomes) == set(roles)
    esc = html.escape
    link = lambda key: f'<a href="#creature-{key}">{esc(names[key])}</a>'
    rows = []
    for pack in packs:
        contents = ", ".join(link(k) + (f' ×{pack["forms"].count(k)}' if pack["forms"].count(k) > 1 else "") for k in dict.fromkeys(pack["forms"]))
        rows.append(f'<tr><th scope="row">{esc(pack["name"])}</th><td>{contents}</td><td>{pack["bonus_gold"]}</td></tr>')
    packs_html = '<div class="manual-table" tabindex="0" role="region" aria-label="Starting packs"><table><thead><tr><th>Pack</th><th>Creatures</th><th>Bonus gold</th></tr></thead><tbody>' + "".join(rows) + '</tbody></table></div>'
    stages_html = '<ol class="manual-stages">' + "".join('<li>' + ", ".join(link(k) for k in group) + '</li>' for group in stages) + '</ol>'
    cards = []
    for key, data in forms.items():
        image = ROOT / f"docs/design/character_pngs/64/characters/{key}.png"
        uri = "data:image/png;base64," + base64.b64encode(image.read_bytes()).decode()
        stats = f'HP {data["hp"]} · Damage {data["dmg"]} · Interval {data["interval"]}s<br>Range {data["range"]} · Speed {data["speed"]} · Armour {data["armour"]}%'
        if data["family"] == "fantasy":
            stats += f' · {data["price"]} gold'
        route = "; ".join(f'{link(dest)} {chance}%' for dest, chance in zip(outcomes[key], [55, 30, 15]))
        cards.append(f'<article class="panel text-panel manual-creature" id="creature-{key}"><header><img src="{uri}" alt="{esc(names[key])}" width="64" height="64"><h3>{esc(names[key])}</h3></header><p>{esc(roles[key])}</p><p class="manual-base-stats">{stats}</p><p>{route}.</p></article>')
    return {"@@PACKS@@": packs_html, "@@STAGES@@": stages_html, "@@CREATURES@@": "\n".join(cards)}
