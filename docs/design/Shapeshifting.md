# Shapeshifting

## Status and scope

Shapeshifting is the core mechanic. The rules below are the current design to prototype, recorded from the follow-up discussion; provisional controls and numbers remain subject to testing and team validation.

The first auto-battler prototype focuses on **one spell and one target per cast**. Two-creature interactions are deferred to [[Ideas to Explore]].

## Casting flow

1. Hover over a friendly or enemy creature.
2. Cast the default active spell, provisionally with **right-click**.
3. Play a short sound and visual effect as the creature changes form.
4. The transformed creature becomes immune to further shapeshifting for **three seconds**, as an initial tuning value.

This per-creature immunity is distinct from the spell's charges and recharge. The proposed three charges let players save and chain casts, but do not bypass a target's immunity.

Bench targeting is proposed separately; its availability and timing remain open.

## Transformation graph — proposed model

Represent forms as nodes in a network. Connections define which forms a creature can become when shapeshifted, with a probability assigned to each possible outcome.

Under the fantasy-to-animal proposal, build a heroic fantasy roster and an animal roster, then define their connections. For example, a shield-bearing foot soldier could have two or three possible animal outcomes. No animals, connections or probability values have been selected yet. The animal mashup still requires team validation.

The player **does not choose the resulting form**. The current form determines the available outcomes and their probabilities.

Repeated transformations can move a creature through the network. Some desired forms may require several casts and waiting through immunity periods. Connectivity is not yet defined: reaching every form from every other form is an ambition to investigate, not an established property.

## Skill and uncertainty

Players should develop an intuition for likely outcomes as they learn the network. Randomness creates uncertainty, while knowledge of connections and cast timing should provide meaningful control.

The number of links on the shortest path and the expected number of casts needed to reach a form are different: weighted random outcomes can make the actual journey longer. Both may be useful when evaluating the network; no distance formula has been chosen.

## Rules still to define

- What changes with the form: statistics, abilities, attacks, role and other properties.
- How current health, damage already taken and cooldowns carry over.
- **To resolve through prototyping:** whether a creature keeps its transformed form between rounds or returns to its initial form. No default rule has been chosen; compare how persistence and reversion affect team building and combat decisions.
- Whether connections are directed, reversible, or connect forms within the same roster as well as across rosters.
- Whether the player can inspect possible outcomes and probabilities.
- Exact charge recharge rules and how immunity time behaves if combat is paused or slowed.

See [[Gameplay Loop]], [[Art Direction]] and [[Ideas to Explore]].
