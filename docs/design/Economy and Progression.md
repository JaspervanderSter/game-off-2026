# Economy and Progression

## Confirmed journey progression — 20 November 2026

[[Prototype 02#Journey roadmap and progression — confirmed 20 November 2026]]
records the confirmed across-duel design: a wizard travels through forest,
medieval town and magic-school islands; the fifteen opponents introduce existing rules one at a time, and each side
starts its duels with **3, 6, then 10 hearts**. See [[Journey and Opponents]] for
the five characters in each territory.
The map uses a triangle layout and suspended bridges, fits one screen without
scrolling, and has no textual interface or upper UI banner. These are selected
design decisions, separate from the older resource-economy experiments below.
The route is linear: each victory discovers the next opponent through a
four-second animated trace with muffled taps. Unknown opponents and paths are
fully hidden; the protagonist is not shown on the map. That section also records
implementation status and the unresolved details.

## Direction from the earlier discussion

Use two separate resources for two progression axes:

| Resource | Purpose | Status |
| --- | --- | --- |
| Gold | Buy creatures in the shop. | Current intended direction; income and prices unresolved. |
| Wizard progression resource | Improve shapeshift and potentially unlock other shapeshift types. | Separate resource requested; name, income and upgrade rules unresolved. |

Combining creatures to increase their level is a working proposal. Neither income model nor merging rules have been selected: prototyping must answer these questions.

“Arcane knowledge” is an assistant-proposed placeholder for the second resource, not an approved name. This resource is for progression; it is not currently defined as a per-cast cost or a replacement for spell charges.

## Assistant proposal A — predictable income first

Start with fixed gold income after every completed round, regardless of the winner, and a small fixed amount of arcane knowledge at the same transition.

For an initial comparison, keep the AI on the same income schedule. AI spending rules remain to be defined.

This gives both creature and spell progression a predictable baseline. Test whether purchases create real choices and whether each resource has a clear purpose before adding reward conditions.

Optional later experiment: a small, capped victory bonus. Compare whether it makes victory rewarding without letting an early lead determine the whole duel.

No income amounts, costs, interest, streak rewards or exchange rate between resources are selected.

## Assistant proposal B — knowledge through discovery

Keep predictable gold income. Replace the fixed knowledge grant with a reward for discovering a previously unseen transformation connection during the duel.

This could connect wizard progression to learning the transformation network. Risks to test: rewarding purposeless casts, encouraging players to prolong combat, or running out of income once discoveries are exhausted. Define discovery scope and a per-round cap before testing this model.

Compare this with proposal A while leaving the creature economy unchanged. Do not assume a discovery reward is needed merely because it fits the theme.

## Assistant proposal C — knowledge through announced objectives

Keep predictable gold income. Offer a small, clearly announced round objective that grants knowledge, such as transforming both a friendly and an enemy creature during the round.

This could encourage varied spell use. Test whether objectives distract from winning the duel or reward actions without tactical value. Objectives must be achievable for both sides and understandable before combat.

## Creature merging experiment

Assistant-proposed starting rule: combine two identical creatures of the same level into one creature of the next level. Two copies is only a test parameter.

Start with a modest statistic improvement rather than adding new abilities at every level. Test whether players meaningfully choose between fielding two bodies and investing in one stronger creature.

Resolve these interactions explicitly:

- Does identity for merging mean original creature identity or current transformed form?
- Does level survive shapeshifting, and how does it affect the destination form?
- If transformations persist, can players cheaply manufacture merge candidates?
- Where and when is merging allowed, and what happens to health and bench space?

These questions are linked to the unresolved persistence rule in [[Shapeshifting]].

## Wizard upgrade experiments

Assistant suggestions only: compare one simple recharge improvement with one modifier that changes transformation choices. Do not implement both immediately.

Unlocking additional shapeshift types belongs to the broader progression direction, but does not expand the first prototype beyond its single-target spell automatically. Multi-target shapeshifting remains deferred.

## Suggested prototype order and observations

1. Establish fixed incomes, a minimal creature shop and one wizard upgrade.
2. Evaluate whether players can explain each resource's purpose and make a meaningful purchase choice.
3. Test merging, including its interaction with transformations.
4. Compare alternate knowledge income models one at a time.

Observe whether an early loser can recover, whether saving versus spending is interesting, whether either resource accumulates without useful purchases, and whether progression incentivizes dragging out combat.

The resource experiments above concern progression within a duel. Across-duel journey progression is now specified by the confirmed 20 November roadmap linked above; it does not by itself approve a second currency or permanent wizard statistics.

See [[Gameplay Loop]], [[Ideas to Explore]] and [[Shapeshifting]].
