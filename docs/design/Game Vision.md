# Game Vision

## Core concept — confirmed direction

A heroic fantasy **auto-battler** in which the player is a wizard or sorcerer whose main spell is **shapeshifting**. Units fight automatically on a board, while the player influences the battlefield by transforming creatures.

The project is intended for Game Off 2026, with the theme **shift**, as reported by the team. Shapeshifting directly expresses that theme through both its name and its central mechanic.

## Shapeshifting

The initial focus is single-target transformations of friendly or enemy creatures. The result is randomly drawn from a set of possible forms connected to the creature's current form. Learning these connections should let skilled players anticipate likely outcomes without choosing the result directly. See [[Shapeshifting]].

Exchanging properties or statistics between a friendly unit and an enemy helped spark the original concept. This remains a secondary direction to explore later; multi-target shapeshifting is deferred. **Shapeshifting is the main design axis**.

Bench targeting is also proposed; see [[Gameplay Loop]].

## References

| Reference | Intended influence |
| --- | --- |
| Teamfight Tactics | Main mechanical reference: placing units on a board and watching them fight automatically. |
| Super Auto Pets | Auto-battler reference, especially for atmosphere. The specific visual interpretation remains open. |

The proposed combination of fantasy characters and animal transformations is recorded separately in [[Ideas to Explore]] because it has not yet been discussed with the other developer.

## Setting

**Confirmed:** heroic fantasy, chosen to make the game easier to read. See [[Art Direction]].

## Duel format and player experience

A **single-player duel against an AI wizard**, framed as a board game played by sorcerers. Multiplayer is outside the current scope.

The duel spans several rounds, with shopping and strategy adjustments between rounds. A wizard loses health after a lost round based on the opposing units remaining on the board. The duel ends when one wizard has no health left.

The desired mood is playful and somewhat chaotic, while the mechanics must still reward control, knowledge and skill.

## Team and existing work

Two programmers are working on the project. Git history inspected on 3 November 2026 includes contributions credited to Jasper van der Ster and Space Monkey.

`prototypes/prototype_01` is an existing attribute-swapping combat experiment. Its controls, timings, targeting restrictions and presentation are not automatically requirements for the new auto-battler prototype.

See [[Gameplay Loop]] and [[Meeting - 2026-11-02]].
