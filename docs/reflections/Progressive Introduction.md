# Progressive introduction and creature tiers

**Status:** exploration, 20 November 2026. No solution, tier assignment, unlock
condition or narrative below has been approved. No gameplay changes implemented.

## Problem raised by the user

Reduce the game's complexity and introduce it progressively. Dividing creatures
into tiers seems promising, but how to unlock them and connect that progression
to wizard duels remains unresolved. Use guided questions and concrete alternatives
to explore solutions before recording any design decision.

## Observed starting point

The current prototype has 12 purchasable fantasy forms and 12 animal forms.
Its transformation graph has eight stages of three forms, with every form leading
to the next stage and the eighth returning to the first. Outcome priorities are
55/30/15 percent. Starting packs, enemy compositions and transformations can all
introduce creatures independently of the shop.

The game already unlocks Adept after an Apprentice victory and Archmage after an
Adept victory. These currently change AI behaviour, not the available roster.
This is existing infrastructure to consider, not evidence that roster progression
should use the same victory gates.

Sources: [live creature data](../../prototypes/prototype_02/scripts/data/creature_db.gd),
[prototype README](../../prototypes/prototype_02/README.md).
Older design notes contain proposals that differ from the live prototype; they
are context rather than a reliable inventory of current behaviour.

## Possible blockers — hypotheses to discuss

| Possible blocker | Why it matters | Useful distinction |
| --- | --- | --- |
| Solving onboarding, progression and replayability together | One unlock system acquires too many responsibilities. | First identify what the opening experience must teach. |
| Treating tiers as power levels | Later creatures may make early favourites feel obsolete. | Learning tiers could add tactical possibilities rather than raw strength. |
| Counting shop entries instead of encountered forms | Transformations or the opponent reveal locked content immediately. | Define the complete encounter pool for both wizards. |
| Reducing the roster while keeping every other demand | Shopping, merges, placement, cast timing and target choice still compete for attention. | Identify the hardest decision, not just the number of creatures. |
| Waiting for a complete story | Narrative scope delays a small gameplay experiment. | A sparring partner and an agreed duel rule may be enough for a test. |
| Requiring victory before the player can learn more | A struggling player may repeatedly face the same lesson. | Compare victory gates with encounter completion or optional advancement. |
| Teaching connections that later change | An expanding graph can invalidate learned expectations. | Decide explicitly how small and large rosters relate. |

These are possible sources of the design impasse, not conclusions about the
user's preferences or observed player behaviour.

## Three candidate frames

All names and flows here are disposable examples. Do not build three systems.

| Candidate | Fiction and progression | Small test | Main risk |
| --- | --- | --- | --- |
| A. Lessons between wizards | A mentor proposes restricted sparring, then introduces a new magical practice. | Two encounters with a small shared roster, then an optional richer encounter. Initially compare completion with victory as the advancement trigger. | Lessons feel like chores; changing transformation routes causes confusion. |
| B. Duel conventions | Both wizards agree to a restricted, intermediate or complete grimoire before the duel. Richer formats become available after an introductory encounter and remain selectable. | Use the existing duel entry flow with two roster presets; keep AI difficulty a separate choice. | The extra format choice complicates the menu; restrictions need to feel natural. |
| C. A growing grimoire | Each encountered wizard demonstrates a new group of forms, available in future duels. | One opponent introduces one fixed addition after the encounter, including after a defeat; preview it before the next duel. | More persistent state and content; collection overshadows tactical learning. |

Provisional assistant preference: test A or B first because both can be evaluated
with existing duel structure and very little narrative content. C is worth testing
if discovery and collection are central to the desired experience.

An alternative is unlocking tiers at fixed rounds within every duel. This creates
a rising arc but repeats the teaching ramp for experienced players and can add
unfamiliar forms while the player is already under pressure. Keep it as a comparison
if within-duel escalation is the actual goal, rather than assuming it is needed.

## The transformation constraint

Filtering shop offers alone does not create a smaller learning space. A restricted
prototype must account for starting packs, both shops, enemy teams and every
reachable transformation outcome.

The current graph reaches all 24 forms from any starting form. No proper nonempty
subset is closed under all current outgoing transformations. A truly restricted
roster therefore requires a graph change or an explicit boundary rule.

Two possible experiments:

1. **A separate small practice graph.** Easy to isolate and compare, but learned
   routes may change in the complete game. Present it as a specific sparring rule;
   check whether players understand the transition.
2. **A revised complete graph with stable learning groups.** Aim to preserve
   learned connections, but define how new groups become reachable. This is a
   larger design task and should wait until a small roster proves useful.

Blindly removing locked outcomes can leave a form with no valid destination.
Renormalising probabilities or reconnecting stages also changes expectations.
Never leave that behaviour implicit in a prototype specification.

Smaller cycles also shorten the return to a previous form, conflicting with the
current eight-cast shortest return. If tested, record that as an intentional
experimental departure rather than claiming all existing graph properties survive.

## One paper prototype before implementation

Purpose: determine whether fewer forms help a player explain a cast decision.
This tests the learning hypothesis before investing in unlock presentation.

- Compare a few equivalent tactical situations with the full roster and an
  illustrative small roster. Six forms is a test size, not a chosen tier size.
- In the small version, include recognisable frontline, damage and support roles
  across fantasy and animal forms; specify the practice graph before testing.
- Show actual outcomes and ask: "Who would you transform, what do you hope to
  gain, and what could go wrong?" Evaluate allied and enemy targets separately.
- Follow with a richer situation and check whether earlier learning still helps.
- Record explanations, hesitation and surprises. Do not treat win rate as a
  measure of understanding or simulate balance duels for this investigation.

If fewer forms do not help, investigate feedback, outcome previews or the bundled
effects of allied/enemy casts before adding a progression system.

## Guided discussion — answer progressively

Start with only the first two questions; later answers depend on them.

1. Which fantasy is most appealing: an apprentice taking lessons, a competitor
   entering richer duel formats, or an explorer expanding a grimoire?
2. What seems hardest for a newcomer: recognising creature roles, choosing a
   transformation target, or handling preparation and combat demands together?
3. Should the complete game be reached during one duel, over a few introductory
   duels, or through a longer journey?
4. Should an unsuccessful learner advance, repeat, or choose? What experience
   should a defeat produce?
5. Should new tiers add tactical variety, stronger creatures, or both?
6. Must learned transformation routes remain identical as tiers open?

## Evidence and decisions

- **User direction:** explore progressive introduction and possible creature tiers;
  keep reflection separate from approved design.
- **User feedback:** school, tournament and grimoire discovery are all appealing;
  choosing one exclusive frame is difficult. They may have a useful order, without
  needing to be implemented together. Newcomers may not know auto-battlers at all:
  shop, rounds, hearts and defeat already need teaching before the shapeshift twist.
- **Next exploration requested:** write an HTML rule booklet to expose concept
  dependencies and guide a later progression prototype. See
  [Game rules](../how-to-play.html), now published on GitHub Pages and linked
  from itch.io.
- **Pending:** review and test the booklet's teaching order, then derive a small
  progression experiment from the results.
- **Assistant hypotheses:** all proposed diagnoses, candidate systems, roster sizes
  and test procedures in this note.
- **Playtest evidence:** none collected.
- **Validated design decisions:** none.

### Follow-up: one complete rules document

The user requested a single detailed guide from A to Z with section shortcuts,
instead of a quick guide and a separate booklet. The current rules explanation
is now consolidated in `docs/how-to-play.html`. It includes the roster, starting
packs, exact transformation probabilities, statistics and examples. The extra
game card was removed from the guide body; the navigation's play link remains.
These are documentation choices, not validation of any gameplay progression.

The user subsequently requested a concise, factual version: remove the opening
subtitle and paragraph, keep the section shortcuts, remove the first-shop gold
column, and shorten headings and explanations. The published page is now titled
"Game rules". These editorial changes do not validate its teaching order.
