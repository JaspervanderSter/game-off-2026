# Art Direction

## Confirmed direction

Use a **heroic fantasy** setting to make the game easier to read.

The player takes the role of a wizard or sorcerer. Shapeshifting is the central magical action and will need a readable visual expression.

## Reference intent

Super Auto Pets is primarily an atmosphere reference. Teamfight Tactics is primarily a mechanical reference. No specific art style has yet been approved on that basis.

## Unvalidated visual proposal

Fantasy characters transforming into animals inspired by Super Auto Pets could create a playful mixture of the two reference worlds. This is an individual proposal awaiting discussion, recorded in [[Ideas to Explore]]. It is not an approved art direction or a commitment to particular characters or assets.

## Current preferences from the follow-up

- A playful, slightly offbeat and chaotic wizard duel, with skill and control in the mechanics.
- A board-game framing: sorcerers playing against each other on a game board.
- **2D presentation**, potentially with slight perspective; top-down is also acceptable for now. The camera is not settled.
- Very high readability as a priority.
- Simple tween-based combat motion inspired by the described feel of Super Auto Pets: creatures lunge into one another.
- On death, a creature is flung off-screen like a rocket with a plume of smoke.
- A short sound and visual effect signal a shapeshift.

These are the current speaker's preferences, recorded for discussion rather than presented as previously agreed meeting decisions.

## Mouse cursors

**Confirmed direction (26 November 2026).** Every clickable zone tells the player what a click does through the cursor, without text. Six 32×32 pixel-art cursors, in the game's palette (brown wand, purple spell star, gold):

| Cursor | Look | Shown |
| --- | --- | --- |
| Normal | the wand at rest, its star dim | everywhere nothing reacts |
| Clickable | the wand lit, with gold sparks | buttons, map encounters, title medallion, packs, upgrades, reroll, fight, restart, abandon; shop offers the player cannot afford (they answer with a sound) |
| Grab | an open hand in a purple sleeve | over an affordable shop offer or an owned creature during preparation |
| Hold | the same hand closed | while a creature is dragged |
| Cast | the wand casting, with a dashed aiming ring | in combat, over a creature the spell can reach now |
| Unavailable | the wand greyed | in combat, over a valid target while the wand has no charge or the creature is still immune |

- There is **one spell**, so the cast cursor is the same on allies and enemies; only its effect differs. Before the swamp witch introduces the hex, enemies keep the wand at rest: the cursor introduces the hex along with the rule.
- Both hands click at the palm and the wands at the star, so grabbing does not make the pointer jump.
- Cursors are static: on the Web, every cursor change regenerates a browser cursor, so animation stays on the board.
- They are drawn on 32 pixels and shown with each pixel doubled, 64×64 on screen (playtest, 26 November 2026: at 32 they were too small to read). Chromium browsers refuse cursors over 32 pixels where they would overlap the browser's own interface, so at the very edge of the page the system cursor briefly takes over.
- Empty board cells in combat (a fizzle) and the title's skip-by-click while it animates keep the wand at rest; only real targets light it.

## Remaining open decisions

- Character style, silhouettes, palette and visual references.
- Readability of unit roles, teams and transformed states.
- Transformation effects and how to communicate their gameplay consequences.
- Asset production approach and achievable content volume for the jam.

See [[Game Vision]] and [[Design Index]].
