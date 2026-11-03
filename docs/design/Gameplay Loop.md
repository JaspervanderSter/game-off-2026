# Gameplay Loop

## Duel structure

The player faces an AI-controlled wizard. Both wizards have health; the duel ends when one wizard has no health left. Multiplayer is outside the current scope.

The intended minimum jam experience is one complete playable duel, including the transitions between rounds.

## Intended round flow

1. **Shop:** acquire creatures using gold. Combining creatures to level them up is proposed. A separate resource is intended for wizard spell progression; income rules and purchases must be tested. See [[Economy and Progression]].
2. **Preparation:** place creatures on the board.
3. **Combat:** units fight automatically; the player intervenes by casting spells with cooldowns.
4. **Resolution:** the losing wizard takes damage based on the opposing creatures still on the board. If both wizards retain health, return to the shop and adjust the strategy for the next round.

The precise round-ending trigger, draws, damage formula and any round limit remain unspecified. Shop details and progression also remain open.

## Starting selection — working proposal

At the beginning of a duel, choose a starting creature pack to support replayability. A tier-1 power-up may also be offered. Pack contents, selection rules and power-up effects remain to be defined.

## First auto-battler prototype

The proposed initial spell scope is **shapeshifting only**. Additional spells are outside this initial scope; they are not yet specified.

The player's core interaction to explore is transforming creatures during automatic combat.

## Charges and cooldowns — working proposal

Give the basic shapeshift spell **three charges**, allowing the player to save casts and use several in succession.

The exact cooldown, recharge model, starting charge count and interaction with other resources remain open. Three charges is a suggestion, not a settled balance value.

## Targets

- **Confirmed direction:** transformations can involve friendly units and enemy units.
- **Deferred idea:** transformations involving multiple creatures, including exchanges of properties between opposing units.
- **Working proposal:** allow shapeshifting creatures on the bench as well.

The initial interaction targets one creature, with a weighted random outcome based on its current form and an initial three-second immunity after transformation. See [[Shapeshifting]] for the working rules and unresolved questions.

## Bench — working proposal

A bench similar in concept to the one referenced in Teamfight Tactics is desired, but its purpose in this game has not been established. Do not assume that it inherits the reference game's rules.

Questions include its capacity, when units may move between bench and board, and how bench transformations affect later combat.

## Other open decisions

- Exact round-ending conditions, draws and wizard damage calculation.
- Board size, team size and positioning rules.
- Shop economy, upgrades and progression: explicitly to resolve through prototyping; see [[Economy and Progression]].

See [[Game Vision]] and [[Ideas to Explore]].
