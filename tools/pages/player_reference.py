"""Render the complete guide's reference directly from current creature data."""
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
    names, roles = {}, {}
    for heading, body in re.findall(r"### ([^\n]+)\n(.*?)(?=\n###? |\Z)", notes, re.S):
        key = re.search(r"`([^`]+)`", heading).group(1)
        names[key] = heading.split(" (`")[0]
        roles[key] = " ".join(body.split("**Combat role:**", 1)[1].split())
    assert set(names) == set(forms) == set(outcomes), "Reference must cover every live form"
    esc = html.escape
    link = lambda key: f'<a href="#creature-{key}">{esc(names[key])}</a>'
    rows = []
    for pack in packs:
        contents = ", ".join(link(k) + (f' ×{pack["forms"].count(k)}' if pack["forms"].count(k) > 1 else "") for k in dict.fromkeys(pack["forms"]))
        rows.append(f'<tr><th scope="row">{esc(pack["name"])}</th><td>{contents}</td><td>{pack["bonus_gold"]}</td><td>{3 + pack["bonus_gold"]}</td></tr>')
    packs_html = '<div class="manual-table" tabindex="0" role="region" aria-label="Starting packs"><table><thead><tr><th>Pack</th><th>Creatures</th><th>Bonus gold</th><th>First-shop gold</th></tr></thead><tbody>' + "".join(rows) + '</tbody></table></div>'
    stages_html = '<ol class="manual-stages">' + "".join('<li>' + ", ".join(link(k) for k in group) + '</li>' for group in stages) + '</ol>'
    labels = {
        "harvest": "Gold at combat start (before stars)", "cd": "Ability cooldown (s)",
        "cd_start": "Initial ability delay (s)", "radius": "Effect / search radius (cells)",
        "duration": "Effect duration (s)", "splash_radius": "Basic-shot splash radius (cells)",
        "burn_duration": "Burn duration (s)", "burn_dps": "Base burn damage per second",
        "fireball_speed": "Fireball speed (cells/s)", "channel_duration": "Channel time (s)",
        "chill_slow": "Movement / attack speed reduction (fraction)", "chill_duration": "Chill duration (s)",
        "storm_dps": "Base blizzard damage per second", "knock": "Charge knockback (cells)",
        "chain_targets": "Bolt targets at 0 / 1 / 2 / 3 stars", "chain_falloff": "Damage lost per chain hop (fraction)",
        "chain_radius": "Chain search radius (cells)", "fear_radius": "Allied-entry fear radius (cells)",
        "fear_duration": "Allied-entry fear duration (s)",
    }
    powers = {
        "berserker": "Maximum basic-attack interval reduction (fraction)", "pyromancer": "Base fireball damage",
        "cleric": "Health restored per heal", "bard": "Basic attack speed bonus (fraction)",
        "turtle": "Extra shell armour (percentage points)", "rhino": "Charge damage multiplier",
        "wolf": "Attack speed bonus near an ally (fraction)", "snake": "Poison damage per second",
        "skunk": "Armour removed (percentage points)", "eagle": "Dive damage", "hedgehog": "Retaliation damage",
        "deer": "Regeneration health per second", "peacock": "Basic-attack interval multiplier",
    }
    cards = []
    for key, data in forms.items():
        image = ROOT / f"docs/design/character_pngs/64/characters/{key}.png"
        uri = "data:image/png;base64," + base64.b64encode(image.read_bytes()).decode()
        stats = [("Base health", data["hp"]), ("Basic attack damage", data["dmg"]),
                 ("Basic attack interval (s)", data["interval"]), ("Attack range (cells)", data["range"]),
                 ("Movement speed (cells/s)", data["speed"]), ("Armour (%)", data["armour"])]
        if data["family"] == "fantasy":
            stats.append(("Purchase price (gold)", data["price"]))
        for field, value in data.items():
            label = powers.get(key) if field == "power" else labels.get(field)
            if label:
                stats.append((label, " / ".join(map(str, value)) if isinstance(value, list) else value))
        definitions = "".join(f'<div><dt>{esc(label)}</dt><dd>{esc(str(value))}</dd></div>' for label, value in stats)
        route = "; ".join(f'{link(dest)} {chance}%' for dest, chance in zip(outcomes[key], [55, 30, 15]))
        cards.append(f'<article class="panel text-panel manual-creature" id="creature-{key}"><header><img src="{uri}" alt="{esc(names[key])}" width="64" height="64"><h4>{esc(names[key])}</h4></header><p>{esc(roles[key])}</p><dl class="manual-stats">{definitions}</dl><p><strong>Transforms into:</strong> {route}.</p></article>')
    return {"@@PACKS@@": packs_html, "@@STAGES@@": stages_html, "@@CREATURES@@": "\n".join(cards)}
