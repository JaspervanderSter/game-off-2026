# Pitch — Shapeshifters Duel

**Status: working draft for discussion, not an approved specification.** Written
on 19 November 2026 from design notes and the current prototype. The detailed
rules, roster, timings and effects below describe a prototype snapshot or pitch
proposal; they are not commitments for the final game. [[Game Vision]],
[[Art Direction]] and the other design notes retain their own decision status.

## One line

**An auto-battler where you don't command your army: you rewrite it, mid-fight,
one shapeshift at a time.**

## Elevator pitch

Two wizards face each other across a game board. Each buys a small band of heroic
fantasy fighters, places them, and lets them clash on their own. But neither
wizard sits still: with a click, they shapeshift any creature on the board,
friend or foe. The Shield Guardian becomes a Turtle; the enemy Assassin becomes a
Rabbit; the humble Pitchfork Peasant, after a few lucky casts, turns into
something the opponent never planned for.

You never choose the result. Every form leads to three possible others, and
learning that web of transformations is what turns a gamble into a plan.

## Project introduction for 2D artists

Shapeshifters Duel is a 2D heroic fantasy game in which two wizards face off across a game board, using small bands of fighters as their pieces. Between rounds, the player recruits and positions their team; once combat begins, the creatures fight on their own while the wizards meddle with a single spell: shapeshifting. A heavily armoured guardian might become a turtle, or a dangerous enemy might suddenly find itself fighting as a rabbit. Each transformation changes the creature's role and can turn an apparently settled battle into a fresh scramble. The intended atmosphere is playful, mischievous and a little absurd: a magical contest with expressive characters, sudden transformations and defeated creatures flying off the board in a puff of smoke. For the 2D art, the central challenge is to give both fantasy fighters and animals distinct personalities and immediately readable silhouettes, so players can follow the action as the board keeps changing. Character style, palette and the precise camera angle remain open for discussion with the artists joining the project.

This introduction provides setting and tone for prospective contributors. See [[Artist Brief]] for a first visual exploration with prototype screenshots, and [[Art Direction]] for visual preferences and open decisions. A production asset list should be agreed separately.

## The fantasy

You are the wizard, not a general. Your power is not to make units stronger in a
menu between fights, but to change **what they are** while the battle is
happening, in real time and without a pause button.

## Why it fits "shift"

The theme is the verb of the game. The only spell is a shift; every round, the
board shifts shape under both players' hands; and the duel itself shifts as
income grows and one wizard's lead tips the balance.

## How a duel plays

1. **Pick a starting band** of creatures from a few themed packs.
2. **Shop:** spend gold on fantasy fighters. Income grows each round.
3. **Prepare:** drag creatures onto your half of the board.
4. **Fight:** creatures charge, lunge and shoot by themselves for about
   20–30 seconds. You spend spell charges to transform them as the fight unfolds.
5. **Resolve:** the losing wizard loses health for every enemy left standing.
   Transformations wear off; the next round starts in the shop.

The duel ends when one wizard runs out of health.

## The shapeshift, in one cast

- **Click a creature you own:** it changes form, heals a little, attacks again
  immediately, sheds negative effects and gains a level for the rest of the fight.
  A rescue, a power spike, a change of role.
- **Click an enemy:** it changes form, is stunned for three seconds and loses its
  levels. A disruption, a counter, a gamble that might backfire.
- Charges recharge every few seconds and can be stored, so saving three for a
  decisive burst is a real choice.
- A freshly transformed creature is briefly immune, and no form leads straight
  back to the one it came from. You can't simply undo your rival's work.

## The two worlds

Twelve heroic fantasy fighters (peasant, guardian, duelist, archer, pyromancer,
bard…) and twelve animals (turtle, rhinoceros, wolf, eagle, skunk, peacock…).
Every shapeshift crosses from one world to the other. Each form has a clear
strength and a clear weakness, so a transformation never just raises numbers: it
changes how a creature fights.

## Design pillars

1. **Shapeshifting is the game.** Every system serves the spell: the shop buys
   transformation potential as much as raw strength.
2. **Chaos you can learn.** Outcomes are random, but the network is fixed and
   visible on hover. Knowledge and timing turn luck into skill.
3. **Readable at a glance.** Icons and animation instead of text; clear team
   colours, roles and feedback on every transformation.
4. **Playful and a little silly.** Creatures lunge into one another, and defeated
   ones are launched off the board like rockets trailing smoke.

## What makes it different

Classic auto-battlers ask you to make all your decisions before the fight, then
watch. Here the fight is where the most interesting decisions happen. Your team
composition is a starting point, not a final answer.

## Inspirations

- **Teamfight Tactics** for the board, the shop and automatic combat.
- **Super Auto Pets** for the light, playful atmosphere and its friendly animals.

## Format and scope

- Single player against an AI wizard; no multiplayer.
- 2D top-down board, procedural shapes and icons, synthesized sound effects.
- Jam goal: one complete, replayable duel, from the first shop to the last heart.

See [[Design Index]].
